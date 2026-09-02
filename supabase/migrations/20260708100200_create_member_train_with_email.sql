-- ============================================================
-- create_member_train — capture the conductor's email
-- ============================================================
--
-- The creator becomes the primary conductor, registered by email so they can
-- receive access codes. Adding p_email changes the arity, so the old wrapper
-- and _impl are dropped and rebuilt.
--
-- Creation is the one place that can't use a session token — there's no
-- session yet — so it still authenticates by authorized-seller username,
-- exactly as before. The email only determines where codes are sent.
-- ============================================================

drop function if exists public.create_member_train(text, text, text, text, text, text, jsonb);
drop function if exists public.create_member_train_impl(text, text, text, text, text, text, jsonb);


create or replace function public.create_member_train(
  p_username      text,
  p_email         text,
  p_name          text,
  p_tagline       text  default null,
  p_description   text  default null,
  p_district_link text  default null,
  p_rules_md      text  default null,
  p_days          jsonb default '[]'::jsonb
)
returns public.trains
language plpgsql
security definer
set search_path = public
as $$
declare
  clean_username text;
  clean_email    text;
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
  v_code         text;
  v_salt         text;
begin
  clean_username := nullif(trim(regexp_replace(coalesce(p_username, ''), '^@+', '')), '');
  clean_email    := lower(nullif(trim(coalesce(p_email, '')), ''));

  if clean_username is null then
    raise exception 'Username is required.' using errcode = '22023';
  end if;

  if clean_email is null or clean_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'A valid email address is required so you can receive your access code.'
      using errcode = '22023';
  end if;

  if length(trim(coalesce(p_name, ''))) = 0 then
    raise exception 'Train name is required.' using errcode = '22023';
  end if;

  if not exists (
    select 1 from public.members
    where lower(username) = lower(clean_username) and can_go_live = true
  ) then
    raise exception 'Only authorized Niknax sellers can create a train.' using errcode = 'P0001';
  end if;

  perform public.set_audit_actor(clean_username);

  insert into public.trains (
    name, tagline, description, district_link, rules_md,
    cover_url, published, is_upcoming, conductor_username, is_member_train
  ) values (
    trim(p_name),
    nullif(trim(coalesce(p_tagline, '')), ''),
    nullif(trim(coalesce(p_description, '')), ''),
    nullif(trim(coalesce(p_district_link, '')), ''),
    nullif(trim(coalesce(p_rules_md, '')), ''),
    null, false, false, clean_username, true
  )
  returning * into new_train;

  -- Creator becomes the primary conductor
  insert into public.train_conductors (train_id, email, email_key, username, is_primary)
  values (new_train.id, trim(p_email), clean_email, clean_username, true);

  days_count := coalesce(jsonb_array_length(p_days), 0);

  for day_idx in 0..(days_count - 1) loop
    day_obj      := p_days->day_idx;
    slot_start   := (day_obj->>'start_time')::time;
    slot_dur     := coalesce((day_obj->>'slot_duration')::integer, 30);
    slot_cnt     := coalesce((day_obj->>'slot_count')::integer, 24);
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
        slot_start + (kickoff_dur * interval '1 minute')
                   + ((i - 1) * slot_dur * interval '1 minute'),
        slot_dur, null, null, null, false, i - 1 + order_base
      );
    end loop;
  end loop;

  -- Send the first access code straight away so they can start managing
  -- without having to request one.
  v_code := lpad((floor(random() * 1000000))::integer::text, 6, '0');
  v_salt := encode(gen_random_bytes(16), 'hex');

  insert into public.conductor_access_codes (train_id, email_key, code_hash, salt, expires_at)
  values (new_train.id, clean_email, public.hash_secret(v_code, v_salt), v_salt,
          now() + interval '30 minutes');

  insert into public.email_outbox (kind, recipient, payload)
  values (
    'conductor_code',
    trim(p_email),
    jsonb_build_object(
      'code',       v_code,
      'train_id',   new_train.id,
      'train_name', new_train.name,
      'expires_in', '30 minutes',
      'is_welcome', true
    )
  );

  return new_train;
end;
$$;

grant execute on function
  public.create_member_train(text, text, text, text, text, text, text, jsonb)
  to anon, authenticated;
