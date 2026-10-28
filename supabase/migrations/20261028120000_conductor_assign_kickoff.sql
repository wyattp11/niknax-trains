-- ============================================================
-- Conductors can put anyone in their train's Kickoff slot
-- ============================================================
--
-- The Kickoff slot can't be claimed from the public page — on Niknax-sponsored
-- trains that's deliberate, since the Niknax team runs the kickoff. On a
-- member train, though, nobody could fill it except Niknax staff, which left
-- the conductor with no way to choose their own kickoff host.
--
-- This lets a conductor of a MEMBER train set the Kickoff slot to any
-- username, or swap whoever is in it. Deliberately open:
--   • not limited to the authorized-sellers list ("anyone")
--   • allowed even if that person also has a regular slot on the train
--   • no strike check (member trains never had one)
--
-- Only the Kickoff slot. Regular slots still go through public sign-up, the
-- lobby substitute, or release. Clearing the kickoff uses the existing
-- clear_member_train_slot_seller.
--
-- The previous holder's show link is dropped by the
-- trg_clear_seller_link_on_seller_change trigger (20260919100000), and a
-- new holder waiting in the lobby is removed by the lobby trigger.
-- ============================================================

create or replace function public.assign_member_train_kickoff(
  p_train_id uuid,
  p_token    text,
  p_slot_id  uuid,
  p_username text
)
returns public.slots
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  clean_username text;
  v_slot         public.slots;
  v_member_name  text;
  updated        public.slots;
begin
  perform public.require_conductor(p_train_id, p_token);

  clean_username := nullif(trim(regexp_replace(coalesce(p_username, ''), '^@+', '')), '');

  if clean_username is null then
    raise exception 'Enter a username.' using errcode = '22023';
  end if;

  if length(clean_username) > 60 then
    raise exception 'Username is too long.' using errcode = '22023';
  end if;

  select s.* into v_slot
  from public.slots s
  join public.train_days d on d.id = s.train_day_id
  join public.trains t     on t.id = d.train_id
  where s.id = p_slot_id
    and d.train_id = p_train_id
    and t.is_member_train = true;

  if v_slot.id is null then
    raise exception 'Slot not found on this train.' using errcode = 'P0001';
  end if;

  if not (lower(coalesce(v_slot.label, '')) = 'kickoff' or v_slot.slot_order = 0) then
    raise exception 'Only the Kickoff slot can be assigned directly.' using errcode = 'P0001';
  end if;

  -- Use the member list's capitalization when it's someone we know.
  select username into v_member_name
  from public.members
  where lower(username) = lower(clean_username)
  limit 1;

  update public.slots
  set username = coalesce(v_member_name, clean_username)
  where id = p_slot_id
  returning * into updated;

  return updated;
end;
$$;

grant execute on function public.assign_member_train_kickoff(uuid, text, uuid, text)
  to anon, authenticated;
