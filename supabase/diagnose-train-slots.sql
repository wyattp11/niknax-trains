-- ============================================================
-- TRAIN SLOT DIAGNOSTIC
-- Paste into Supabase → SQL Editor, edit the name on the next
-- line, run, then copy the whole result table back to Claude.
-- ============================================================

with target as (
  select id, name, is_member_train, conductor_username
  from public.trains
  -- ↓↓↓ EDIT THIS: any part of the train name, case-insensitive ↓↓↓
  where name ilike '%glass%'
  order by created_at desc
  limit 1
),
rows as (
  select
    d.day_date,
    d.day_order,
    s.slot_order,
    s.start_time,
    s.duration_min,
    (s.start_time + (s.duration_min * interval '1 minute'))::time as computed_end,
    s.label,
    s.username,
    s.is_pre_assigned,
    lag(s.start_time)  over w as prev_start,
    lag(s.duration_min) over w as prev_dur,
    lead(s.start_time) over w as next_start
  from target t
  join public.train_days d on d.train_id = t.id
  join public.slots      s on s.train_day_id = d.id
  window w as (partition by d.id order by s.slot_order)
)
select
  (select name from target)               as train,
  (select case when is_member_train then 'MEMBER (@' || coalesce(conductor_username,'?') || ')'
               else 'Niknax' end from target) as kind,
  day_date,
  slot_order                              as ord,
  to_char(start_time, 'HH12:MI AM')       as starts,
  duration_min                            as mins,
  to_char(computed_end, 'HH12:MI AM')     as ends,
  coalesce(label, '')                     as label,
  coalesce(username, '—')                 as seller,
  case when is_pre_assigned then 'yes' else '' end as reserved,
  -- Gap (or overlap) between the previous slot's end and this slot's start
  case
    when prev_start is null then ''
    else (extract(epoch from (
            start_time - (prev_start + (prev_dur * interval '1 minute'))::time
         )) / 60)::integer::text || ' min'
  end                                     as gap_from_prev,
  -- Problem flags
  trim(concat_ws(' | ',
    case when prev_start is not null
          and start_time < (prev_start + (prev_dur * interval '1 minute'))::time
         then 'OVERLAPS PREVIOUS' end,
    case when prev_start is not null
          and start_time > (prev_start + (prev_dur * interval '1 minute'))::time
         then 'GAP' end,
    case when next_start is not null and next_start < start_time
         then 'OUT OF ORDER (next slot starts earlier)' end,
    case when duration_min is null or duration_min <= 0
         then 'BAD DURATION' end
  ))                                      as problem
from rows
order by day_order nulls last, day_date, slot_order;
