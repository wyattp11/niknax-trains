-- ============================================================
-- AUDIT LOG — change history for trains, days, and slots
-- ============================================================
--
-- Until now the tables only held current state, so "what were the original
-- settings" was unanswerable once anyone edited a train. This records every
-- insert, update, and delete with before/after values and who did it.
--
-- Actor attribution:
--   • Admins are authenticated, so auth.uid() identifies them.
--   • Public writes go through security-definer RPCs as the anon role, which
--     would otherwise all look identical. Those RPCs set a per-transaction
--     GUC (app.actor) naming the seller or conductor, which the trigger reads.
--
-- Deliberately NOT logged: train_chat_messages (high volume, already
-- ephemeral) and member_strikes (already an append-only record).
-- ============================================================


create table if not exists public.audit_log (
  id           bigserial primary key,
  table_name   text        not null,
  row_id       uuid        not null,
  train_id     uuid,                      -- denormalized for fast lookup
  action       text        not null check (action in ('INSERT', 'UPDATE', 'DELETE')),
  changed_cols text[],                    -- only the columns that actually changed
  old_values   jsonb,
  new_values   jsonb,
  actor        text,                      -- username, or 'admin', or null
  actor_uid    uuid,                      -- auth.users id when authenticated
  created_at   timestamptz not null default now()
);

create index if not exists audit_log_train_id_idx  on public.audit_log(train_id, created_at desc);
create index if not exists audit_log_row_id_idx    on public.audit_log(row_id);
create index if not exists audit_log_created_at_idx on public.audit_log(created_at desc);

alter table public.audit_log enable row level security;

drop policy if exists "admin read audit log" on public.audit_log;
create policy "admin read audit log"
on public.audit_log
for select
to authenticated
using (public.is_admin());

-- Nobody writes directly; only the trigger (security definer) does.
revoke insert, update, delete on public.audit_log from anon, authenticated;


-- ── Actor helper ──────────────────────────────────────────────────────────
-- RPCs call this to name the person behind an anon write.

create or replace function public.set_audit_actor(p_actor text)
returns void
language sql
volatile
as $$
  select set_config('app.actor', coalesce(p_actor, ''), true);
$$;

grant execute on function public.set_audit_actor(text) to anon, authenticated;


create or replace function public.current_audit_actor()
returns text
language plpgsql
stable
as $$
declare
  v text;
begin
  begin
    v := nullif(current_setting('app.actor', true), '');
  exception when others then
    v := null;
  end;

  if v is not null then
    return v;
  end if;

  if auth.uid() is not null then
    return 'admin';
  end if;

  return null;
end;
$$;

grant execute on function public.current_audit_actor() to anon, authenticated;


-- ── Generic trigger ───────────────────────────────────────────────────────

create or replace function public.audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old      jsonb;
  v_new      jsonb;
  v_row_id   uuid;
  v_train_id uuid;
  v_changed  text[];
  k          text;
begin
  v_old := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) else null end;
  v_new := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) else null end;

  v_row_id := coalesce((v_new->>'id')::uuid, (v_old->>'id')::uuid);

  -- Resolve the owning train so history is queryable per train
  if tg_table_name = 'trains' then
    v_train_id := v_row_id;
  elsif tg_table_name = 'train_days' then
    v_train_id := coalesce((v_new->>'train_id')::uuid, (v_old->>'train_id')::uuid);
  elsif tg_table_name = 'slots' then
    select d.train_id into v_train_id
    from public.train_days d
    where d.id = coalesce((v_new->>'train_day_id')::uuid, (v_old->>'train_day_id')::uuid);
  end if;

  -- On UPDATE, keep only the columns that actually changed. Without this the
  -- history is unreadable — every row edit would look like a full rewrite.
  if tg_op = 'UPDATE' then
    v_changed := array(
      select key
      from jsonb_each(v_new)
      where key <> 'created_at'
        and v_new -> key is distinct from v_old -> key
    );

    if array_length(v_changed, 1) is null then
      return null;   -- nothing meaningful changed; don't log noise
    end if;

    v_old := (select jsonb_object_agg(key, v_old -> key) from unnest(v_changed) as key);
    v_new := (select jsonb_object_agg(key, v_new -> key) from unnest(v_changed) as key);
  end if;

  insert into public.audit_log
    (table_name, row_id, train_id, action, changed_cols, old_values, new_values, actor, actor_uid)
  values
    (tg_table_name, v_row_id, v_train_id, tg_op, v_changed, v_old, v_new,
     public.current_audit_actor(), auth.uid());

  return null;   -- AFTER trigger; return value ignored
end;
$$;


-- ── Attach ────────────────────────────────────────────────────────────────

drop trigger if exists audit_trains     on public.trains;
drop trigger if exists audit_train_days on public.train_days;
drop trigger if exists audit_slots      on public.slots;

create trigger audit_trains
  after insert or update or delete on public.trains
  for each row execute function public.audit_row_change();

create trigger audit_train_days
  after insert or update or delete on public.train_days
  for each row execute function public.audit_row_change();

create trigger audit_slots
  after insert or update or delete on public.slots
  for each row execute function public.audit_row_change();


-- ── Readable history view ─────────────────────────────────────────────────

create or replace view public.train_history
with (security_invoker = true)
as
select
  a.id,
  a.train_id,
  a.created_at,
  a.table_name,
  a.action,
  a.actor,
  a.changed_cols,
  a.old_values,
  a.new_values,
  -- Human-readable one-liner for the admin timeline
  case
    when a.table_name = 'trains' and a.action = 'INSERT' then 'Train created'
    when a.table_name = 'trains' and a.action = 'DELETE' then 'Train deleted'
    when a.table_name = 'trains' then
      'Train updated: ' || array_to_string(a.changed_cols, ', ')
    when a.table_name = 'train_days' and a.action = 'INSERT' then
      'Day added (' || coalesce(a.new_values->>'day_date', '?') || ')'
    when a.table_name = 'train_days' and a.action = 'DELETE' then
      'Day removed (' || coalesce(a.old_values->>'day_date', '?') || ')'
    when a.table_name = 'train_days' then
      'Day updated: ' || array_to_string(a.changed_cols, ', ')
    when a.table_name = 'slots' and a.action = 'INSERT' then
      'Slot added at ' || coalesce(a.new_values->>'start_time', '?')
    when a.table_name = 'slots' and a.action = 'DELETE' then
      'Slot removed from ' || coalesce(a.old_values->>'start_time', '?')
        || case when a.old_values->>'username' is not null
                then ' (' || (a.old_values->>'username') || ')' else '' end
    when a.table_name = 'slots' and a.changed_cols = array['username'] then
      case
        when a.new_values->>'username' is null
          then 'Slot released by ' || coalesce(a.old_values->>'username', '?')
        when a.old_values->>'username' is null
          then 'Slot claimed by ' || coalesce(a.new_values->>'username', '?')
        else 'Slot reassigned: ' || coalesce(a.old_values->>'username', '?')
             || ' → ' || coalesce(a.new_values->>'username', '?')
      end
    when a.table_name = 'slots' and 'start_time' = any(a.changed_cols) then
      'Slot time changed: ' || coalesce(a.old_values->>'start_time', '?')
        || ' → ' || coalesce(a.new_values->>'start_time', '?')
    when a.table_name = 'slots' then
      'Slot updated: ' || array_to_string(a.changed_cols, ', ')
    else a.table_name || ' ' || a.action
  end as summary
from public.audit_log a;

grant select on public.train_history to authenticated;
