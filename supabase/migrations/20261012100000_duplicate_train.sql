-- ============================================================
-- Duplicate a train — admin or conductor, any train (not just past ones)
-- ============================================================
--
-- The Dashboard's Duplicate used to copy a train from the browser in several
-- separate inserts, so a failure halfway left a half-built copy behind, and
-- conductors (who can't write tables directly) couldn't duplicate at all.
-- This does the whole copy in one transaction.
--
-- What the copy gets:
--   • name + " (Copy)", tagline, description, cover, District link, rules,
--     member-train flag, conductor, and the public interest-count setting
--   • every day (same dates — edit them after) and every slot's time, length,
--     label and reserved flag
--   • reserved slots keep their assigned person; every other slot is empty,
--     and no show links carry over
--   • for a member train, the same conductor list
--
-- What it doesn't get: sign-ups, show links, lobby, interest list, chat,
-- chat lock, or a sign-ups-open time.
--
-- The copy always starts unpublished and not upcoming. For an admin that's a
-- draft; for a member train that's "pending review", so the Niknax approval
-- step still applies to a conductor's copy exactly as it does to a new train.
--
-- A conductor gets a fresh 90-day session on the copy, so they land in it
-- already signed in instead of needing a new access code.
-- ============================================================

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
