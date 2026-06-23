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
begin
  clean_username := nullif(trim(regexp_replace(coalesce(claimant_username, ''), '^@+', '')), '');

  if clean_username is null then
    raise exception 'Please enter your username.' using errcode = '22023';
  end if;

  if length(clean_username) > 60 then
    raise exception 'Username is too long.' using errcode = '22023';
  end if;

  select d.train_id
  into target_train_id
  from public.slots s
  join public.train_days d on d.id = s.train_day_id
  where s.id = slot_id;

  if target_train_id is not null then
    perform pg_advisory_xact_lock(hashtext(target_train_id::text), hashtext(lower(clean_username)));
  end if;

  if exists (
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
        and t.published = true
    )
  returning s.* into claimed;

  if not found then
    raise exception 'Sorry - this slot is no longer available.' using errcode = 'P0001';
  end if;

  return claimed;
end;
$$;

grant execute on function public.claim_slot(uuid, text) to anon, authenticated;

create or replace view public.members_signup_search
with (security_invoker = false)
as
select username, lower(username) as username_key, role
from public.members
where can_go_live = true;

grant select on public.members_signup_search to anon, authenticated;

create or replace view public.members_public_badges
with (security_invoker = false)
as
select lower(username) as username_key, role
from public.members
where role is not null and trim(role) <> '';

grant select on public.members_public_badges to anon, authenticated;

insert into public.members (username, role, can_go_live, updated_at)
values
  ('pixiestix', 'NN Moderator', true, now()),
  ('koalateavintage', 'NN Moderator', true, now()),
  ('thiftydiytrish', 'NN Moderator', true, now()),
  ('thethriftingteacher', 'NN Moderator', true, now()),
  ('jolieflipsvintage', 'NN Moderator', true, now()),
  ('myflippingvanlife', 'NN Moderator', true, now()),
  ('candylandcuriosities', 'NN Moderator', true, now()),
  ('crazylamplady', 'Owner', true, now()),
  ('moonskyvintage', 'Administrator', true, now())
on conflict (username) do update
set role = excluded.role,
    can_go_live = true,
    updated_at = now();
