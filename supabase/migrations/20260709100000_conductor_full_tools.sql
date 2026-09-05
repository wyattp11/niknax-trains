-- ============================================================
-- Fix username-only conductors, and give conductors the admin toolset
-- ============================================================
--
-- BUG: the previous migration dropped NOT NULL from train_conductors.email_key
-- but not from the same column on conductor_access_codes and
-- conductor_sessions. Generating a code for a conductor registered by
-- username alone therefore failed with:
--   null value in column "email_key" ... violates not-null constraint
--
-- Those columns are now vestigial — conductor_id is the real key — so they
-- simply become nullable.
--
-- Also extends the conductor toolset to match the admin's:
--   • rules_md and cover_url on update_member_train
--   • day date and label editing
--   • read access to their own train's change history
-- ============================================================


-- ── The fix ───────────────────────────────────────────────────────────────

alter table public.conductor_access_codes alter column email_key drop not null;
alter table public.conductor_sessions     alter column email_key drop not null;


-- ── Train details: add rules and cover ────────────────────────────────────

create or replace function public.update_member_train(
  p_train_id      uuid,
  p_conductor     text,          -- session token
  p_name          text,
  p_tagline       text default null,
  p_description   text default null,
  p_district_link text default null,
  p_rules_md      text default null,
  p_cover_url     text default null
)
returns public.trains
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  updated public.trains;
begin
  perform public.require_conductor(p_train_id, p_conductor);

  if length(trim(coalesce(p_name, ''))) = 0 then
    raise exception 'Train name is required.' using errcode = '22023';
  end if;

  update public.trains set
    name          = trim(p_name),
    tagline       = nullif(trim(coalesce(p_tagline, '')), ''),
    description   = nullif(trim(coalesce(p_description, '')), ''),
    district_link = nullif(trim(coalesce(p_district_link, '')), ''),
    -- null means "not supplied, leave it" rather than "clear it", so an
    -- older client that doesn't send these can't wipe them.
    rules_md      = coalesce(nullif(trim(coalesce(p_rules_md, '')), ''), rules_md),
    cover_url     = coalesce(nullif(trim(coalesce(p_cover_url, '')), ''), cover_url)
  where id = p_train_id and is_member_train = true
  returning * into updated;

  if not found then
    raise exception 'Train not found.' using errcode = 'P0001';
  end if;

  return updated;
end;
$$;

grant execute on function
  public.update_member_train(uuid, text, text, text, text, text, text, text)
  to anon, authenticated;


-- ── Edit a day's date and label ───────────────────────────────────────────

create or replace function public.update_member_train_day(
  p_train_id  uuid,
  p_token     text,
  p_day_id    uuid,
  p_day_date  date default null,
  p_day_label text default null
)
returns public.train_days
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  updated public.train_days;
begin
  perform public.require_conductor(p_train_id, p_token);

  update public.train_days set
    day_date  = coalesce(p_day_date, day_date),
    day_label = case
                  when p_day_label is not null then nullif(trim(p_day_label), '')
                  else day_label
                end
  where id = p_day_id and train_id = p_train_id
  returning * into updated;

  if not found then
    raise exception 'Day not found on this train.' using errcode = 'P0001';
  end if;

  return updated;
end;
$$;

grant execute on function public.update_member_train_day(uuid, text, uuid, date, text)
  to anon, authenticated;


-- ── Change history for conductors ─────────────────────────────────────────
-- audit_log is admin-only by RLS, so conductors reach their own train's
-- history through this security-definer function. Scoped to one train, and
-- it returns the same readable summaries the admin panel shows.

create or replace function public.conductor_train_history(
  p_train_id uuid,
  p_token    text,
  p_limit    integer default 200
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  result jsonb;
begin
  perform public.require_conductor(p_train_id, p_token);

  select coalesce(jsonb_agg(row_to_json(h) order by h.created_at desc), '[]'::jsonb)
  into result
  from (
    select id, created_at, table_name, action, actor, changed_cols, summary
    from public.train_history
    where train_id = p_train_id
    order by created_at desc
    limit least(coalesce(p_limit, 200), 500)
  ) h;

  return result;
end;
$$;

grant execute on function public.conductor_train_history(uuid, text, integer)
  to anon, authenticated;

-- train_history is security_invoker, so it would run as the caller (anon) and
-- see nothing. A security-definer wrapper needs it to resolve as the owner.
create or replace view public.train_history
with (security_invoker = false)
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

-- The view now bypasses RLS, so it must not be readable directly. Admins go
-- through audit_log (which has its own admin policy); conductors go through
-- the function above.
revoke all on public.train_history from anon, authenticated;


-- Admins keep their panel working via a definer function of their own.
create or replace function public.admin_train_history(
  p_train_id uuid,
  p_limit    integer default 500
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  result jsonb;
begin
  if not public.is_admin() then
    raise exception 'Admins only.' using errcode = 'P0001';
  end if;

  select coalesce(jsonb_agg(row_to_json(h) order by h.created_at desc), '[]'::jsonb)
  into result
  from (
    select id, created_at, table_name, action, actor, changed_cols, summary
    from public.train_history
    where train_id = p_train_id
    order by created_at desc
    limit least(coalesce(p_limit, 500), 1000)
  ) h;

  return result;
end;
$$;

grant execute on function public.admin_train_history(uuid, integer) to authenticated;
