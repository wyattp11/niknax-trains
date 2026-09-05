-- ============================================================
-- Reserved slots stop naming who they're for
-- ============================================================
--
-- The public label is now a locked "Reserved" rather than "Moderator Sign Up",
-- because reserved rows get used for guests and features too, not just
-- moderators. claim_slot still told anyone who clicked exactly who the slot
-- was held for, which undercut that — so the three messages that leaked it
-- now say only that the slot is reserved.
--
-- Nothing about who can actually claim what changes; this is wording only.
-- ============================================================


create or replace function public.claim_slot(slot_id uuid, claimant_username text)
returns public.slots
language plpgsql
security definer
set search_path = public
as $$
declare
  claimed public.slots;
  clean_username text;
  target_train_id uuid;
  target_published boolean := false;
  target_is_upcoming boolean := false;
  target_is_kickoff boolean := false;
  target_is_pre_assigned boolean := false;
  target_is_member_train boolean := false;
  is_unlimited_claimant boolean := false;
  strike_points integer := 0;
  strike_threshold integer := 1;
  strike_reason text;
  strike_train_name text;
  block_message text;
begin
  clean_username := nullif(trim(regexp_replace(coalesce(claimant_username, ''), '^@+', '')), '');

  if clean_username is null then
    raise exception 'Please enter your username.' using errcode = '22023';
  end if;

  if length(clean_username) > 60 then
    raise exception 'Username is too long.' using errcode = '22023';
  end if;

  select exists (
    select 1
    from public.members m
    where lower(m.username) = lower(clean_username)
      and public.is_staff_role(m.role)
  )
  into is_unlimited_claimant;

  select d.train_id, t.published, t.is_upcoming,
         (lower(coalesce(s.label, '')) = 'kickoff' or s.slot_order = 0),
         s.is_pre_assigned,
         coalesce(t.is_member_train, false)
  into target_train_id, target_published, target_is_upcoming, target_is_kickoff,
       target_is_pre_assigned, target_is_member_train
  from public.slots s
  join public.train_days d on d.id = s.train_day_id
  join public.trains t on t.id = d.train_id
  where s.id = slot_id;

  if target_train_id is null then
    raise exception 'Sorry - this slot is no longer available.' using errcode = 'P0001';
  end if;

  if target_is_kickoff and not is_unlimited_claimant then
    raise exception 'This slot is reserved. If it''s being held for you, check with the Niknax team.'
      using errcode = 'P0001', detail = 'reserved_slot';
  end if;

  if target_is_pre_assigned and not target_is_kickoff and not is_unlimited_claimant then
    raise exception 'This slot is reserved. If it''s being held for you, check with the Niknax team.'
      using errcode = 'P0001', detail = 'reserved_slot';
  end if;

  if not target_published and not (target_is_upcoming and is_unlimited_claimant) then
    raise exception 'Sign-ups for this event haven''t opened yet.'
      using errcode = 'P0001', detail = 'not_open';
  end if;

  -- ── Strike gate ────────────────────────────────────────────────────────
  if not target_is_member_train and not is_unlimited_claimant then

    select coalesce(sum(st.points), 0)
    into strike_points
    from public.member_strikes st
    where st.username_key = lower(clean_username)
      and st.cleared_at is null
      and (st.penalty_train_id is null or st.penalty_train_id = target_train_id);

    select coalesce(nullif(value, '')::integer, 1)
    into strike_threshold
    from public.app_settings
    where key = 'strike_block_threshold';

    strike_threshold := coalesce(strike_threshold, 1);

    if strike_points >= strike_threshold then
      update public.member_strikes
      set penalty_train_id = target_train_id
      where username_key = lower(clean_username)
        and cleared_at is null
        and penalty_train_id is null;

      select public.strike_reason_label(st.reason), coalesce(t.name, 'a previous event')
      into strike_reason, strike_train_name
      from public.member_strikes st
      left join public.trains t on t.id = st.train_id
      where st.username_key = lower(clean_username)
        and st.cleared_at is null
        and st.penalty_train_id = target_train_id
      order by st.created_at desc
      limit 1;

      select value into block_message
      from public.app_settings
      where key = 'strike_block_message';

      block_message := coalesce(
        nullif(block_message, ''),
        'You''re sitting out this event because of {reason} at {train}. You can still sign up for member-created trains.'
      );

      block_message := replace(block_message, '{reason}', coalesce(strike_reason, 'a reported issue'));
      block_message := replace(block_message, '{train}',  coalesce(strike_train_name, 'a previous event'));
      block_message := replace(block_message, '{username}', clean_username);

      raise exception '%', block_message
        using errcode = 'P0001', detail = 'strike_block';
    end if;
  end if;
  -- ── End strike gate ────────────────────────────────────────────────────

  perform pg_advisory_xact_lock(hashtext(target_train_id::text), hashtext(lower(clean_username)));

  if not is_unlimited_claimant and exists (
    select 1
    from public.slots existing
    join public.train_days existing_day on existing_day.id = existing.train_day_id
    where existing_day.train_id = target_train_id
      and lower(existing.username) = lower(clean_username)
  ) then
    raise exception 'You are already signed up for a slot on this train.' using errcode = 'P0001';
  end if;

  update public.slots s
  set username = clean_username
  where s.id = slot_id
    and s.username is null
    and (s.is_pre_assigned = false or is_unlimited_claimant)
    and exists (
      select 1
      from public.train_days d
      join public.trains t on t.id = d.train_id
      where d.id = s.train_day_id
        and (t.published = true or (t.is_upcoming = true and is_unlimited_claimant))
        and ((lower(coalesce(s.label, '')) <> 'kickoff' and s.slot_order <> 0) or is_unlimited_claimant)
    )
  returning s.* into claimed;

  if not found then
    raise exception 'Sorry - this slot is no longer available.' using errcode = 'P0001';
  end if;

  return claimed;
end;
$$;

grant execute on function public.claim_slot(uuid, text) to anon, authenticated;
