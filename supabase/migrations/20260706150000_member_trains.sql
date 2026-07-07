-- ── Member Trains ─────────────────────────────────────────────────────────
-- Authorized sellers (can_go_live = true) can create their own public trains.
-- Admin approves by publishing / marking upcoming. Only the conductor and
-- admin can edit or delete. No moderator/owner/admin pre-assigned slots.

-- ── Schema additions ───────────────────────────────────────────────────────

alter table public.trains
  add column if not exists conductor_username text,
  add column if not exists is_member_train    boolean not null default false;

-- ── Read policies for member trains ───────────────────────────────────────
-- Member trains are community trains (not private drafts), so we let anon
-- read them even before admin publishes them. The UUID ID is effectively
-- unguessable so "security by obscurity" is acceptable here.

create policy "anon read member trains"
  on public.trains
  for select
  using (is_member_train = true);

create policy "anon read member train days"
  on public.train_days
  for select
  using (
    exists (
      select 1 from public.trains t
      where t.id = train_days.train_id
        and t.is_member_train = true
    )
  );

create policy "anon read member train slots"
  on public.slots
  for select
  using (
    exists (
      select 1
      from public.train_days d
      join public.trains t on t.id = d.train_id
      where d.id = slots.train_day_id
        and t.is_member_train = true
    )
  );

-- ── Helper macro (inlined in each function) ───────────────────────────────
-- Each RPC verifies: clean username, train is a member train, username is
-- the conductor. Shared boilerplate is repeated so each function is
-- self-contained.

-- ── 1. create_member_train ─────────────────────────────────────────────────

