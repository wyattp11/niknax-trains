-- ============================================================
-- TRAIN INTEREST — "I'm interested" for trains that are Arriving Soon
-- ============================================================
--
-- Before sign-ups open, sellers can say they want in. That gives the admin
-- (and a member train's conductors) a list of who to expect and who to ping
-- when the train starts boarding.
--
--   • trains.signups_open_at     optional; drives a public countdown and an
--                                "Add reminder" calendar button. It does NOT
--                                open sign-ups on its own — status stays a
--                                manual switch, as before.
--   • trains.show_interest_count whether the public sees "N sellers
--                                interested". Names are never public.
--
-- The list is kept after sign-ups open, and each entry is marked when that
-- seller has claimed a slot, so it doubles as a "who still hasn't signed up"
-- checklist.
--
-- Unlike the Lobby, the table is NOT publicly readable: names are for the
-- admin and conductors only. The public gets a count, and only when the
-- train's show_interest_count is on.
-- ============================================================


alter table public.trains
  add column if not exists signups_open_at     timestamptz,
  add column if not exists show_interest_count boolean not null default true;


create table if not exists public.train_interest (
  id           uuid primary key default gen_random_uuid(),
  train_id     uuid not null references public.trains(id) on delete cascade,
  username     text not null,
  username_key text not null,
  created_at   timestamptz not null default now(),
  unique (train_id, username_key)
);

create index if not exists train_interest_train_idx
  on public.train_interest(train_id, created_at);

alter table public.train_interest enable row level security;

-- Admin only. Everyone else goes through the RPCs below.
drop policy if exists "admin manage interest" on public.train_interest;
create policy "admin manage interest"
on public.train_interest
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

revoke all on public.train_interest from anon;
grant select, insert, update, delete on public.train_interest to authenticated;


-- ── Express interest ──────────────────────────────────────────────────────
-- Returns the new public count (null when the train hides it).

create or replace function public.express_train_interest(
  p_train_id uuid,
  p_username text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  clean_username text;
  v_train        public.trains;
  v_member_name  text;
begin
  clean_username := nullif(trim(regexp_replace(coalesce(p_username, ''), '^@+', '')), '');

  if clean_username is null then
    raise exception 'Please enter your username.' using errcode = '22023';
  end if;

  select * into v_train from public.trains where id = p_train_id;

  if not found or not (v_train.published or v_train.is_upcoming) then
    raise exception 'This event isn''t open yet.' using errcode = 'P0001';
  end if;

  -- Once boarding, interest is beside the point — they should grab a slot.
  if v_train.published then
    raise exception 'Sign-ups are open — grab a slot instead!'
      using errcode = 'P0001', detail = 'signups_open';
  end if;

  select username into v_member_name
  from public.members
  where lower(username) = lower(clean_username) and can_go_live = true
  limit 1;

  if v_member_name is null then
    raise exception 'Sorry — that username isn''t on the authorized sellers list.'
      using errcode = 'P0001';
  end if;

  insert into public.train_interest (train_id, username, username_key)
  values (p_train_id, v_member_name, lower(clean_username))
  on conflict (train_id, username_key) do nothing;

  return public.train_interest_public(p_train_id);
end;
$$;

grant execute on function public.express_train_interest(uuid, text) to anon, authenticated;


-- ── Withdraw ──────────────────────────────────────────────────────────────

create or replace function public.withdraw_train_interest(
  p_train_id uuid,
  p_username text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  clean_username text;
begin
  clean_username := nullif(trim(regexp_replace(coalesce(p_username, ''), '^@+', '')), '');

  if clean_username is not null then
    delete from public.train_interest
    where train_id = p_train_id and username_key = lower(clean_username);
  end if;

  return public.train_interest_public(p_train_id);
end;
$$;

grant execute on function public.withdraw_train_interest(uuid, text) to anon, authenticated;


-- ── Public view: count only, and only if the train shows it ───────────────

create or replace function public.train_interest_public(p_train_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public, extensions
as $$
  select jsonb_build_object(
    'show_count', t.show_interest_count,
    'count', case when t.show_interest_count
                  then (select count(*) from public.train_interest i where i.train_id = t.id)
                  else null end
  )
  from public.trains t
  where t.id = p_train_id
    and (t.published or t.is_upcoming);
$$;

grant execute on function public.train_interest_public(uuid) to anon, authenticated;


-- Counts for the home page, one round trip for every card. Trains that hide
-- their count are simply left out.
create or replace function public.train_interest_counts(p_train_ids uuid[])
returns table (train_id uuid, interest_count integer)
language sql
stable
security definer
set search_path = public, extensions
as $$
  select t.id, (select count(*)::integer from public.train_interest i where i.train_id = t.id)
  from public.trains t
  where t.id = any(p_train_ids)
    and t.show_interest_count
    and (t.published or t.is_upcoming);
$$;

grant execute on function public.train_interest_counts(uuid[]) to anon, authenticated;


-- ── Full list: admin, or a conductor of this member train ─────────────────
-- Each entry says whether that seller has since claimed a slot.

create or replace function public.train_interest_list(
  p_train_id uuid,
  p_token    text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
begin
  if not public.is_admin()
     and public.conductor_email_for_token(p_train_id, p_token) is null then
    raise exception 'You do not have permission to view this list.'
      using errcode = 'P0001', detail = 'conductor_auth';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'username',   i.username,
             'created_at', i.created_at,
             'signed_up',  exists (
               select 1
               from public.slots s
               join public.train_days d on d.id = s.train_day_id
               where d.train_id = i.train_id
                 and lower(s.username) = i.username_key
             )
           ) order by i.created_at)
    from public.train_interest i
    where i.train_id = p_train_id
  ), '[]'::jsonb);
end;
$$;

grant execute on function public.train_interest_list(uuid, text) to anon, authenticated;


-- Remove someone from the list (e.g. a duplicate or a mistaken entry).
create or replace function public.remove_train_interest(
  p_train_id uuid,
  p_username text,
  p_token    text default null
)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if not public.is_admin() then
    perform public.require_conductor(p_train_id, p_token);
  end if;

  delete from public.train_interest
  where train_id = p_train_id
    and username_key = lower(trim(regexp_replace(coalesce(p_username, ''), '^@+', '')));

  return true;
end;
$$;

grant execute on function public.remove_train_interest(uuid, text, text) to anon, authenticated;


-- ── Conductor settings ────────────────────────────────────────────────────
-- Admins edit these columns directly; conductors come through here. Both
-- values are always sent, so null for signups_open_at means "no time set".

create or replace function public.set_member_train_interest_settings(
  p_train_id        uuid,
  p_token           text,
  p_show_count      boolean,
  p_signups_open_at timestamptz
)
returns public.trains
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  updated public.trains;
begin
  perform public.require_conductor(p_train_id, p_token);

  update public.trains set
    show_interest_count = coalesce(p_show_count, true),
    signups_open_at     = p_signups_open_at
  where id = p_train_id and is_member_train = true
  returning * into updated;

  if updated.id is null then
    raise exception 'Train not found.' using errcode = 'P0001';
  end if;

  return updated;
end;
$$;

grant execute on function public.set_member_train_interest_settings(uuid, text, boolean, timestamptz)
  to anon, authenticated;
