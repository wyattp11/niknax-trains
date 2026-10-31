-- ============================================================
-- One code per conductor, good on every train they conduct
-- ============================================================
--
-- Codes were tied to one conductor row on one train. A duplicated train, or a
-- new train the same person creates, has its own conductor row and so needed
-- its own code — which is why conductors couldn't get into their copies.
--
-- Now the code belongs to the PERSON. A conductor is recognised on any train
-- by their username, or by email when no username is on file. Their one code:
--   • unlocks every member train where they're listed as a conductor —
--     including copies and trains they create later, with no new code
--   • signs them into ALL of their current trains at once, so moving between
--     their trains doesn't ask again
--   • stays good until the admin issues them a new one
--
-- A device already signed into one of their trains can also step straight
-- into another of their trains without the code (conductor_session_hop).
--
-- Per-train limits stay: a train's access closes a week after its last day,
-- and 10 wrong codes on a train's page pause entry there for 15 minutes.
--
-- Existing live codes carry over, so nobody who has a working code loses it.
-- ============================================================


create table if not exists public.conductor_codes (
  id           uuid primary key default gen_random_uuid(),
  username_key text,                      -- lower(username) it was issued for
  email_key    text,                      -- and/or lower(email)
  code_hash    text not null,
  salt         text not null,
  created_at   timestamptz not null default now(),
  used_at      timestamptz,               -- first use
  retired_at   timestamptz,
  check (username_key is not null or email_key is not null)
);

create index if not exists conductor_codes_live_idx
  on public.conductor_codes(username_key, email_key) where retired_at is null;

alter table public.conductor_codes enable row level security;
revoke all on public.conductor_codes from anon, authenticated;   -- RPCs only


-- Failed-entry counter per train page (the old one lived on the code rows).
create table if not exists public.conductor_code_attempts (
  train_id       uuid primary key references public.trains(id) on delete cascade,
  attempts       integer not null default 0,
  last_failed_at timestamptz
);

alter table public.conductor_code_attempts enable row level security;
revoke all on public.conductor_code_attempts from anon, authenticated;


-- ── Same person? ──────────────────────────────────────────────────────────
-- Username is THE identity. Email is only used for conductors who have no
-- username at all, and then only against rows that also have none.
--
-- Matching on "username OR email" would be exploitable: anyone can create a
-- member train with their own username and someone else's email, and would
-- then match that person's trains by email.

create or replace function public.conductor_matches(
  p_row          public.train_conductors,
  p_username_key text,
  p_email_key    text
)
returns boolean
language sql
immutable
as $$
  select case
    when p_username_key is not null
      then lower(nullif(trim(p_row.username), '')) = p_username_key
    else p_email_key is not null
     and nullif(trim(p_row.username), '') is null
     and p_row.email_key = p_email_key
  end;
$$;


-- Mints a 90-day session for one conductor row. Returns the plain token.
create or replace function public.mint_conductor_session(p_conductor public.train_conductors)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_token   text;
  v_salt    text;
  v_expires timestamptz := now() + interval '90 days';
begin
  v_token := replace(gen_random_uuid()::text, '-', '')
          || replace(gen_random_uuid()::text, '-', '');
  v_salt  := encode(gen_random_bytes(16), 'hex');

  insert into public.conductor_sessions
    (train_id, conductor_id, email_key, token_hash, salt, expires_at, last_seen_at)
  values
    (p_conductor.train_id, p_conductor.id, p_conductor.email_key,
     public.hash_secret(v_token, v_salt), v_salt, v_expires, now());

  return jsonb_build_object(
    'train_id',   p_conductor.train_id,
    'token',      v_token,
    'expires_at', v_expires,
    'email',      p_conductor.email,
    'username',   p_conductor.username
  );
end;
$$;

revoke all on function public.mint_conductor_session(public.train_conductors) from public, anon, authenticated;


-- ── Carry over live codes from the per-train table ────────────────────────

insert into public.conductor_codes (username_key, email_key, code_hash, salt, created_at, used_at)
select distinct on (c.code_hash)
  lower(nullif(trim(tc.username), '')),
  case when nullif(trim(tc.username), '') is null then tc.email_key end,
  c.code_hash, c.salt, c.created_at, c.used_at
from public.conductor_access_codes c
join public.train_conductors tc on tc.id = c.conductor_id
where c.retired_at is null
  and c.expires_at > now()
  and (tc.username is not null or tc.email_key is not null)
