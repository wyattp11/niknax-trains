-- ============================================================
-- MEMBER-TRAIN RPCS — token auth + full schedule control
-- ============================================================
--
-- Every conductor write RPC now proves access with a session token instead
-- of a self-declared username. The second argument keeps its name and type
-- (text) but now carries the token, so no signatures change.
--
-- require_conductor() raises if the token is invalid and records the
-- conductor's email as the audit actor when it isn't.
--
-- Also adds the two capabilities conductors were missing:
--   • regenerate_member_train_schedule — start time, slot count, duration
--     and kickoff, the same regeneration admins have
--   • clear_member_train_slot_seller — release a slot after a no-show
--
-- create_member_train is unchanged here: at creation there's no session yet,
-- so it still authenticates by member username and registers the creator's
-- email as the primary conductor (see the accompanying migration).
-- ============================================================


-- ── Train details ─────────────────────────────────────────────────────────

create or replace function public.update_member_train(
  p_train_id      uuid,
  p_conductor     text,          -- session token
  p_name          text,
  p_tagline       text default null,
  p_description   text default null,
  p_district_link text default null
)
returns public.trains
language plpgsql
security definer
set search_path = public
as $$
declare
  updated public.trains;
begin
  perform public.require_conductor(p_train_id, p_conductor);

  if length(trim(coalesce(p_name, ''))) = 0 then
    raise exception 'Train name is required.' using errcode = '22023';
  end if;

  update public.trains set
    name          = trim(p_name),
    tagline       = nullif(trim(coalesce(p_tagline, '')), ''),
    description   = nullif(trim(coalesce(p_description, '')), ''),
    district_link = nullif(trim(coalesce(p_district_link, '')), '')
  where id = p_train_id and is_member_train = true
  returning * into updated;

  if not found then
    raise exception 'Train not found.' using errcode = 'P0001';
  end if;

  return updated;
end;
$$;

grant execute on function public.update_member_train(uuid, text, text, text, text, text)
  to anon, authenticated;


