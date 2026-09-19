-- ============================================================
-- Which slots are showing a "Watch on District" link that may
-- belong to someone who is no longer in the slot?
-- Paste into Supabase → SQL Editor and run.
-- ============================================================
--
-- The 20260919100000 migration already cleared the unambiguous case (an empty
-- slot still holding a link) and added a trigger so it can't happen again.
-- This lists the cases a script shouldn't decide on its own: a slot where the
-- link's handle doesn't look like the seller sitting in it. Check by eye —
-- some sellers legitimately use a shop URL that doesn't contain their handle.

select
  t.name                                   as train,
  d.day_date,
  s.slot_order                             as ord,
  to_char(s.start_time, 'HH12:MI AM')      as starts,
  s.username                               as seller_now,
  s.seller_link,
  case
    when s.seller_link ilike '%' || s.username || '%' then 'handle matches'
    else 'HANDLE DOES NOT MATCH — check this one'
  end                                      as verdict
from public.slots s
join public.train_days d on d.id = s.train_day_id
join public.trains t     on t.id = d.train_id
where s.username    is not null
  and s.seller_link is not null
  and s.seller_link not ilike '%' || s.username || '%'
order by t.name, d.day_date, s.slot_order;


-- Should return zero rows now and forever — an empty slot holding a link.
-- If anything shows up here, the trigger isn't installed.
select
  t.name as train, d.day_date, s.slot_order as ord, s.seller_link
from public.slots s
join public.train_days d on d.id = s.train_day_id
join public.trains t     on t.id = d.train_id
where s.username is null
  and s.seller_link is not null
order by t.name, d.day_date, s.slot_order;


-- Confirm the trigger is in place.
select tgname, tgenabled
from pg_trigger
where tgrelid = 'public.slots'::regclass
  and tgname = 'trg_clear_seller_link_on_seller_change';
