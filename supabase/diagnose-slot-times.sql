-- ============================================================
-- What time was actually stored?
-- Paste into Supabase → SQL Editor, edit the name, run.
-- ============================================================
--
-- Shows the raw stored value alongside how it renders, so a
-- write that landed as AM but displays as PM (or vice versa)
-- is immediately visible.

select
  t.name                                          as train,
  d.day_date,
  s.slot_order                                    as ord,
  s.start_time                                    as stored_raw,
  to_char(s.start_time, 'HH24:MI')                as stored_24h,
  to_char(s.start_time, 'HH12:MI AM')             as reads_as_et,
  -- The other zones, computed the same way the app does
  to_char(s.start_time - interval '1 hour', 'HH12:MI AM') as ct,
  to_char(s.start_time - interval '2 hour', 'HH12:MI AM') as mt,
  to_char(s.start_time - interval '3 hour', 'HH12:MI AM') as pt,
  s.duration_min                                  as mins,
  coalesce(s.label, '')                           as label,
  coalesce(s.username, '—')                        as seller
from public.slots s
join public.train_days d on d.id = s.train_day_id
join public.trains t on t.id = d.train_id
-- ↓↓↓ EDIT THIS ↓↓↓
where t.name ilike '%your train name%'
order by d.day_date, s.slot_order;


-- Who wrote these, and what the previous value was. Empty if the
-- audit-log migrations aren't applied.
select
  to_char(a.created_at, 'Mon DD HH24:MI:SS') as changed_at,
  a.actor,
  a.action,
  a.old_values->>'start_time'                as time_before,
  a.new_values->>'start_time'                as time_after
from public.audit_log a
join public.trains t on t.id = a.train_id
where t.name ilike '%your train name%'      -- same name as above
  and a.table_name = 'slots'
  and (a.action = 'INSERT' or 'start_time' = any(a.changed_cols))
order by a.created_at desc
limit 40;