create or replace function public.create_member_train(
  p_username     text,
  p_name         text,
  p_tagline      text    default null,
  p_description  text    default null,
  p_district_link text   default null,
  p_rules_md     text    default null,
  p_days         jsonb   default '[]'::jsonb
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
  i              integer;
  kickoff_dur    constant integer := 10;
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
    day_obj    := p_days->day_idx;
    slot_start := (day_obj->>'start_time')::time;
    slot_dur   := coalesce((day_obj->>'slot_duration')::integer, 30);
    slot_cnt   := coalesce((day_obj->>'slot_count')::integer, 24);

    insert into public.train_days (train_id, day_date, day_label, day_order)
    values (
      new_train.id,
      (day_obj->>'day_date')::date,
      nullif(trim(coalesce(day_obj->>'day_label', '')), ''),
      day_idx
    )
    returning id into new_day_id;

    -- Kickoff slot (slot_order = 0)
    insert into public.slots
      (train_day_id, start_time, duration_min, username, seller_link, label, is_pre_assigned, slot_order)
    values
      (new_day_id, slot_start, kickoff_dur, null, null, 'Kickoff', false, 0);

    -- Open seller slots
    for i in 1..slot_cnt loop
      insert into public.slots
        (train_day_id, start_time, duration_min, username, seller_link, label, is_pre_assigned, slot_order)
      values (
        new_day_id,
        slot_start
          + (kickoff_dur * interval '1 minute')
          + ((i - 1) * slot_dur * interval '1 minute'),
        slot_dur, null, null, null, false, i
      );
    end loop;
  end loop;

  return new_train;
end;
$$;

grant execute on function public.create_member_train(text, text, text, text, text, text, jsonb)
  to anon, authenticated;

-- ── 2. update_member_train ─────────────────────────────────────────────────

create or replace function public.update_member_train(
  p_train_id      uuid,
  p_conductor     text,
  p_name          text,
  p_tagline       text  default null,
  p_description   text  default null,
  p_district_link text  default null
)
returns public.trains
language plpgsql
security definer
set search_path = public
as $$
declare
  clean_conductor text;
  v_conductor     text;
  updated_train   public.trains;
begin
  clean_conductor := nullif(trim(regexp_replace(coalesce(p_conductor, ''), '^@+', '')), '');

  select conductor_username into v_conductor
  from public.trains
  where id = p_train_id and is_member_train = true;

  if not found or v_conductor is null or lower(v_conductor) <> lower(clean_conductor) then
    raise exception 'Only the train conductor can edit this train.' using errcode = 'P0001';
  end if;

  update public.trains set
    name          = trim(p_name),
    tagline       = nullif(trim(coalesce(p_tagline, '')), ''),
    description   = nullif(trim(coalesce(p_description, '')), ''),
    district_link = nullif(trim(coalesce(p_district_link, '')), ''),
    updated_at    = now()
  where id = p_train_id
  returning * into updated_train;

  return updated_train;
end;
$$;

grant execute on function public.update_member_train(uuid, text, text, text, text, text)
  to anon, authenticated;

-- ── 3. delete_member_train ─────────────────────────────────────────────────

create or replace function public.delete_member_train(
  p_train_id  uuid,
  p_conductor text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  clean_conductor text;
  v_conductor     text;
begin
  clean_conductor := nullif(trim(regexp_replace(coalesce(p_conductor, ''), '^@+', '')), '');

  select conductor_username into v_conductor
  from public.trains
  where id = p_train_id and is_member_train = true;

  if not found or v_conductor is null or lower(v_conductor) <> lower(clean_conductor) then
    raise exception 'Only the train conductor can delete this train.' using errcode = 'P0001';
  end if;

  -- Delete in FK order
  delete from public.slots s
    using public.train_days d
    where s.train_day_id = d.id and d.train_id = p_train_id;

  delete from public.train_days where train_id = p_train_id;
  delete from public.trains     where id = p_train_id;
end;
$$;

grant execute on function public.delete_member_train(uuid, text)
  to anon, authenticated;

-- ── 4. add_member_train_day ────────────────────────────────────────────────

create or replace function public.add_member_train_day(
  p_train_id     uuid,
  p_conductor    text,
  p_day_date     date,
  p_day_label    text    default null,
  p_start_time   time    default '10:30',
  p_slot_duration integer default 30,
  p_slot_count   integer default 24
)
returns jsonb   -- { day: {...}, slots: [...] }
language plpgsql
security definer
set search_path = public
as $$
declare
  clean_conductor text;
  v_conductor     text;
  v_day_order     integer;
  new_day_id      uuid;
  kickoff_dur     constant integer := 10;
  i               integer;
  result_slots    jsonb;
begin
  clean_conductor := nullif(trim(regexp_replace(coalesce(p_conductor, ''), '^@+', '')), '');

  select conductor_username into v_conductor
  from public.trains
  where id = p_train_id and is_member_train = true;

  if not found or v_conductor is null or lower(v_conductor) <> lower(clean_conductor) then
    raise exception 'Only the train conductor can add days to this train.' using errcode = 'P0001';
  end if;

  select coalesce(max(day_order) + 1, 0) into v_day_order
  from public.train_days where train_id = p_train_id;

  insert into public.train_days (train_id, day_date, day_label, day_order)
  values (p_train_id, p_day_date, nullif(trim(coalesce(p_day_label, '')), ''), v_day_order)
  returning id into new_day_id;

  -- Kickoff
  insert into public.slots
    (train_day_id, start_time, duration_min, username, seller_link, label, is_pre_assigned, slot_order)
  values (new_day_id, p_start_time, kickoff_dur, null, null, 'Kickoff', false, 0);

  -- Open slots
  for i in 1..p_slot_count loop
    insert into public.slots
      (train_day_id, start_time, duration_min, username, seller_link, label, is_pre_assigned, slot_order)
    values (
      new_day_id,
      p_start_time
        + (kickoff_dur * interval '1 minute')
        + ((i - 1) * p_slot_duration * interval '1 minute'),
      p_slot_duration, null, null, null, false, i
    );
  end loop;

  select jsonb_build_object(
    'day', row_to_json(d)::jsonb,
    'slots', coalesce((
      select jsonb_agg(row_to_json(s)::jsonb order by s.slot_order)
      from public.slots s where s.train_day_id = new_day_id
    ), '[]'::jsonb)
  )
  into result_slots
  from public.train_days d
  where d.id = new_day_id;

  return result_slots;
end;
$$;

grant execute on function public.add_member_train_day(uuid, text, date, text, time, integer, integer)
  to anon, authenticated;

-- ── 5. remove_member_train_day ─────────────────────────────────────────────

create or replace function public.remove_member_train_day(
  p_train_id  uuid,
  p_conductor text,
  p_day_id    uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  clean_conductor text;
  v_conductor     text;
begin
  clean_conductor := nullif(trim(regexp_replace(coalesce(p_conductor, ''), '^@+', '')), '');

  select conductor_username into v_conductor
  from public.trains
  where id = p_train_id and is_member_train = true;

  if not found or v_conductor is null or lower(v_conductor) <> lower(clean_conductor) then
    raise exception 'Only the train conductor can remove days from this train.' using errcode = 'P0001';
  end if;

  -- Verify day belongs to this train
  if not exists (
    select 1 from public.train_days
    where id = p_day_id and train_id = p_train_id
  ) then
    raise exception 'Day not found on this train.' using errcode = 'P0001';
  end if;

  delete from public.slots where train_day_id = p_day_id;
  delete from public.train_days where id = p_day_id;
end;
$$;

grant execute on function public.remove_member_train_day(uuid, text, uuid)
  to anon, authenticated;

-- ── 6. add_member_train_slot ───────────────────────────────────────────────

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
  v_next_order    integer;
  new_slot        public.slots;
begin
  clean_conductor := nullif(trim(regexp_replace(coalesce(p_conductor, ''), '^@+', '')), '');

  select conductor_username into v_conductor
  from public.trains
  where id = p_train_id and is_member_train = true;

  if not found or v_conductor is null or lower(v_conductor) <> lower(clean_conductor) then
    raise exception 'Only the train conductor can add slots.' using errcode = 'P0001';
  end if;

  if not exists (
    select 1 from public.train_days where id = p_day_id and train_id = p_train_id
  ) then
    raise exception 'Day not found on this train.' using errcode = 'P0001';
  end if;

  select coalesce(max(slot_order) + 1, 1) into v_next_order
  from public.slots where train_day_id = p_day_id;

  insert into public.slots
    (train_day_id, start_time, duration_min, username, seller_link, label, is_pre_assigned, slot_order)
  values
    (p_day_id, p_start_time, p_duration, null, null,
     nullif(trim(coalesce(p_label, '')), ''), false, v_next_order)
  returning * into new_slot;

  return new_slot;
end;
$$;

grant execute on function public.add_member_train_slot(uuid, text, uuid, time, integer, text)
  to anon, authenticated;

-- ── 7. edit_member_train_slot ──────────────────────────────────────────────

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
  updated_slot    public.slots;
begin
  clean_conductor := nullif(trim(regexp_replace(coalesce(p_conductor, ''), '^@+', '')), '');

  select conductor_username into v_conductor
  from public.trains
  where id = p_train_id and is_member_train = true;

  if not found or v_conductor is null or lower(v_conductor) <> lower(clean_conductor) then
    raise exception 'Only the train conductor can edit slots.' using errcode = 'P0001';
  end if;

  -- Verify slot belongs to this train
  if not exists (
    select 1 from public.slots s
    join public.train_days d on d.id = s.train_day_id
    where s.id = p_slot_id and d.train_id = p_train_id
  ) then
    raise exception 'Slot not found on this train.' using errcode = 'P0001';
  end if;

  update public.slots set
    start_time   = coalesce(p_start_time, start_time),
    duration_min = coalesce(p_duration,   duration_min),
    label        = case
                     when p_label is not null then nullif(trim(p_label), '')
                     else label
                   end
  where id = p_slot_id
  returning * into updated_slot;

  return updated_slot;
end;
$$;

grant execute on function public.edit_member_train_slot(uuid, text, uuid, time, integer, text)
  to anon, authenticated;

-- ── 8. delete_member_train_slot ────────────────────────────────────────────
-- Deletes the slot and shifts later slots in the same day earlier by the
-- deleted slot's duration (same logic as the admin deleteSlot in TrainDetail).

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

  if not found or v_conductor is null or lower(v_conductor) <> lower(clean_conductor) then
    raise exception 'Only the train conductor can delete slots.' using errcode = 'P0001';
  end if;

  select s.train_day_id, s.duration_min, s.slot_order
  into v_day_id, v_dur, v_order
  from public.slots s
  join public.train_days d on d.id = s.train_day_id
  where s.id = p_slot_id and d.train_id = p_train_id;

  if not found then
    raise exception 'Slot not found on this train.' using errcode = 'P0001';
  end if;

  -- Shift later slots earlier and renumber
  update public.slots
  set
    start_time   = (start_time::interval - v_dur * interval '1 minute')::time,
    slot_order   = slot_order - 1
  where train_day_id = v_day_id
    and slot_order > v_order;

  delete from public.slots where id = p_slot_id;
end;
$$;

grant execute on function public.delete_member_train_slot(uuid, text, uuid)
  to anon, authenticated;
