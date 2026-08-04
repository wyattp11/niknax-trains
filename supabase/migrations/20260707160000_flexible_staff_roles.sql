-- ============================================================
-- FLEXIBLE STAFF ROLE MATCHING
-- ============================================================
--
-- Staff detection used to be an exact-match list:
--   lower(role) in ('nn owner', 'nn admin', 'nn moderator')
--
-- That broke as soon as the members CSV carried a different spelling.
-- "MODERATOR" and "NN Moderator" are the same person's job, but only the
-- second one could claim a reserved slot.
--
-- is_staff_role() now normalizes the badge (lowercase, punctuation and
-- underscores collapsed to spaces) and looks for owner / admin / moderator
-- as a whole word. So all of these qualify:
--
--   NN Moderator · MODERATOR · Moderator · nn_moderator · Mod
--   NN Owner     · OWNER     · Owner
--   NN Admin     · ADMIN     · Administrator
--
-- The tradeoff: a badge like "Shop Owner" would also qualify. Role labels
-- are set by admins only, and the Members tab now shows a Staff marker on
-- every qualifying row, so this stays auditable at a glance.
-- ============================================================

create or replace function public.is_staff_role(p_role text)
returns boolean
language sql
immutable
as $$
  select coalesce(
    regexp_replace(lower(trim(coalesce(p_role, ''))), '[^a-z]+', ' ', 'g')
      ~ '(^| )(owner|admin|administrator|moderator|mod)( |$)',
    false
  );
$$;

grant execute on function public.is_staff_role(text) to anon, authenticated;


-- ============================================================
-- claim_slot — same logic as 20260707120000, with the staff check
-- swapped for is_staff_role()
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
    raise exception 'Only NN moderators and admins can claim the Kickoff slot.' using errcode = 'P0001';
  end if;

  if target_is_pre_assigned and not target_is_kickoff and not is_unlimited_claimant then
    raise exception 'This is a reserved slot for NN moderators and admins.' using errcode = 'P0001';
  end if;

  if not target_published and not (target_is_upcoming and is_unlimited_claimant) then
    raise exception 'Only NN moderators and admins can sign up before this train is published.' using errcode = 'P0001';
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
