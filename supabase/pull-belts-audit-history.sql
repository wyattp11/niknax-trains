-- ============================================================
-- PULL: audit history for Belts, Buckles & Bags
-- Run all three, paste the results back.
-- ============================================================

-- ── 1. Edit sessions: when the train was touched, and by whom ────────────
-- Groups changes into bursts so the 11:30 AM edit stands out as one block.

select
  to_char(date_trunc('minute', a.created_at), 'Mon DD HH24:MI') as edit_session,
  a.actor,
  a.table_name,
  a.action,
  count(*)                                                       as rows_changed,
  array_agg(distinct col)                                        as columns_touched
from public.audit_log a
join public.trains t on t.id = a.train_id
left join lateral unnest(a.changed_cols) as col on true
where t.name ilike '%belts%buckles%'
group by date_trunc('minute', a.created_at), a.actor, a.table_name, a.action
order by date_trunc('minute', a.created_at);


-- ── 2. The start-time change itself, slot by slot ────────────────────────
-- Shows the before/after for every slot whose time moved. If the kickoff is
-- absent from this list, that confirms it was never rewritten — the bug.

select
  to_char(a.created_at, 'Mon DD HH24:MI:SS')      as changed_at,
  a.old_values->>'start_time'                     as time_before,
  a.new_values->>'start_time'                     as time_after,
  a.old_values->>'slot_order'                     as order_before,
  a.new_values->>'slot_order'                     as order_after,
  a.old_values->>'duration_min'                   as dur_before,
  a.new_values->>'duration_min'                   as dur_after,
  coalesce(s.username, '(deleted row)')           as seller,
  coalesce(s.label, '')                           as label,
  a.row_id
from public.audit_log a
join public.trains t on t.id = a.train_id
left join public.slots s on s.id = a.row_id
where t.name ilike '%belts%buckles%'
  and a.table_name = 'slots'
  and a.action = 'UPDATE'
  and 'start_time' = any(a.changed_cols)
order by a.created_at, (a.new_values->>'slot_order')::integer nulls last;


-- ── 3. Reconstruct the state just BEFORE the first start_time change ─────
-- For each slot, the oldest recorded start_time/slot_order in that burst is
-- what it held before the edit. This is the authoritative rollback target.

with target as (
  select id from public.trains where name ilike '%belts%buckles%' limit 1
),
first_change as (
  select min(a.created_at) as at
  from public.audit_log a, target t
  where a.train_id = t.id
    and a.table_name = 'slots'
    and a.action = 'UPDATE'
    and 'start_time' = any(a.changed_cols)
),
earliest as (
  select distinct on (a.row_id)
    a.row_id,
    a.old_values->>'start_time'   as start_time,
    a.old_values->>'slot_order'   as slot_order,
    a.old_values->>'duration_min' as duration_min
  from public.audit_log a, target t, first_change f
  where a.train_id = t.id
    and a.table_name = 'slots'
    and a.action = 'UPDATE'
    and a.created_at >= f.at
    and 'start_time' = any(a.changed_cols)
  order by a.row_id, a.created_at
)
select
  e.slot_order                                     as ord_before,
  e.start_time                                     as time_before,
  e.duration_min                                   as dur_before,
  coalesce(s.username, '—')                        as seller,
  coalesce(s.label, '')                            as label,
  to_char(s.start_time, 'HH24:MI')                 as time_now,
  s.slot_order                                     as ord_now,
  e.row_id
from earliest e
left join public.slots s on s.id = e.row_id
order by nullif(e.slot_order, '')::integer nulls last;
