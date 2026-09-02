-- ============================================================
-- FIX: Belts, Buckles & Bags — renumber slot_order by time
-- ============================================================
--
-- The times are already correct. Every slot's start_time matches the time
-- rebeljunque encoded in its label ("4:30 tiffaneytreasurechest" sits at
-- 16:30, "11:30 kickoff!" at 11:30, and so on for all 21 rows).
--
-- Only slot_order is wrong. Sorted by slot_order the day currently reads
-- 16:30 → 21:30 and then jumps backwards to 11:30 → 16:00, which is what
-- made the second half render as the next calendar day.
--
-- Sorted by time it's a clean contiguous schedule: 11:30 AM → 10:00 PM,
-- 21 slots of 30 minutes, no midnight crossing. This just makes slot_order
-- agree with the clock.
--
-- Nothing else is touched — no times, sellers, links, or labels change.
-- ============================================================

begin;

-- ── Before ───────────────────────────────────────────────────────────────

select
  'BEFORE' as state,
  s.slot_order                        as ord,
  to_char(s.start_time, 'HH12:MI AM') as starts,
  coalesce(s.username, '—')           as seller,
  coalesce(s.label, '')               as label
from public.slots s
join public.train_days d on d.id = s.train_day_id
join public.trains t on t.id = d.train_id
where t.name ilike '%belts%buckles%'
order by s.slot_order;


-- ── Renumber by chronological time ───────────────────────────────────────
-- The kickoff keeps order 0 because it's also the earliest slot, so plain
-- time ordering already puts it first.

with target as (
  select d.id as day_id
  from public.train_days d
  join public.trains t on t.id = d.train_id
  where t.name ilike '%belts%buckles%'
  limit 1
),
ordered as (
  select
    s.id,
    (row_number() over (order by s.start_time, s.id) - 1)::integer as new_order
  from public.slots s, target
  where s.train_day_id = target.day_id
)
update public.slots s
set slot_order = o.new_order
from ordered o
where s.id = o.id
  and s.slot_order is distinct from o.new_order;


-- ── After: verify contiguity ─────────────────────────────────────────────

select
  'AFTER' as state,
  s.slot_order                        as ord,
  to_char(s.start_time, 'HH12:MI AM') as starts,
  s.duration_min                      as mins,
  coalesce(s.username, '—')           as seller,
  coalesce(s.label, '')               as label,
  case
    when lag(s.start_time) over w is null then 'first'
    when s.start_time = (lag(s.start_time) over w
         + (lag(s.duration_min) over w * interval '1 minute'))::time then 'ok'
    else '*** GAP OR OVERLAP ***'
  end                                 as contiguity
from public.slots s
join public.train_days d on d.id = s.train_day_id
join public.trains t on t.id = d.train_id
where t.name ilike '%belts%buckles%'
window w as (order by s.slot_order)
order by s.slot_order;

-- Sanity: no duplicate order, and no backwards jump. Expect 0 rows.
select 'DUPLICATE ORDER' as problem, s.slot_order, count(*)
from public.slots s
join public.train_days d on d.id = s.train_day_id
join public.trains t on t.id = d.train_id
where t.name ilike '%belts%buckles%'
group by s.slot_order having count(*) > 1;


commit;

-- If the AFTER listing doesn't read 11:30 AM → 10:00 PM cleanly, run:
--   rollback;
