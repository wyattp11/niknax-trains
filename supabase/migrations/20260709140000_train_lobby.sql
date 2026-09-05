-- ============================================================
-- TRAIN LOBBY — a waiting list for full trains
-- ============================================================
--
-- Sellers who arrive after every slot is taken can register interest instead
-- of leaving empty-handed. When someone drops out, an admin or conductor
-- swaps a lobby member straight into the vacancy.
--
-- The lobby opens once every CLAIMABLE slot is filled. Reserved and kickoff
-- rows sitting empty don't hold it shut, since a regular seller can't take
-- those anyway — a train whose only free slots are moderator-reserved is, from
-- a seller's point of view, full.
--
-- Gates on joining mirror slot signup: authorized sellers only, one entry per
-- train, and not while already holding a slot on that train.
-- ============================================================


create table if not exists public.train_lobby (
  id           uuid primary key default gen_random_uuid(),
  train_id     uuid not null references public.trains(id) on delete cascade,
  username     text not null,
  username_key text not null,
  note         text,                        -- optional "any day works", etc.
  created_at   timestamptz not null default now(),
  unique (train_id, username_key)
);

create index if not exists train_lobby_train_idx
  on public.train_lobby(train_id, created_at);

alter table public.train_lobby enable row level security;

-- Lobby membership is as public as slot sign-ups already are.
drop policy if exists "public read lobby" on public.train_lobby;
create policy "public read lobby"
on public.train_lobby
for select
using (
  exists (
    select 1 from public.trains t
    where t.id = train_id
      and (t.published = true or t.is_upcoming = true or t.is_member_train = true)
  )
);

drop policy if exists "admin manage lobby" on public.train_lobby;
create policy "admin manage lobby"
on public.train_lobby
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

grant select on public.train_lobby to anon, authenticated;
-- Writes go through the RPCs below so the gates can't be bypassed.
revoke insert, update, delete on public.train_lobby from anon;


-- ── Is the lobby open? ────────────────────────────────────────────────────
-- Open when the train has claimable slots and none of them are free.

