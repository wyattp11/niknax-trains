-- ============================================================
-- TRAIN CHAT — lightweight per-train message board
-- ============================================================
--
-- Posting is gated to the authorized sellers list (members with
-- can_go_live = true), same trust model as slot signup: username-based,
-- not cryptographically verified.
--
-- Moderation:
--   • Admins (and the conductor, on member trains) can delete any message.
--   • trains.chat_locked freezes posting without deleting history.
--   • members.chat_blocked stops a specific seller from posting anywhere.
--
-- Reads are open to anon on any visible train. All writes go through
-- security-definer RPCs so anon never touches the table directly.
-- ============================================================


-- ── Columns ────────────────────────────────────────────────────────────────

alter table public.trains
  add column if not exists chat_locked boolean not null default false;

alter table public.members
  add column if not exists chat_blocked boolean not null default false;


-- ── Messages table ─────────────────────────────────────────────────────────

create table if not exists public.train_chat_messages (
  id           uuid primary key default gen_random_uuid(),
  train_id     uuid not null references public.trains(id) on delete cascade,
  username     text not null,
  username_key text not null,
  body         text not null,
  role         text,               -- snapshot of the member badge at post time
  created_at   timestamptz not null default now(),
  constraint train_chat_body_len check (char_length(body) between 1 and 500)
);

create index if not exists train_chat_train_id_idx
  on public.train_chat_messages(train_id, created_at desc);

alter table public.train_chat_messages enable row level security;

-- Anyone can read messages on a train they're allowed to see. Moderation is a
-- hard delete rather than a soft one: a soft-deleted row would fail this policy,
-- so the realtime UPDATE event would never reach other viewers and the message
-- would linger on their screens until reload. DELETE events carry only the
-- primary key and always propagate.
drop policy if exists "public read train chat" on public.train_chat_messages;
create policy "public read train chat"
on public.train_chat_messages
for select
using (
  exists (
    select 1 from public.trains t
    where t.id = train_id
      and (t.published = true or t.is_upcoming = true or t.is_member_train = true)
  )
);

drop policy if exists "admin manage train chat" on public.train_chat_messages;
create policy "admin manage train chat"
on public.train_chat_messages
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

grant select on public.train_chat_messages to anon, authenticated;

-- Writes go exclusively through the RPCs below.
revoke insert, update, delete on public.train_chat_messages from anon;


-- ── Post a message ─────────────────────────────────────────────────────────

create or replace function public.post_chat_message(
  p_train_id uuid,
  p_username text,
  p_body     text
)
returns public.train_chat_messages
language plpgsql
security definer
set search_path = public
as $$
declare
  posted public.train_chat_messages;
  clean_username text;
  clean_body text;
  member_role text;
  member_blocked boolean := false;
  member_found boolean := false;
  train_visible boolean := false;
  train_locked boolean := false;
begin
  clean_username := nullif(trim(regexp_replace(coalesce(p_username, ''), '^@+', '')), '');
  clean_body     := nullif(trim(coalesce(p_body, '')), '');

  if clean_username is null then
    raise exception 'Please enter your username.' using errcode = '22023';
  end if;

  if clean_body is null then
    raise exception 'Message cannot be empty.' using errcode = '22023';
  end if;

  if char_length(clean_body) > 500 then
    raise exception 'Message is too long (500 characters max).' using errcode = '22023';
  end if;

  -- Train must exist and be visible
  select (t.published or t.is_upcoming or t.is_member_train), t.chat_locked
  into train_visible, train_locked
  from public.trains t
  where t.id = p_train_id;

  if not coalesce(train_visible, false) then
    raise exception 'Chat is not available for this event.' using errcode = 'P0001';
  end if;

  if coalesce(train_locked, false) then
    raise exception 'Chat is locked for this event.'
      using errcode = 'P0001', detail = 'chat_locked';
  end if;

  -- Poster must be on the authorized sellers list
  select true, m.role, coalesce(m.chat_blocked, false)
  into member_found, member_role, member_blocked
  from public.members m
  where lower(m.username) = lower(clean_username)
    and m.can_go_live = true;

  if not coalesce(member_found, false) then
    raise exception 'Only authorized Niknax sellers can post in chat.'
      using errcode = 'P0001', detail = 'not_a_member';
  end if;

  if member_blocked then
    raise exception 'Your chat access has been paused. Contact the Niknax team.'
      using errcode = 'P0001', detail = 'chat_blocked';
  end if;

  insert into public.train_chat_messages (train_id, username, username_key, body, role)
  values (
    p_train_id,
    (select m.username from public.members m
      where lower(m.username) = lower(clean_username) and m.can_go_live = true
      limit 1),
    lower(clean_username),
    clean_body,
    member_role
  )
  returning * into posted;

  return posted;
end;
$$;

grant execute on function public.post_chat_message(uuid, text, text) to anon, authenticated;


-- ── Delete a message (admin or the member-train conductor) ─────────────────

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
  conductor text;
  is_member_train boolean := false;
  actor_clean text;
  allowed boolean := false;
begin
  select m.train_id, t.conductor_username, coalesce(t.is_member_train, false)
  into msg_train_id, conductor, is_member_train
  from public.train_chat_messages m
  join public.trains t on t.id = m.train_id
  where m.id = p_message_id;

  if msg_train_id is null then
    return false;
  end if;

  -- Admins can always delete
  if public.is_admin() then
    allowed := true;
  else
    -- The conductor of a member train can moderate their own train
    actor_clean := nullif(trim(regexp_replace(coalesce(p_actor, ''), '^@+', '')), '');
    if is_member_train
       and conductor is not null
       and actor_clean is not null
       and lower(actor_clean) = lower(conductor) then
      allowed := true;
    end if;
  end if;

  if not allowed then
    raise exception 'You do not have permission to remove this message.' using errcode = 'P0001';
  end if;

  delete from public.train_chat_messages where id = p_message_id;

  return true;
end;
$$;

grant execute on function public.delete_chat_message(uuid, text) to anon, authenticated;


-- ── Conductor lock toggle for member trains ───────────────────────────────

create or replace function public.set_member_train_chat_locked(
  p_train_id  uuid,
  p_conductor text,
  p_locked    boolean
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  conductor text;
  is_mt boolean := false;
  actor_clean text;
begin
  select t.conductor_username, coalesce(t.is_member_train, false)
  into conductor, is_mt
  from public.trains t
  where t.id = p_train_id;

  actor_clean := nullif(trim(regexp_replace(coalesce(p_conductor, ''), '^@+', '')), '');

  if not is_mt
     or conductor is null
     or actor_clean is null
     or lower(actor_clean) <> lower(conductor) then
    raise exception 'You do not have permission to change this train.' using errcode = 'P0001';
  end if;

  update public.trains set chat_locked = coalesce(p_locked, false) where id = p_train_id;
  return true;
end;
$$;

grant execute on function public.set_member_train_chat_locked(uuid, text, boolean) to anon, authenticated;


-- ── Realtime ───────────────────────────────────────────────────────────────
-- Adds the chat table to the realtime publication so clients get live inserts.

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'train_chat_messages'
  ) then
    alter publication supabase_realtime add table public.train_chat_messages;
  end if;
end
$$;
