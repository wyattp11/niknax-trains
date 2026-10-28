-- ============================================================
-- Conductor codes become reusable personal codes
-- ============================================================
--
-- Before: an admin-issued code worked ONCE, within 48 hours. The sign-in it
-- created lived only in that one browser. A new phone, a link opened inside
-- Instagram/District's built-in browser, cleared data, or iPhone Safari
-- wiping site storage after 7 days without a visit all meant going back to
-- the admin for a new code.
--
-- Now each conductor's code is theirs to keep: it works on any device, any
-- number of times, until
--   • the admin issues them a new code (which retires the old one), or
--   • the train ends — 7 days after its last scheduled day. The grace week
--     lets a conductor look back over the train or duplicate it.
-- A train with no days yet doesn't end.
--
-- Wrong guesses are still limited: 10 misses on a train locks code entry for
-- 15 minutes. A correct entry clears the count. The old limit counted misses
-- forever, which a long-lived code would eventually trip.
--
-- Existing used or expired codes stay dead. Anyone still holding an unused,
-- unexpired code keeps it, now reusable.
-- ============================================================

alter table public.conductor_access_codes
  add column if not exists retired_at     timestamptz,
  add column if not exists last_failed_at timestamptz;

-- Backfill: anything already used, retired or expired is retired.
update public.conductor_access_codes
set retired_at = coalesce(used_at, expires_at)
where retired_at is null
  and (used_at is not null or expires_at <= now());

create index if not exists conductor_access_codes_live_idx
  on public.conductor_access_codes(train_id)
  where retired_at is null;


-- ── Has this train ended? ─────────────────────────────────────────────────

create or replace function public.train_access_ended(p_train_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, extensions
as $$
  select coalesce(
    (now() at time zone 'America/New_York')::date > max(d.day_date) + 7,
    false
  )
  from public.train_days d
  where d.train_id = p_train_id;
$$;

grant execute on function public.train_access_ended(uuid) to anon, authenticated;


-- ── Admin issues (or resets) a conductor's code ───────────────────────────

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
  v_code      text;
  v_salt      text;
begin
  if not public.is_admin() then
    raise exception 'Admins only.' using errcode = 'P0001';
  end if;

  select * into v_conductor from public.train_conductors where id = p_conductor_id;
  if not found then
    raise exception 'Conductor not found.' using errcode = 'P0001';
  end if;

  v_code := public.generate_access_code();
  v_salt := encode(gen_random_bytes(16), 'hex');

  -- One live code per conductor: a new one retires the old.
  update public.conductor_access_codes
  set retired_at = now()
  where conductor_id = p_conductor_id and retired_at is null;

  -- expires_at is required by the table; the real limit is the train ending,
  -- checked when the code is entered.
  insert into public.conductor_access_codes
    (train_id, conductor_id, email_key, code_hash, salt, expires_at)
  values
    (v_conductor.train_id, p_conductor_id, v_conductor.email_key,
     public.hash_secret(v_code, v_salt), v_salt, 'infinity');

  return jsonb_build_object(
    'ok',        true,
    'code',      v_code,
    'reusable',  true,
    'conductor', coalesce(v_conductor.username, v_conductor.email)
  );
end;
$$;

grant execute on function public.admin_create_conductor_code(uuid) to authenticated;


-- ── Conductor enters their code ───────────────────────────────────────────

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
  v_clean     text;
  v_row       public.conductor_access_codes;
  v_conductor public.train_conductors;
  v_token     text;
  v_salt      text;
  v_expires   timestamptz;
  v_attempts  integer;
  v_last_miss timestamptz;
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

  -- Rate limit: 10 misses, then a 15-minute cool-off.
  select coalesce(max(attempts), 0), max(last_failed_at)
  into v_attempts, v_last_miss
  from public.conductor_access_codes
  where train_id = p_train_id and retired_at is null;

  if v_attempts >= 10 and v_last_miss > now() - interval '15 minutes' then
    raise exception 'Too many incorrect attempts. Wait 15 minutes and try again.'
      using errcode = 'P0001';
  end if;

  for v_row in
    select * from public.conductor_access_codes
    where train_id = p_train_id
      and retired_at is null
      and expires_at > now()       -- admin codes are 'infinity'; this only
                                   -- matters for codes from the old email flow
      and conductor_id is not null
  loop
    if public.hash_secret(v_clean, v_row.salt) = v_row.code_hash then
      exit;
    end if;
    v_row := null;
  end loop;

  if v_row.id is null then
    update public.conductor_access_codes
    set attempts = case
                     -- the cool-off has passed: start counting again
                     when last_failed_at is null or last_failed_at <= now() - interval '15 minutes'
                       then 1
                     else attempts + 1
                   end,
        last_failed_at = now()
    where train_id = p_train_id and retired_at is null;

    raise exception 'That code isn''t right. Check it with your Niknax admin.'
      using errcode = 'P0001';
  end if;

  select * into v_conductor from public.train_conductors where id = v_row.conductor_id;
  if not found then
    raise exception 'That code is no longer linked to a conductor.' using errcode = 'P0001';
  end if;

  -- Reusable: record first use, clear the miss count, leave the code live.
  update public.conductor_access_codes
  set used_at = coalesce(used_at, now())
  where id = v_row.id;

  update public.conductor_access_codes
  set attempts = 0, last_failed_at = null
  where train_id = p_train_id and retired_at is null;

  v_token   := replace(gen_random_uuid()::text, '-', '')
            || replace(gen_random_uuid()::text, '-', '');
  v_salt    := encode(gen_random_bytes(16), 'hex');
  v_expires := now() + interval '90 days';

  insert into public.conductor_sessions
    (train_id, conductor_id, email_key, token_hash, salt, expires_at, last_seen_at)
  values
    (p_train_id, v_conductor.id, v_conductor.email_key,
     public.hash_secret(v_token, v_salt), v_salt, v_expires, now());

  return jsonb_build_object(
    'token',      v_token,
    'expires_at', v_expires,
    'email',      v_conductor.email,
    'username',   v_conductor.username
  );
end;
$$;

grant execute on function public.redeem_conductor_code(uuid, text) to anon, authenticated;


-- ── Duplicate: also carry each conductor's live code onto the copy ────────
-- (Same as 20261012100000 plus the code copy in the conductor loop.)

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

      -- Their personal code works on the copy too, so losing the sign-in on
      -- the copy doesn't mean another trip to the admin.
      insert into public.conductor_access_codes
        (train_id, conductor_id, email_key, code_hash, salt, expires_at)
      select v_new_id, v_inserted_id, c.email_key, c.code_hash, c.salt, c.expires_at
      from public.conductor_access_codes c
      where c.conductor_id = v_cond.id
        and c.retired_at is null;

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
