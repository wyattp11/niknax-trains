-- ============================================================
-- Conductors control their train's status
-- ============================================================
--
-- Conductors can now move their own train between Arriving Soon (upcoming)
-- and Now Boarding (published), so they don't need an admin for routine
-- scheduling.
--
-- The original design had admin approval as the gate — a member train stays
-- invisible until an admin publishes or marks it upcoming. That gate is kept:
-- a conductor can only change status on a train an admin has ALREADY approved
-- (one that is published or upcoming). A brand-new train sitting in "pending
-- review" can still only be released by an admin.
--
-- So the approval step survives, but day-to-day control moves to the person
-- actually running the event. If an admin unpublishes and un-marks a train,
-- it returns to pending and the conductor loses the toggle again.
-- ============================================================

create or replace function public.set_member_train_status(
  p_train_id uuid,
  p_token    text,
  p_status   text          -- 'upcoming' | 'boarding'
)
returns public.trains
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_train   public.trains;
  updated   public.trains;
begin
  perform public.require_conductor(p_train_id, p_token);

  select * into v_train from public.trains where id = p_train_id and is_member_train = true;

  if not found then
    raise exception 'Train not found.' using errcode = 'P0001';
  end if;

  -- Approval gate: an unreviewed train can only be released by an admin.
  if not v_train.published and not v_train.is_upcoming then
    raise exception 'This train is still awaiting review by the Niknax team. They''ll release it once approved.'
      using errcode = 'P0001', detail = 'pending_review';
  end if;

  if p_status not in ('upcoming', 'boarding') then
    raise exception 'Unknown status.' using errcode = '22023';
  end if;

  update public.trains set
    published   = (p_status = 'boarding'),
    is_upcoming = (p_status = 'upcoming')
  where id = p_train_id and is_member_train = true
  returning * into updated;

  return updated;
end;
$$;

grant execute on function public.set_member_train_status(uuid, text, text)
  to anon, authenticated;
