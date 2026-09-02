-- ============================================================
-- ROLLBACK from the audit log — Belts, Buckles & Bags
-- Restores the schedule to its state immediately BEFORE the
-- admin's start-time change on Sep 02.
-- ============================================================
--
-- Anchors on the audit row itself rather than a typed timestamp, so there's
-- no timezone guesswork: the cutoff is the admin's UPDATE burst that changed
-- only start_time.
--
-- For each slot and each column, it takes the OLDEST recorded old_value at or
-- after that cutoff. Because a column only appears in the log when it actually
-- changed, that value is by definition what the column held before the cutoff
-- — even if the column wasn't touched until a later edit.
--
-- Only scheduling fields are reverted: start_time, slot_order, duration_min.
-- username, seller_link, and label are left exactly as they are, so sellers
-- keep their slots and their District links.
--
-- Every UPDATE after the cutoff was an UPDATE — no inserts or deletes — so
-- all 21 rows still exist and a pure revert is complete.
--
-- SAFE: runs in a transaction, prints a before/after comparison, and only
-- commits at the end. Review the output first.
-- ============================================================

begin;

create temporary table _restore on commit drop as
with target as (
  select id from public.trains where name ilike '%belts%buckles%' limit 1
),
cutoff as (
  -- The admin's start-time-only burst. If this returns nothing, adjust the
  -- filter; if it returns the wrong burst, add an explicit created_at bound.
  select min(a.created_at) as at
  from public.audit_log a, target t
  where a.train_id = t.id
    and a.table_name = 'slots'
    and a.action = 'UPDATE'
    and a.actor = 'admin'
    and a.changed_cols = array['start_time']
),
changes as (
  select a.row_id, a.created_at, a.old_values
  from public.audit_log a, target t, cutoff c
  where a.train_id = t.id
    and a.table_name = 'slots'
    and a.action = 'UPDATE'
    and a.created_at >= c.at
)
select
  row_id,
  -- Oldest recorded old_value per column = the value held before the cutoff
  (select ch.old_values->>'start_time'   from changes ch
    where ch.row_id = c2.row_id and ch.old_values ? 'start_time'
    order by ch.created_at limit 1)                        as start_time,
  (select ch.old_values->>'slot_order'   from changes ch
    where ch.row_id = c2.row_id and ch.old_values ? 'slot_order'
    order by ch.created_at limit 1)                        as slot_order,
  (select ch.old_values->>'duration_min' from changes ch
    where ch.row_id = c2.row_id and ch.old_values ? 'duration_min'
    order by ch.created_at limit 1)                        as duration_min
from (select distinct row_id from changes) c2;


-- ── Preview: what will change ────────────────────────────────────────────

select
  coalesce(s.username, '(open)')                          as seller,
  coalesce(s.label, '')                                   as label,
  to_char(s.start_time, 'HH24:MI')                        as time_now,
  coalesce(r.start_time, to_char(s.start_time, 'HH24:MI:SS')) as time_restored,
  s.slot_order                                            as ord_now,
  coalesce(r.slot_order::integer, s.slot_order)           as ord_restored,
  case
    when r.start_time is null and r.slot_order is null then 'unchanged'
    when r.start_time::time is distinct from s.start_time
      or r.slot_order::integer is distinct from s.slot_order then '← REVERTING'
    else 'already correct'
  end                                                     as effect
from public.slots s
join public.train_days d on d.id = s.train_day_id
join public.trains t on t.id = d.train_id
left join _restore r on r.row_id = s.id
where t.name ilike '%belts%buckles%'
order by coalesce(r.slot_order::integer, s.slot_order);


-- ── Apply ────────────────────────────────────────────────────────────────

update public.slots s
set start_time   = coalesce(r.start_time::time,      s.start_time),
    slot_order   = coalesce(r.slot_order::integer,   s.slot_order),
    duration_min = coalesce(r.duration_min::integer, s.duration_min)
from _restore r
where r.row_id = s.id;


-- ── Verify: contiguous, ascending, no gaps ───────────────────────────────

select
  s.slot_order                        as ord,
  to_char(s.start_time, 'HH12:MI AM') as starts,
  s.duration_min                      as mins,
  coalesce(s.label, '')               as label,
  coalesce(s.username, '—')           as seller,
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

-- Duplicate slot_order would mean the restore was incomplete. Expect 0 rows.
select s.slot_order, count(*)
from public.slots s
join public.train_days d on d.id = s.train_day_id
join public.trains t on t.id = d.train_id
where t.name ilike '%belts%buckles%'
group by s.slot_order having count(*) > 1;


-- Looks right?
commit;

-- Otherwise:
--   rollback;