create or replace function public.train_lobby_open(p_train_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, extensions
as $$
  with claimable as (
    select s.username
    from public.slots s
    join public.train_days d on d.id = s.train_day_id
    where d.train_id = p_train_id
      and coalesce(s.is_pre_assigned, false) = false
      and lower(coalesce(s.label, '')) <> 'kickoff'
      and s.slot_order <> 0
  )
  select exists (select 1 from claimable)
     and not exists (select 1 from claimable where username is null);
$$;

grant execute on function public.train_lobby_open(uuid) to anon, authenticated;


-- ── Join ──────────────────────────────────────────────────────────────────

create or replace function public.join_train_lobby(
  p_train_id uuid,
  p_username text,
  p_note     text default null
)
returns public.train_lobby
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  clean_username text;
  joined         public.train_lobby;
  v_visible      boolean := false;
  v_strikes      integer := 0;
begin
  clean_username := nullif(trim(regexp_replace(coalesce(p_username, ''), '^@+', '')), '');

  if clean_username is null then
    raise exception 'Please enter your username.' using errcode = '22023';
  end if;

  select (published or is_upcoming or is_member_train)
  into v_visible
  from public.trains where id = p_train_id;

  if not coalesce(v_visible, false) then
    raise exception 'This event isn''t open yet.' using errcode = 'P0001';
  end if;

  if not exists (
    select 1 from public.members
    where lower(username) = lower(clean_username) and can_go_live = true
  ) then
    raise exception 'Sorry — that username isn''t on the authorized sellers list.'
      using errcode = 'P0001';
  end if;

  if not public.train_lobby_open(p_train_id) then
    raise exception 'There are still open slots — grab one instead of waiting.'
      using errcode = 'P0001', detail = 'slots_available';
  end if;

  -- Already on the schedule: nothing to wait for.
  if exists (
    select 1
    from public.slots s
    join public.train_days d on d.id = s.train_day_id
    where d.train_id = p_train_id
      and lower(s.username) = lower(clean_username)
  ) then
    raise exception 'You already have a slot on this train.'
      using errcode = 'P0001', detail = 'already_scheduled';
  end if;

  -- A seller who can't claim a slot shouldn't be queued for one. Checked
  -- without assigning a penalty train — sitting in a lobby isn't an attempt
  -- to claim, so it mustn't count as serving the strike.
  select coalesce(sum(points), 0) into v_strikes
  from public.member_strikes
  where username_key = lower(clean_username)
    and cleared_at is null
    and penalty_train_id is null;

  if v_strikes > 0 and not exists (
    select 1 from public.trains where id = p_train_id and is_member_train = true
  ) then
    raise exception 'You''re sitting out this event. You can still join member-created trains.'
      using errcode = 'P0001', detail = 'strike_block';
  end if;

  insert into public.train_lobby (train_id, username, username_key, note)
  values (
    p_train_id,
    (select username from public.members
      where lower(username) = lower(clean_username) and can_go_live = true limit 1),
    lower(clean_username),
    nullif(trim(coalesce(p_note, '')), '')
  )
  on conflict (train_id, username_key) do update set note = excluded.note
  returning * into joined;

  return joined;
end;
$$;

grant execute on function public.join_train_lobby(uuid, text, text) to anon, authenticated;


-- ── Leave ─────────────────────────────────────────────────────────────────

create or replace function public.leave_train_lobby(
  p_train_id uuid,
  p_username text
)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  clean_username text;
begin
  clean_username := nullif(trim(regexp_replace(coalesce(p_username, ''), '^@+', '')), '');
  if clean_username is null then
    return false;
  end if;

  delete from public.train_lobby
  where train_id = p_train_id and username_key = lower(clean_username);

  return true;
end;
$$;

grant execute on function public.leave_train_lobby(uuid, text) to anon, authenticated;


-- ── Substitute a lobby member into a slot ─────────────────────────────────
-- Usable by an admin, or by the conductor of a member train (via token).

create or replace function public.substitute_from_lobby(
  p_slot_id  uuid,
  p_username text,
  p_token    text default null
)
returns public.slots
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_train_id     uuid;
  clean_username text;
  v_lobby        public.train_lobby;
  updated        public.slots;
  allowed        boolean := false;
begin
  clean_username := nullif(trim(regexp_replace(coalesce(p_username, ''), '^@+', '')), '');

  select d.train_id into v_train_id
  from public.slots s
  join public.train_days d on d.id = s.train_day_id
  where s.id = p_slot_id;

  if v_train_id is null then
    raise exception 'Slot not found.' using errcode = 'P0001';
  end if;

  if public.is_admin() then
    allowed := true;
  elsif public.conductor_email_for_token(v_train_id, p_token) is not null then
    allowed := true;
  end if;

  if not allowed then
    raise exception 'You do not have permission to fill this slot.' using errcode = 'P0001';
  end if;

  select * into v_lobby
  from public.train_lobby
  where train_id = v_train_id and username_key = lower(clean_username);

  if not found then
    raise exception 'That person is not in this train''s lobby.' using errcode = 'P0001';
  end if;

  -- Guard against double-booking if they claimed a slot in the meantime.
  if exists (
    select 1 from public.slots s
    join public.train_days d on d.id = s.train_day_id
    where d.train_id = v_train_id
      and lower(s.username) = lower(clean_username)
  ) then
    delete from public.train_lobby where id = v_lobby.id;
    raise exception 'They already have a slot on this train — removed them from the lobby.'
      using errcode = 'P0001';
  end if;

  update public.slots
  set username    = v_lobby.username,
      seller_link = null          -- the previous seller's link must not carry over
  where id = p_slot_id
  returning * into updated;

  delete from public.train_lobby where id = v_lobby.id;

  return updated;
end;
$$;

grant execute on function public.substitute_from_lobby(uuid, text, text) to anon, authenticated;


-- ── Lobby with open state, for the UI ─────────────────────────────────────

create or replace function public.train_lobby_state(p_train_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public, extensions
as $$
  select jsonb_build_object(
    'open', public.train_lobby_open(p_train_id),
    'members', coalesce((
      select jsonb_agg(jsonb_build_object(
               'username',   l.username,
               'note',       l.note,
               'created_at', l.created_at
             ) order by l.created_at)
      from public.train_lobby l
      where l.train_id = p_train_id
    ), '[]'::jsonb)
  );
$$;

grant execute on function public.train_lobby_state(uuid) to anon, authenticated;
