-- ============================================================
-- SLOT ORDERING + MIDNIGHT-SAFE TIME SHIFTING
-- ============================================================
--
-- Two defects in the member-train slot RPCs:
--
-- 1. add_member_train_slot took whatever start time the conductor typed and
--    assigned slot_order = max + 1. Adding a 2:00 PM slot to a day that
--    already ran to 8:00 PM parked it at the END of the list holding an early
--    time. Every view sorts by slot_order, so order and time disagreed — the
--    schedule read as scrambled. It also never pushed later slots back, so the
--    new slot silently overlapped whatever it landed on.
--
-- 2. delete_member_train_slot shifted later slots earlier with
--       (start_time::interval - v_dur * interval '1 minute')::time
--    which wraps to late evening when it crosses below midnight — the same
--    class of bug already fixed in the JS addMinutes().
--
-- Fixed by deriving slot_order from the time rather than appending, and by
-- doing all time arithmetic through a modulo-normalized helper.
-- ============================================================


-- ── Midnight-safe time shifting ───────────────────────────────────────────
-- Mirrors addMinutes() in src/lib/timeUtils.js: normalize into 0–1439 so a
-- negative shift wraps correctly instead of producing an invalid time.

create or replace function public.shift_time(p_time time, p_minutes integer)
returns time
language sql
immutable
as $$
  select time '00:00' + (
    ((
      (extract(hour from p_time)::integer * 60 + extract(minute from p_time)::integer)
      + coalesce(p_minutes, 0)
    ) % 1440 + 1440) % 1440
  ) * interval '1 minute';
$$;

grant execute on function public.shift_time(time, integer) to anon, authenticated;


-- ── Absolute minutes within a show night ──────────────────────────────────
-- Trains run past midnight, so a bare clock time is ambiguous. Anchored to the
-- day's first slot: anything earlier on the clock belongs to the next morning.
-- Valid for any show night shorter than 24 hours.

create or replace function public.slot_abs_minutes(p_time time, p_base_minutes integer)
returns integer
language sql
immutable
as $$
  select case
    when (extract(hour from p_time)::integer * 60 + extract(minute from p_time)::integer)
         < coalesce(p_base_minutes, 0)
    then (extract(hour from p_time)::integer * 60 + extract(minute from p_time)::integer) + 1440
    else (extract(hour from p_time)::integer * 60 + extract(minute from p_time)::integer)
  end;
$$;

grant execute on function public.slot_abs_minutes(time, integer) to anon, authenticated;


-- ============================================================
-- add_member_train_slot — insert in chronological position
-- ============================================================

create or replace function public.add_member_train_slot(
  p_train_id    uuid,
  p_conductor   text,
  p_day_id      uuid,
  p_start_time  time,
  p_duration    integer default 30,
  p_label       text    default null
)
returns public.slots
language plpgsql
security definer
set search_path = public
as $$
declare
  clean_conductor text;
  v_conductor     text;
  v_base_minutes  integer;
  v_new_abs       integer;
  v_new_order     integer;
  new_slot        public.slots;
begin
  clean_conductor := nullif(trim(regexp_replace(coalesce(p_conductor, ''), '^@+', '')), '');

  select conductor_username into v_conductor
  from public.trains
  where id = p_train_id and is_member_train = true;

  if not found or v_conductor is null or clean_conductor is null
     or lower(v_conductor) <> lower(clean_conductor) then
    raise exception 'Only the train conductor can add slots.' using errcode = 'P0001';
  end if;

  if not exists (
    select 1 from public.train_days where id = p_day_id and train_id = p_train_id
  ) then
    raise exception 'Day not found on this train.' using errcode = 'P0001';
  end if;

  -- Anchor: the first slot of the night defines where the clock "starts".
  select (extract(hour from s.start_time)::integer * 60
          + extract(minute from s.start_time)::integer)
  into v_base_minutes
  from public.slots s
  where s.train_day_id = p_day_id
  order by s.slot_order
  limit 1;

  -- Empty day — this slot becomes the anchor.
  v_base_minutes := coalesce(
    v_base_minutes,
    extract(hour from p_start_time)::integer * 60 + extract(minute from p_start_time)::integer
  );

  v_new_abs := public.slot_abs_minutes(p_start_time, v_base_minutes);

  -- Position = how many existing slots start before this one.
  select count(*)
  into v_new_order
  from public.slots s
  where s.train_day_id = p_day_id
    and public.slot_abs_minutes(s.start_time, v_base_minutes) < v_new_abs;

  -- Make room: everything at or after this position moves down one.
  update public.slots
  set slot_order = slot_order + 1
  where train_day_id = p_day_id
    and public.slot_abs_minutes(start_time, v_base_minutes) >= v_new_abs;

  insert into public.slots
    (train_day_id, start_time, duration_min, username, seller_link, label, is_pre_assigned, slot_order)
  values
    (p_day_id, p_start_time, greatest(coalesce(p_duration, 30), 1), null, null,
     nullif(trim(coalesce(p_label, '')), ''), false, v_new_order)
  returning * into new_slot;

  return new_slot;
