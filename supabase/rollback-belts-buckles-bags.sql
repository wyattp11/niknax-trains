-- ============================================================
-- ROLLBACK: Belts, Buckles & Bags — restore the pre-change schedule
-- ============================================================
--
-- Restores the exact state captured by the diagnostic before the start time
-- was changed to 11:30 AM: a 4:30 PM kickoff followed by 20 contiguous
-- 30-minute slots running to 2:40 AM, with every seller in their original
-- position.
--
-- Matching is by username (the kickoff by its label), because slot ids
-- weren't captured. Sellers are unique within the day, so this is exact.
--
-- SAFE TO INSPECT FIRST: run everything down to the COMMIT, check the
-- verification output, and only then commit. Nothing is deleted — only
-- start_time, duration_min, and slot_order are rewritten.
-- ============================================================

begin;

-- Guard: bail out if this doesn't resolve to exactly one day
do $$
declare
  v_days integer;
begin
  select count(*) into v_days
  from public.train_days d
  join public.trains t on t.id = d.train_id
  where t.name ilike '%belts%buckles%';

  if v_days <> 1 then
    raise exception 'Expected exactly 1 day for this train, found %. Aborting.', v_days;
  end if;
end
$$;


with target as (
  select d.id as day_id
  from public.train_days d
  join public.trains t on t.id = d.train_id
  where t.name ilike '%belts%buckles%'
  limit 1
),
snapshot(slot_order, start_time, duration_min, seller) as (
  values
    (0,  '16:30'::time, 10, null),
    (1,  '16:40'::time, 30, 'tiffaneytreasurechest'),
    (2,  '17:10'::time, 30, 'Hodese62'),
    (3,  '17:40'::time, 30, 'kandmvintage'),
    (4,  '18:10'::time, 30, 'rebeljunque'),
    (5,  '18:40'::time, 30, 'anewleafhilda'),
    (6,  '19:10'::time, 30, 'secondwindkelly'),
    (7,  '19:40'::time, 30, 'thefiligreefinch'),
    (8,  '20:10'::time, 30, 'gigisvaultvariety'),
    (9,  '20:40'::time, 30, 'Aeressdesigns'),
    (10, '21:10'::time, 30, 'Unique around the corner'),
    (11, '21:40'::time, 30, 'Powellhousevintage'),
    (12, '22:10'::time, 30, 'HiddenHouseStore'),
    (13, '22:40'::time, 30, 'Muchadoaboutjunkin (Thera & Rick)'),
    (14, '23:10'::time, 30, 'rummagejunkie'),
    (15, '23:40'::time, 30, 'Southmont Vintage'),
    (16, '00:10'::time, 30, 'HOPEHOW'),
    (17, '00:40'::time, 30, 'doesitglowgalmichelle'),
    (18, '01:10'::time, 30, 'moonchild0702 Sandy'),
    (19, '01:40'::time, 30, 'Jk'),
    (20, '02:10'::time, 30, 'Keenlykristin')
)
update public.slots s
set start_time   = snap.start_time,
    duration_min = snap.duration_min,
    slot_order   = snap.slot_order
from snapshot snap, target
where s.train_day_id = target.day_id
  and (
    -- Kickoff row matched by label
    (snap.seller is null and lower(coalesce(s.label, '')) = 'kickoff')
    -- Seller rows matched by username
    or (snap.seller is not null and lower(s.username) = lower(snap.seller))
  );


-- ── Verification — review before committing ──────────────────────────────

select
  s.slot_order                          as ord,
  to_char(s.start_time, 'HH12:MI AM')   as starts,
  s.duration_min                        as mins,
  coalesce(s.label, '')                 as label,
  coalesce(s.username, '—')             as seller,
  case
    when s.start_time = lag(s.start_time) over (order by s.slot_order)
         + (lag(s.duration_min) over (order by s.slot_order) * interval '1 minute')
      then 'ok'
    when lag(s.start_time) over (order by s.slot_order) is null
      then 'first'
    else '*** GAP OR OVERLAP ***'
  end                                   as contiguity
from public.slots s
join public.train_days d on d.id = s.train_day_id
join public.trains t on t.id = d.train_id
where t.name ilike '%belts%buckles%'
order by s.slot_order;

-- Anything left unmatched? Should return zero rows.
select s.id, s.slot_order, s.start_time, s.username, s.label
from public.slots s
join public.train_days d on d.id = s.train_day_id
join public.trains t on t.id = d.train_id
where t.name ilike '%belts%buckles%'
  and s.slot_order not between 0 and 20;


-- If the verification looks right:
commit;

-- If anything looks wrong instead, run:
--   rollback;
