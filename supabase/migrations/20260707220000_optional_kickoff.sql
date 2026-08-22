-- ============================================================
-- OPTIONAL KICKOFF SLOT
-- ============================================================
--
-- Both member-train RPCs hardcoded a 10-minute Kickoff row, so trains that
-- don't run one had to have it deleted by hand every time. Kickoff is now
-- opt-in per day, with an adjustable duration — Jocelyn's kickoff and boost
-- shows aren't always 10 minutes.
--
-- Without a kickoff, seller slots begin at the day's start time rather than
-- after it, and slot_order starts at 0 instead of 1.
--
-- Both functions keep their original signatures with the new arguments
-- defaulted, so existing callers behave exactly as before.
--
-- NOTE: these replace the _impl functions created by the audit-actor
-- migration (20260707200100). The public wrappers are untouched.
-- ============================================================


create or replace function public.create_member_train_impl(
  p_username        text,
  p_name            text,
  p_tagline         text    default null,
  p_description     text    default null,
  p_district_link   text    default null,
  p_rules_md        text    default null,
  p_days            jsonb   default '[]'::jsonb
)
returns public.trains
language plpgsql
security definer
set search_path = public
as $$
declare
  clean_username text;
  new_train      public.trains;
  new_day_id     uuid;
  days_count     integer;
  day_idx        integer;
  day_obj        jsonb;
  slot_start     time;
  slot_dur       integer;
  slot_cnt       integer;
  want_kickoff   boolean;
  kickoff_dur    integer;
  order_base     integer;
  i              integer;
begin
  clean_username := nullif(trim(regexp_replace(coalesce(p_username, ''), '^@+', '')), '');

  if clean_username is null then
    raise exception 'Username is required.' using errcode = '22023';
  end if;

  if length(trim(coalesce(p_name, ''))) = 0 then
    raise exception 'Train name is required.' using errcode = '22023';
  end if;

  if not exists (
    select 1 from public.members
    where lower(username) = lower(clean_username)
      and can_go_live = true
  ) then
    raise exception 'Only authorized Niknax sellers can create a train.' using errcode = 'P0001';
  end if;

  insert into public.trains (
    name, tagline, description, district_link, rules_md,
    cover_url, published, is_upcoming,
    conductor_username, is_member_train
  ) values (
    trim(p_name),
    nullif(trim(coalesce(p_tagline, '')), ''),
    nullif(trim(coalesce(p_description, '')), ''),
    nullif(trim(coalesce(p_district_link, '')), ''),
    nullif(trim(coalesce(p_rules_md, '')), ''),
    null, false, false,
    clean_username, true
  )
  returning * into new_train;

  days_count := coalesce(jsonb_array_length(p_days), 0);

  for day_idx in 0..(days_count - 1) loop
    day_obj      := p_days->day_idx;
    slot_start   := (day_obj->>'start_time')::time;
    slot_dur     := coalesce((day_obj->>'slot_duration')::integer, 30);
    slot_cnt     := coalesce((day_obj->>'slot_count')::integer, 24);
    -- Default true so callers that omit the flag keep the old behaviour
    want_kickoff := coalesce((day_obj->>'include_kickoff')::boolean, true);
    kickoff_dur  := coalesce((day_obj->>'kickoff_duration')::integer, 10);

    insert into public.train_days (train_id, day_date, day_label, day_order)
    values (
      new_train.id,
      (day_obj->>'day_date')::date,
      nullif(trim(coalesce(day_obj->>'day_label', '')), ''),
      day_idx
    )
    returning id into new_day_id;

    if want_kickoff then
      insert into public.slots
        (train_day_id, start_time, duration_min, username, seller_link, label, is_pre_assigned, slot_order)
      values
        (new_day_id, slot_start, kickoff_dur, null, null, 'Kickoff', false, 0);
      order_base := 1;
    else
      kickoff_dur := 0;
      order_base  := 0;
    end if;

    for i in 1..slot_cnt loop
      insert into public.slots
        (train_day_id, start_time, duration_min, username, seller_link, label, is_pre_assigned, slot_order)
      values (
        new_day_id,
        slot_start
          + (kickoff_dur * interval '1 minute')
          + ((i - 1) * slot_dur * interval '1 minute'),
        slot_dur, null, null, null, false, i - 1 + order_base
      );
    end loop;
  end loop;

  return new_train;
end;
$$;

revoke all on function public.create_member_train_impl(text, text, text, text, text, text, jsonb)
  from anon, authenticated;


-- ── add_member_train_day ──────────────────────────────────────────────────

create or replace function public.add_member_train_day(
  p_train_id         uuid,
  p_conductor        text,
  p_day_date         date,
  p_day_label        text    default null,
  p_start_time       time    default '10:30',
  p_slot_duration    integer default 30,
  p_slot_count       integer default 24,
  p_include_kickoff  boolean default true,
  p_kickoff_duration integer default 10
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  clean_conductor text;
  v_conductor     text;
  v_next_order    integer;
  new_day         public.train_days;
  result_slots    jsonb;
  kickoff_dur     integer;
  order_base      integer;
  i               integer;
begin
  clean_conductor := nullif(trim(regexp_replace(coalesce(p_conductor, ''), '^@+', '')), '');

  perform public.set_audit_actor(clean_conductor);

  select conductor_username into v_conductor
  from public.trains
  where id = p_train_id and is_member_train = true;

  if not found or v_conductor is null or clean_conductor is null
     or lower(v_conductor) <> lower(clean_conductor) then
    raise exception 'Only the train conductor can add days.' using errcode = 'P0001';
  end if;

  select coalesce(max(day_order) + 1, 0) into v_next_order
  from public.train_days where train_id = p_train_id;

  insert into public.train_days (train_id, day_date, day_label, day_order)
  values (
    p_train_id,
    p_day_date,
    nullif(trim(coalesce(p_day_label, '')), ''),
    v_next_order
  )
  returning * into new_day;

  if coalesce(p_include_kickoff, true) then
    kickoff_dur := coalesce(p_kickoff_duration, 10);
    insert into public.slots
      (train_day_id, start_time, duration_min, username, seller_link, label, is_pre_assigned, slot_order)
    values
      (new_day.id, p_start_time, kickoff_dur, null, null, 'Kickoff', false, 0);
    order_base := 1;
  else
    kickoff_dur := 0;
    order_base  := 0;
  end if;

  for i in 1..coalesce(p_slot_count, 24) loop
    insert into public.slots
      (train_day_id, start_time, duration_min, username, seller_link, label, is_pre_assigned, slot_order)
    values (
      new_day.id,
      p_start_time
        + (kickoff_dur * interval '1 minute')
        + ((i - 1) * coalesce(p_slot_duration, 30) * interval '1 minute'),
      coalesce(p_slot_duration, 30), null, null, null, false, i - 1 + order_base
    );
  end loop;

  select jsonb_build_object(
    'day', to_jsonb(new_day),
    'slots', coalesce(jsonb_agg(to_jsonb(s) order by s.slot_order), '[]'::jsonb)
  )
  into result_slots
  from public.slots s
  where s.train_day_id = new_day.id;

  return result_slots;
end;
$$;

grant execute on function
  public.add_member_train_day(uuid, text, date, text, time, integer, integer, boolean, integer)
  to anon, authenticated;