end;
$$;

grant execute on function public.add_member_train_slot(uuid, text, uuid, time, integer, text)
  to anon, authenticated;


-- ============================================================
-- edit_member_train_slot — renumber if the time moved
-- ============================================================

create or replace function public.edit_member_train_slot(
  p_train_id   uuid,
  p_conductor  text,
  p_slot_id    uuid,
  p_start_time time    default null,
  p_duration   integer default null,
  p_label      text    default null
)
returns public.slots
language plpgsql
security definer
set search_path = public
as $$
declare
  clean_conductor text;
  v_conductor     text;
  v_day_id        uuid;
  v_base_minutes  integer;
  updated_slot    public.slots;
  r               record;
  i               integer := 0;
begin
  clean_conductor := nullif(trim(regexp_replace(coalesce(p_conductor, ''), '^@+', '')), '');

  select conductor_username into v_conductor
  from public.trains
  where id = p_train_id and is_member_train = true;

  if not found or v_conductor is null or clean_conductor is null
     or lower(v_conductor) <> lower(clean_conductor) then
    raise exception 'Only the train conductor can edit slots.' using errcode = 'P0001';
  end if;

  select s.train_day_id into v_day_id
  from public.slots s
  join public.train_days d on d.id = s.train_day_id
  where s.id = p_slot_id and d.train_id = p_train_id;

  if v_day_id is null then
    raise exception 'Slot not found on this train.' using errcode = 'P0001';
  end if;

  update public.slots set
    start_time   = coalesce(p_start_time, start_time),
    duration_min = coalesce(greatest(p_duration, 1), duration_min),
    label        = case
                     when p_label is not null then nullif(trim(p_label), '')
                     else label
                   end
  where id = p_slot_id
  returning * into updated_slot;

  -- Moving a slot's time can reorder the day. Renumber so slot_order and the
  -- clock never disagree.
  if p_start_time is not null then
    select (extract(hour from s.start_time)::integer * 60
            + extract(minute from s.start_time)::integer)
    into v_base_minutes
    from public.slots s
    where s.train_day_id = v_day_id
    order by s.slot_order
    limit 1;

    for r in
      select s.id
      from public.slots s
      where s.train_day_id = v_day_id
      order by public.slot_abs_minutes(s.start_time, coalesce(v_base_minutes, 0)), s.slot_order
    loop
      update public.slots set slot_order = i where id = r.id;
      i := i + 1;
    end loop;

    select * into updated_slot from public.slots where id = p_slot_id;
  end if;

  return updated_slot;
end;
$$;

grant execute on function public.edit_member_train_slot(uuid, text, uuid, time, integer, text)
  to anon, authenticated;


-- ============================================================
-- delete_member_train_slot — midnight-safe shift
-- ============================================================

create or replace function public.delete_member_train_slot(
  p_train_id  uuid,
  p_conductor text,
  p_slot_id   uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  clean_conductor text;
  v_conductor     text;
  v_day_id        uuid;
  v_dur           integer;
  v_order         integer;
begin
  clean_conductor := nullif(trim(regexp_replace(coalesce(p_conductor, ''), '^@+', '')), '');

  select conductor_username into v_conductor
  from public.trains
  where id = p_train_id and is_member_train = true;

  if not found or v_conductor is null or clean_conductor is null
     or lower(v_conductor) <> lower(clean_conductor) then
    raise exception 'Only the train conductor can delete slots.' using errcode = 'P0001';
  end if;

  select s.train_day_id, s.duration_min, s.slot_order
  into v_day_id, v_dur, v_order
  from public.slots s
  join public.train_days d on d.id = s.train_day_id
  where s.id = p_slot_id and d.train_id = p_train_id;

  if v_day_id is null then
    raise exception 'Slot not found on this train.' using errcode = 'P0001';
  end if;

  -- Close the gap. shift_time() normalizes modulo 1440, so a slot moving back
  -- across midnight lands correctly instead of wrapping to the evening.
  update public.slots
  set start_time = public.shift_time(start_time, -coalesce(v_dur, 30)),
      slot_order = slot_order - 1
  where train_day_id = v_day_id
    and slot_order > v_order;

  delete from public.slots where id = p_slot_id;
end;
$$;

grant execute on function public.delete_member_train_slot(uuid, text, uuid)
  to anon, authenticated;