create or replace function public.delete_member_train(p_train_id uuid, p_conductor text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_conductor(p_train_id, p_conductor);

  delete from public.slots
  where train_day_id in (select id from public.train_days where train_id = p_train_id);
  delete from public.train_days where train_id = p_train_id;
  delete from public.trains where id = p_train_id and is_member_train = true;
end;
$$;

grant execute on function public.delete_member_train(uuid, text) to anon, authenticated;


-- ── Days ──────────────────────────────────────────────────────────────────

create or replace function public.add_member_train_day(
  p_train_id         uuid,
  p_conductor        text,       -- session token
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
  v_next_order integer;
  new_day      public.train_days;
  result_slots jsonb;
  kickoff_dur  integer;
  order_base   integer;
  i            integer;
begin
  perform public.require_conductor(p_train_id, p_conductor);

  select coalesce(max(day_order) + 1, 0) into v_next_order
  from public.train_days where train_id = p_train_id;

  insert into public.train_days (train_id, day_date, day_label, day_order)
  values (p_train_id, p_day_date,
          nullif(trim(coalesce(p_day_label, '')), ''), v_next_order)
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
      p_start_time + (kickoff_dur * interval '1 minute')
                   + ((i - 1) * coalesce(p_slot_duration, 30) * interval '1 minute'),
      coalesce(p_slot_duration, 30), null, null, null, false, i - 1 + order_base
    );
  end loop;

  select jsonb_build_object(
    'day', to_jsonb(new_day),
    'slots', coalesce(jsonb_agg(to_jsonb(s) order by s.slot_order), '[]'::jsonb)
  )
  into result_slots
  from public.slots s where s.train_day_id = new_day.id;

  return result_slots;
end;
$$;

grant execute on function
  public.add_member_train_day(uuid, text, date, text, time, integer, integer, boolean, integer)
  to anon, authenticated;


create or replace function public.remove_member_train_day(
  p_train_id uuid, p_conductor text, p_day_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_conductor(p_train_id, p_conductor);

  if not exists (
    select 1 from public.train_days where id = p_day_id and train_id = p_train_id
  ) then
    raise exception 'Day not found on this train.' using errcode = 'P0001';
  end if;

  delete from public.slots where train_day_id = p_day_id;
  delete from public.train_days where id = p_day_id;
end;
$$;

grant execute on function public.remove_member_train_day(uuid, text, uuid) to anon, authenticated;


-- ── Schedule regeneration (new) ───────────────────────────────────────────
-- The capability conductors were missing. Mirrors the admin form: set the
-- day's start time, slot length, and count, and the day is rebuilt around it.

create or replace function public.regenerate_member_train_schedule(
  p_train_id         uuid,
  p_token            text,
  p_day_id           uuid,
  p_start_time       time,
  p_slot_duration    integer,
  p_slot_count       integer,
  p_include_kickoff  boolean default true,
  p_kickoff_duration integer default 10
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_kickoff      public.slots;
  v_kickoff_dur  integer;
  v_order_base   integer;
  v_seller_ids   uuid[];
  v_seller_count integer;
  v_time         time;
  i              integer;
begin
  perform public.require_conductor(p_train_id, p_token);

  if not exists (
    select 1 from public.train_days where id = p_day_id and train_id = p_train_id
  ) then
    raise exception 'Day not found on this train.' using errcode = 'P0001';
  end if;

  if coalesce(p_slot_duration, 0) < 5 or p_slot_duration > 120 then
    raise exception 'Slot duration must be between 5 and 120 minutes.' using errcode = '22023';
  end if;

  if coalesce(p_slot_count, 0) < 1 or p_slot_count > 100 then
    raise exception 'Slot count must be between 1 and 100.' using errcode = '22023';
  end if;

  select * into v_kickoff
  from public.slots
  where train_day_id = p_day_id
    and lower(coalesce(label, '')) = 'kickoff'
  order by slot_order
  limit 1;

  if coalesce(p_include_kickoff, true) then
    v_kickoff_dur := coalesce(p_kickoff_duration, 10);
    v_order_base  := 1;
    if v_kickoff.id is not null then
      update public.slots
      set start_time = p_start_time, duration_min = v_kickoff_dur,
          label = 'Kickoff', slot_order = 0
      where id = v_kickoff.id;
    else
      insert into public.slots
        (train_day_id, start_time, duration_min, username, seller_link, label, is_pre_assigned, slot_order)
      values (p_day_id, p_start_time, v_kickoff_dur, null, null, 'Kickoff', false, 0);
    end if;
  else
    v_kickoff_dur := 0;
    v_order_base  := 0;
    if v_kickoff.id is not null then
      delete from public.slots where id = v_kickoff.id;
    end if;
  end if;

  -- Seller slots in current order. Sign-ups are preserved by position:
  -- slot 1 keeps its seller, slot 2 keeps theirs, and so on.
  select array_agg(id order by slot_order)
  into v_seller_ids
  from public.slots
  where train_day_id = p_day_id
    and lower(coalesce(label, '')) <> 'kickoff';

  v_seller_count := coalesce(array_length(v_seller_ids, 1), 0);

  for i in 1..least(v_seller_count, p_slot_count) loop
    v_time := (p_start_time
               + (v_kickoff_dur * interval '1 minute')
               + ((i - 1) * p_slot_duration * interval '1 minute'))::time;
    update public.slots
    set start_time = v_time,
        duration_min = p_slot_duration,
        slot_order = i - 1 + v_order_base
    where id = v_seller_ids[i];
  end loop;

  -- Grow
  if p_slot_count > v_seller_count then
    for i in (v_seller_count + 1)..p_slot_count loop
      v_time := (p_start_time
                 + (v_kickoff_dur * interval '1 minute')
                 + ((i - 1) * p_slot_duration * interval '1 minute'))::time;
      insert into public.slots
        (train_day_id, start_time, duration_min, username, seller_link, label, is_pre_assigned, slot_order)
      values (p_day_id, v_time, p_slot_duration, null, null, null, false, i - 1 + v_order_base);
    end loop;
  end if;

  -- Shrink (drops any sign-ups in the removed rows — the UI warns first)
  if p_slot_count < v_seller_count then
    delete from public.slots
    where id = any(v_seller_ids[(p_slot_count + 1):v_seller_count]);
  end if;

  return (
    select coalesce(jsonb_agg(to_jsonb(s) order by s.slot_order), '[]'::jsonb)
    from public.slots s where s.train_day_id = p_day_id
  );
end;
$$;

grant execute on function
  public.regenerate_member_train_schedule(uuid, text, uuid, time, integer, integer, boolean, integer)
  to anon, authenticated;


-- ── Individual slots ──────────────────────────────────────────────────────

create or replace function public.add_member_train_slot(
  p_train_id uuid, p_conductor text, p_day_id uuid,
  p_start_time time, p_duration integer default 30, p_label text default null
)
returns public.slots
language plpgsql
security definer
set search_path = public
as $$
declare
  v_base_minutes integer;
  v_new_abs      integer;
  v_new_order    integer;
  new_slot       public.slots;
begin
  perform public.require_conductor(p_train_id, p_conductor);

  if not exists (
    select 1 from public.train_days where id = p_day_id and train_id = p_train_id
  ) then
    raise exception 'Day not found on this train.' using errcode = 'P0001';
  end if;

  select (extract(hour from s.start_time)::integer * 60
          + extract(minute from s.start_time)::integer)
  into v_base_minutes
  from public.slots s
  where s.train_day_id = p_day_id
  order by s.slot_order
  limit 1;

  v_base_minutes := coalesce(
    v_base_minutes,
    extract(hour from p_start_time)::integer * 60 + extract(minute from p_start_time)::integer
  );

  v_new_abs := public.slot_abs_minutes(p_start_time, v_base_minutes);

  select count(*) into v_new_order
  from public.slots s
  where s.train_day_id = p_day_id
    and public.slot_abs_minutes(s.start_time, v_base_minutes) < v_new_abs;

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


create or replace function public.edit_member_train_slot(
  p_train_id uuid, p_conductor text, p_slot_id uuid,
  p_start_time time default null, p_duration integer default null, p_label text default null
)
returns public.slots
language plpgsql
security definer
set search_path = public
as $$
declare
  v_day_id       uuid;
  v_base_minutes integer;
  updated_slot   public.slots;
  r              record;
  i              integer := 0;
begin
  perform public.require_conductor(p_train_id, p_conductor);

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
    label        = case when p_label is not null then nullif(trim(p_label), '') else label end
  where id = p_slot_id
  returning * into updated_slot;

  if p_start_time is not null then
    select (extract(hour from s.start_time)::integer * 60
            + extract(minute from s.start_time)::integer)
    into v_base_minutes
    from public.slots s where s.train_day_id = v_day_id
    order by s.slot_order limit 1;

    for r in
      select s.id from public.slots s
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


create or replace function public.delete_member_train_slot(
  p_train_id uuid, p_conductor text, p_slot_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_day_id uuid;
  v_dur    integer;
  v_order  integer;
begin
  perform public.require_conductor(p_train_id, p_conductor);

  select s.train_day_id, s.duration_min, s.slot_order
  into v_day_id, v_dur, v_order
  from public.slots s
  join public.train_days d on d.id = s.train_day_id
  where s.id = p_slot_id and d.train_id = p_train_id;

  if v_day_id is null then
    raise exception 'Slot not found on this train.' using errcode = 'P0001';
  end if;

  update public.slots
  set start_time = public.shift_time(start_time, -coalesce(v_dur, 30)),
      slot_order = slot_order - 1
  where train_day_id = v_day_id and slot_order > v_order;

  delete from public.slots where id = p_slot_id;
end;
$$;

grant execute on function public.delete_member_train_slot(uuid, text, uuid) to anon, authenticated;


-- ── Release a slot (new) ──────────────────────────────────────────────────

create or replace function public.clear_member_train_slot_seller(
  p_train_id uuid, p_token text, p_slot_id uuid
)
returns public.slots
language plpgsql
security definer
set search_path = public
as $$
declare
  cleared public.slots;
begin
  perform public.require_conductor(p_train_id, p_token);

  update public.slots s
  set username = null, seller_link = null
  where s.id = p_slot_id
    and exists (
      select 1 from public.train_days d
      where d.id = s.train_day_id and d.train_id = p_train_id
    )
  returning * into cleared;

  if not found then
    raise exception 'Slot not found on this train.' using errcode = 'P0001';
  end if;

  return cleared;
end;
$$;

grant execute on function public.clear_member_train_slot_seller(uuid, text, uuid)
  to anon, authenticated;


-- ── Chat lock ─────────────────────────────────────────────────────────────

create or replace function public.set_member_train_chat_locked(
  p_train_id uuid, p_conductor text, p_locked boolean
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_conductor(p_train_id, p_conductor);
  update public.trains set chat_locked = coalesce(p_locked, false)
  where id = p_train_id and is_member_train = true;
  return true;
end;
$$;

grant execute on function public.set_member_train_chat_locked(uuid, text, boolean)
  to anon, authenticated;


-- ── Chat moderation by conductors ─────────────────────────────────────────
-- delete_chat_message took a conductor username; it now accepts a token.

create or replace function public.delete_chat_message(
  p_message_id uuid,
  p_actor      text default null
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  msg_train_id uuid;
  allowed      boolean := false;
begin
  select m.train_id into msg_train_id
  from public.train_chat_messages m
  where m.id = p_message_id;

  if msg_train_id is null then
    return false;
  end if;

  if public.is_admin() then
    allowed := true;
  elsif public.conductor_email_for_token(msg_train_id, p_actor) is not null then
    allowed := true;
  end if;

  if not allowed then
    raise exception 'You do not have permission to remove this message.' using errcode = 'P0001';
  end if;

  delete from public.train_chat_messages where id = p_message_id;
  return true;
end;
$$;

grant execute on function public.delete_chat_message(uuid, text) to anon, authenticated;


-- ── Retire the orphaned _impl functions ───────────────────────────────────
-- The audit-actor migration wrapped these; the wrappers above now contain the
-- full implementation, so the _impl copies are dead code.

drop function if exists public.add_member_train_slot_impl(uuid, text, uuid, time, integer, text);
drop function if exists public.edit_member_train_slot_impl(uuid, text, uuid, time, integer, text);
drop function if exists public.delete_member_train_slot_impl(uuid, text, uuid);