order by c.code_hash, c.created_at;

update public.conductor_access_codes
set retired_at = now()
where retired_at is null;


-- ── Admin issues (or replaces) a conductor's code ─────────────────────────

create or replace function public.admin_create_conductor_code(
  p_conductor_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_conductor public.train_conductors;
  v_ukey      text;
  v_ekey      text;
  v_code      text;
  v_salt      text;
  v_trains    integer;
  v_names     jsonb;
begin
  if not public.is_admin() then
    raise exception 'Admins only.' using errcode = 'P0001';
  end if;

  select * into v_conductor from public.train_conductors where id = p_conductor_id;
  if not found then
    raise exception 'Conductor not found.' using errcode = 'P0001';
  end if;

  v_ukey := lower(nullif(trim(v_conductor.username), ''));
  -- Email identifies the person only when there's no username.
  v_ekey := case when v_ukey is null then v_conductor.email_key end;

  if v_ukey is null and v_ekey is null then
    raise exception 'Add a username or email for this conductor first.' using errcode = 'P0001';
  end if;

  -- One live code per person.
  update public.conductor_codes
  set retired_at = now()
  where retired_at is null
    and ((v_ukey is not null and username_key = v_ukey)
      or (v_ukey is null and username_key is null and email_key = v_ekey));

  v_code := public.generate_access_code();
  v_salt := encode(gen_random_bytes(16), 'hex');

  insert into public.conductor_codes (username_key, email_key, code_hash, salt)
  values (v_ukey, v_ekey, public.hash_secret(v_code, v_salt), v_salt);

  select count(distinct tc.train_id),
         coalesce(jsonb_agg(distinct t.name), '[]'::jsonb)
  into v_trains, v_names
  from public.train_conductors tc
  join public.trains t on t.id = tc.train_id
  where public.conductor_matches(tc, v_ukey, v_ekey);

  return jsonb_build_object(
    'ok',          true,
    'code',        v_code,
    'trains',      v_trains,
    'train_names', v_names,
    'conductor', coalesce(v_conductor.username, v_conductor.email)
  );
end;
$$;

grant execute on function public.admin_create_conductor_code(uuid) to authenticated;


-- ── Conductor enters their code ───────────────────────────────────────────
-- Returns the session for this train plus sessions for every other live
-- member train they conduct, so one entry covers all of them.

create or replace function public.redeem_conductor_code(
  p_train_id uuid,
  p_code     text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_clean    text;
  v_code     public.conductor_codes;
  v_here     public.train_conductors;
  v_row      public.train_conductors;
  v_attempts public.conductor_code_attempts;
  v_main     jsonb;
  v_others   jsonb := '[]'::jsonb;
begin
  v_clean := public.normalize_access_code(p_code);

  if length(coalesce(v_clean, '')) < 9 then
    raise exception 'Enter the 8-character code your Niknax admin gave you.'
      using errcode = '22023';
  end if;

  if public.train_access_ended(p_train_id) then
    raise exception 'This train has ended, so conductor access is closed.'
      using errcode = 'P0001', detail = 'train_ended';
  end if;

  select * into v_attempts from public.conductor_code_attempts where train_id = p_train_id;
  if v_attempts.attempts >= 10 and v_attempts.last_failed_at > now() - interval '15 minutes' then
    raise exception 'Too many incorrect attempts. Wait 15 minutes and try again.'
      using errcode = 'P0001';
  end if;

  for v_code in
    select * from public.conductor_codes where retired_at is null
  loop
    if public.hash_secret(v_clean, v_code.salt) = v_code.code_hash then
      exit;
    end if;
    v_code := null;
  end loop;

  if v_code.id is null then
    insert into public.conductor_code_attempts (train_id, attempts, last_failed_at)
    values (p_train_id, 1, now())
    on conflict (train_id) do update set
      attempts = case
                   when conductor_code_attempts.last_failed_at is null
                     or conductor_code_attempts.last_failed_at <= now() - interval '15 minutes'
                   then 1
                   else conductor_code_attempts.attempts + 1
                 end,
      last_failed_at = now();

    raise exception 'That code isn''t right. Check it with your Niknax admin.'
      using errcode = 'P0001';
  end if;

  -- Right code — but are they a conductor on THIS train?
  select * into v_here
  from public.train_conductors tc
  where tc.train_id = p_train_id
    and public.conductor_matches(tc, v_code.username_key, v_code.email_key)
  order by tc.is_primary desc
  limit 1;

  if v_here.id is null then
    raise exception 'Your code is valid, but you''re not listed as a conductor on this train. Ask the train''s conductor or the Niknax team to add you.'
      using errcode = 'P0001', detail = 'not_on_train';
  end if;

  delete from public.conductor_code_attempts where train_id = p_train_id;
  update public.conductor_codes set used_at = coalesce(used_at, now()) where id = v_code.id;

  v_main := public.mint_conductor_session(v_here);

  -- Every other member train of theirs that's still open.
  for v_row in
    select distinct on (tc.train_id) tc.*
    from public.train_conductors tc
    join public.trains t on t.id = tc.train_id
    where tc.train_id <> p_train_id
      and t.is_member_train
      and public.conductor_matches(tc, v_code.username_key, v_code.email_key)
      and not public.train_access_ended(tc.train_id)
    order by tc.train_id, tc.is_primary desc
  loop
    v_others := v_others || jsonb_build_array(public.mint_conductor_session(v_row));
  end loop;

  return v_main || jsonb_build_object('other_sessions', v_others);
end;
$$;

grant execute on function public.redeem_conductor_code(uuid, text) to anon, authenticated;


-- ── Step from one of your trains into another ─────────────────────────────
-- A device signed into train A can open train B without the code, as long as
-- the same person is a conductor on B. Used for copies and new trains made
-- after the last code entry.

create or replace function public.conductor_session_hop(
  p_from_train_id uuid,
  p_token         text,
  p_to_train_id   uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.conductor_sessions;
  v_from    public.train_conductors;
  v_to      public.train_conductors;
  v_ukey    text;
begin
  if nullif(trim(coalesce(p_token, '')), '') is null or p_from_train_id = p_to_train_id then
    return null;
  end if;

  for v_session in
    select * from public.conductor_sessions
    where train_id = p_from_train_id and revoked_at is null and expires_at > now()
  loop
    if public.hash_secret(p_token, v_session.salt) = v_session.token_hash then
      exit;
    end if;
    v_session := null;
  end loop;

  if v_session.id is null then
    return null;
  end if;

  -- Identity comes from the conductor row the session belongs to. Sessions
  -- without one (pre-dating conductor_id) can't hop.
  select * into v_from from public.train_conductors where id = v_session.conductor_id;
  if v_from.id is null then
    return null;
  end if;
  v_ukey := lower(nullif(trim(v_from.username), ''));

  if public.train_access_ended(p_to_train_id) then
    return null;
  end if;

  select tc.* into v_to
  from public.train_conductors tc
  join public.trains t on t.id = tc.train_id
  where tc.train_id = p_to_train_id
    and t.is_member_train
    and public.conductor_matches(tc, v_ukey, case when v_ukey is null then v_from.email_key end)
  order by tc.is_primary desc
  limit 1;

  if v_to.id is null then
    return null;
  end if;

  perform public.set_audit_actor(coalesce(v_to.username, v_to.email, v_to.email_key));
  return public.mint_conductor_session(v_to);
end;
$$;

grant execute on function public.conductor_session_hop(uuid, text, uuid) to anon, authenticated;


-- ── Admin list: "last active" works for username-only conductors too ──────
-- It matched sessions by email_key, which is empty for conductors added by
-- username, so they always read "never signed in".

-- The view runs as the caller, who can't read conductor_codes directly.
create or replace function public.conductor_has_code(p_row public.train_conductors)
returns boolean
language sql
stable
security definer
set search_path = public, extensions
as $$
  select exists (
    select 1 from public.conductor_codes k
    where k.retired_at is null
      and public.conductor_matches(p_row, k.username_key, k.email_key)
  );
$$;

grant execute on function public.conductor_has_code(public.train_conductors) to authenticated;

create or replace view public.train_conductors_admin
with (security_invoker = true)
as
select
  c.id, c.train_id, c.email, c.username, c.is_primary, c.created_at,
  (select max(s.last_seen_at)
     from public.conductor_sessions s
    where s.train_id = c.train_id
      and (s.conductor_id = c.id or (s.conductor_id is null and s.email_key = c.email_key))
      and s.revoked_at is null) as last_seen_at,
  public.conductor_has_code(c) as has_code
from public.train_conductors c;

grant select on public.train_conductors_admin to authenticated;


-- ── Duplicate: back to the plain version ──────────────────────────────────
-- Copying per-train codes onto the copy is no longer needed: the copy keeps
-- the same conductors, and their personal codes already cover it.

create or replace function public.duplicate_train(
  p_train_id uuid,
  p_token    text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_src            public.trains;
  v_new_id         uuid;
  v_is_admin       boolean := public.is_admin();
  v_session        public.conductor_sessions;
  v_caller_cond_id uuid;
  v_caller_key     text;
  v_new_cond_id    uuid;
  v_day            record;
  v_new_day_id     uuid;
  v_cond           record;
  v_inserted_id    uuid;
  v_token          text;
  v_salt           text;
  v_expires        timestamptz;
  v_idx            integer := 0;
begin
  select * into v_src from public.trains where id = p_train_id;
  if not found then
    raise exception 'Train not found.' using errcode = 'P0001';
  end if;

  if not v_is_admin then
    if not v_src.is_member_train then
      raise exception 'You do not have permission to duplicate this train.' using errcode = 'P0001';
    end if;

    -- Raises the usual "access expired" error, and sets the audit actor.
    perform public.require_conductor(p_train_id, p_token);

    -- Which conductor is this? Needed to sign them into the copy.
    for v_session in
      select * from public.conductor_sessions
      where train_id = p_train_id and revoked_at is null and expires_at > now()
    loop
      if public.hash_secret(p_token, v_session.salt) = v_session.token_hash then
        v_caller_cond_id := v_session.conductor_id;
        v_caller_key     := v_session.email_key;
        exit;
      end if;
    end loop;
  end if;

  -- ── Train ──
  insert into public.trains (
    name, tagline, description, cover_url, district_link, rules_md,
    is_member_train, conductor_username, show_interest_count,
    published, is_upcoming
  ) values (
    v_src.name || ' (Copy)', v_src.tagline, v_src.description, v_src.cover_url,
    v_src.district_link, v_src.rules_md,
    v_src.is_member_train, v_src.conductor_username, v_src.show_interest_count,
    false, false
  )
  returning id into v_new_id;

  -- ── Days + slots ── (day_order renumbered from date order)
  for v_day in
    select * from public.train_days
    where train_id = p_train_id
    order by day_date, day_order
  loop
    insert into public.train_days (train_id, day_date, day_label, day_order)
    values (v_new_id, v_day.day_date, v_day.day_label, v_idx)
    returning id into v_new_day_id;

    insert into public.slots (
      train_day_id, start_time, duration_min, username, seller_link,
      label, is_pre_assigned, slot_order
    )
    select
      v_new_day_id, s.start_time, s.duration_min,
      case when s.is_pre_assigned then s.username else null end,
      null,
      s.label, s.is_pre_assigned, s.slot_order
    from public.slots s
    where s.train_day_id = v_day.id;

    v_idx := v_idx + 1;
  end loop;

  -- ── Conductors (member trains) ──
  if v_src.is_member_train then
    for v_cond in
      select * from public.train_conductors
      where train_id = p_train_id
      order by is_primary desc, created_at
    loop
      insert into public.train_conductors (train_id, email, email_key, username, is_primary)
      values (v_new_id, v_cond.email, v_cond.email_key, v_cond.username, v_cond.is_primary)
      returning id into v_inserted_id;

      if v_cond.id = v_caller_cond_id
         or (v_caller_cond_id is null and v_caller_key is not null and v_cond.email_key = v_caller_key)
      then
        v_new_cond_id := v_inserted_id;
      end if;
    end loop;
  end if;

  -- ── Sign the duplicating conductor into the copy ──
  if not v_is_admin then
    v_token   := replace(gen_random_uuid()::text, '-', '')
              || replace(gen_random_uuid()::text, '-', '');
    v_salt    := encode(gen_random_bytes(16), 'hex');
    v_expires := now() + interval '90 days';

    insert into public.conductor_sessions
      (train_id, conductor_id, email_key, token_hash, salt, expires_at, last_seen_at)
    values
      (v_new_id, v_new_cond_id, v_caller_key,
       public.hash_secret(v_token, v_salt), v_salt, v_expires, now());
  end if;

  return jsonb_build_object(
    'train_id',   v_new_id,
    'token',      v_token,       -- null for admins
    'expires_at', v_expires
  );
end;
$$;

grant execute on function public.duplicate_train(uuid, text) to anon, authenticated;
