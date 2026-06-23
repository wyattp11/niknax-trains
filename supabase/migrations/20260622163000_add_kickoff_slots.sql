with missing_days as (
  select
    d.id as train_day_id,
    coalesce(min(s.start_time), time '00:00') as first_start
  from public.train_days d
  left join public.slots s on s.train_day_id = d.id
  group by d.id
  having not exists (
    select 1
    from public.slots existing
    where existing.train_day_id = d.id
      and lower(coalesce(existing.label, '')) = 'kickoff'
  )
),
shifted as (
  update public.slots s
  set slot_order = s.slot_order + 1
  from missing_days md
  where s.train_day_id = md.train_day_id
  returning s.id
)
insert into public.slots (
  train_day_id,
  start_time,
  duration_min,
  username,
  seller_link,
  label,
  is_pre_assigned,
  slot_order
)
select
  train_day_id,
  (first_start - interval '10 minutes')::time,
  10,
  null,
  null,
  'Kickoff',
  false,
  0
from missing_days;

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
  is_unlimited_claimant boolean := false;
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
      and lower(m.role) in ('nn owner', 'nn admin', 'nn moderator')
  )
  into is_unlimited_claimant;

  select d.train_id, t.published, t.is_upcoming, (lower(coalesce(s.label, '')) = 'kickoff' or s.slot_order = 0)
  into target_train_id, target_published, target_is_upcoming, target_is_kickoff
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

  if not target_published and not (target_is_upcoming and is_unlimited_claimant) then
    raise exception 'Only NN moderators and admins can sign up before this train is published.' using errcode = 'P0001';
  end if;

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
    and s.is_pre_assigned = false
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
