-- ============================================================
-- TRAIN FORENSICS — what can be reconstructed without an audit log
--
-- There is no change history. Edits overwrite in place, so previous
-- values are gone. What survives is slots.created_at: the original
-- generation batch shares a timestamp, so slots added later stand out.
--
-- Paste into Supabase → SQL Editor, edit the name below, run.
-- ============================================================

with target as (
  select id, name, created_at, is_member_train, conductor_username
  from public.trains
  -- ↓↓↓ EDIT THIS ↓↓↓
  where name ilike '%belts%'
  order by created_at desc
  limit 1
),
batched as (
  select
    d.day_date,
    s.slot_order,
    s.start_time,
    s.duration_min,
    s.username,
    s.label,
    s.created_at,
    -- Slots inserted within 5s of each other came from one action
    date_trunc('second', s.created_at) as created_sec,
    min(s.created_at) over (partition by d.id) as first_insert,
    (select created_at from target)            as train_created
  from target t
  join public.train_days d on d.train_id = t.id
  join public.slots      s on s.train_day_id = d.id
)
select
  day_date,
  slot_order                                   as ord,
  to_char(start_time, 'HH12:MI AM')            as starts,
  duration_min                                 as mins,
  coalesce(username, '—')                      as seller,
  coalesce(label, '')                          as label,
  to_char(created_at, 'Mon DD HH24:MI:SS')     as row_created,
  -- Anything more than a minute after the first insert was added later
  case
    when created_at <= first_insert + interval '1 minute'
      then 'original batch'
    else 'ADDED LATER (+'
         || round(extract(epoch from (created_at - first_insert)) / 3600)::text
         || 'h after setup)'
  end                                          as origin
from batched
order by day_date, slot_order;


-- ── Summary: how many insert batches touched this train ──────────────
-- Several distinct groups here means the schedule was edited after setup.

with target as (
  select id from public.trains
  where name ilike '%belts%'          -- ← same name as above
  order by created_at desc limit 1
)
select
  to_char(date_trunc('minute', s.created_at), 'Mon DD HH24:MI') as insert_batch,
  count(*)                                                      as slots_added,
  to_char(min(s.start_time), 'HH12:MI AM')                      as earliest_time,
  to_char(max(s.start_time), 'HH12:MI AM')                      as latest_time
from target t
join public.train_days d on d.train_id = t.id
join public.slots      s on s.train_day_id = d.id
group by date_trunc('minute', s.created_at)
order by 1;
