-- Niknax Train Station schema + security hardening.
-- Run in Supabase SQL Editor after creating at least one Supabase Auth user.
-- Then add that user's auth.users.id to public.admin_users.

create extension if not exists pgcrypto;

-- ============================================================
-- TABLES
-- ============================================================

create table if not exists public.trains (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  tagline       text,
  description   text,
  cover_url     text,
  district_link text,
  published     boolean not null default false,
  is_upcoming   boolean not null default false,
  created_at    timestamptz not null default now()
);

alter table public.trains add column if not exists tagline text;
alter table public.trains add column if not exists description text;
alter table public.trains add column if not exists cover_url text;
alter table public.trains add column if not exists district_link text;
alter table public.trains add column if not exists published boolean not null default false;
alter table public.trains add column if not exists is_upcoming boolean not null default false;
alter table public.trains add column if not exists created_at timestamptz not null default now();

create table if not exists public.train_days (
  id        uuid primary key default gen_random_uuid(),
  train_id  uuid not null references public.trains(id) on delete cascade,
  day_date  date not null,
  day_label text,
  day_order integer not null default 0
);

create table if not exists public.slots (
  id              uuid primary key default gen_random_uuid(),
  train_day_id    uuid not null references public.train_days(id) on delete cascade,
  start_time      time not null,
  duration_min    integer not null default 30,
  username        text,
  seller_link     text,
  label           text,
  is_pre_assigned boolean not null default false,
  slot_order      integer not null default 0,
  created_at      timestamptz not null default now()
);

alter table public.slots add column if not exists seller_link text;
alter table public.slots add column if not exists label text;
alter table public.slots add column if not exists is_pre_assigned boolean not null default false;
alter table public.slots add column if not exists slot_order integer not null default 0;
alter table public.slots add column if not exists created_at timestamptz not null default now();

create table if not exists public.members (
  id          uuid primary key default gen_random_uuid(),
  username    text not null unique,
  full_name   text,
  email       text,
  phone       text,
  joined_at   timestamptz,
  role        text,
  can_go_live boolean not null default false,
  sales       numeric not null default 0,
  spend       numeric not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.admin_users (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists train_days_train_id_idx on public.train_days(train_id);
create index if not exists slots_train_day_id_idx on public.slots(train_day_id);
create index if not exists members_username_idx on public.members(username);
create index if not exists members_can_go_live_idx on public.members(can_go_live);

-- ============================================================
-- ADMIN CHECK
-- ============================================================

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.admin_users
    where user_id = auth.uid()
  );
$$;

grant execute on function public.is_admin() to anon, authenticated;

-- ============================================================
-- PUBLIC RPCS
-- ============================================================

create or replace function public.claim_slot(slot_id uuid, claimant_username text)
returns public.slots
language plpgsql
security definer
set search_path = public
as $$
declare
  claimed public.slots;
  clean_username text;
begin
  clean_username := nullif(trim(regexp_replace(coalesce(claimant_username, ''), '^@+', '')), '');

  if clean_username is null then
    raise exception 'Please enter your username.' using errcode = '22023';
  end if;

  if length(clean_username) > 60 then
    raise exception 'Username is too long.' using errcode = '22023';
  end if;

  update public.slots s
  set username = clean_username
  where s.id = slot_id
    and s.username is null
    and s.is_pre_assigned = false
    and exists (
      select 1
      from public.train_days d
      join public.trains t on t.id = d.train_id
      where d.id = s.train_day_id
        and t.published = true
    )
  returning s.* into claimed;

  if not found then
    raise exception 'Sorry - this slot is no longer available.' using errcode = 'P0001';
  end if;

  return claimed;
end;
$$;

create or replace function public.set_slot_seller_link(slot_id uuid, link text)
returns public.slots
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_slot public.slots;
  clean_link text;
begin
  clean_link := nullif(trim(coalesce(link, '')), '');

  if clean_link is not null and clean_link !~* '^https://([a-z0-9-]+\.)*districtapp\.tv(/|$)' then
    raise exception 'Please enter a valid https:// District link.' using errcode = '22023';
  end if;

  update public.slots s
  set seller_link = clean_link
  where s.id = slot_id
    and s.username is not null
    and exists (
      select 1
      from public.train_days d
      join public.trains t on t.id = d.train_id
      where d.id = s.train_day_id
        and t.published = true
    )
  returning s.* into updated_slot;

  if not found then
    raise exception 'Show links can only be added to claimed slots on published trains.' using errcode = 'P0001';
  end if;

  return updated_slot;
end;
$$;

grant execute on function public.claim_slot(uuid, text) to anon, authenticated;
grant execute on function public.set_slot_seller_link(uuid, text) to anon, authenticated;

-- Username autocomplete exposes only usernames that can go live.
create or replace view public.members_signup_search
with (security_invoker = false)
as
select username
from public.members
where can_go_live = true;

grant select on public.members_signup_search to anon, authenticated;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table public.trains enable row level security;
alter table public.train_days enable row level security;
alter table public.slots enable row level security;
alter table public.members enable row level security;
alter table public.admin_users enable row level security;

drop policy if exists "public read visible trains" on public.trains;
drop policy if exists "admin manage trains" on public.trains;
drop policy if exists "public read visible train days" on public.train_days;
drop policy if exists "admin manage train days" on public.train_days;
drop policy if exists "public read visible slots" on public.slots;
drop policy if exists "admin manage slots" on public.slots;
drop policy if exists "admin manage members" on public.members;
drop policy if exists "admin read admin users" on public.admin_users;
drop policy if exists "admin manage admin users" on public.admin_users;

create policy "public read visible trains"
on public.trains
for select
using (published = true or is_upcoming = true or public.is_admin());

create policy "admin manage trains"
on public.trains
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "public read visible train days"
on public.train_days
for select
using (
  exists (
    select 1
    from public.trains t
    where t.id = train_days.train_id
      and (t.published = true or t.is_upcoming = true or public.is_admin())
  )
);

create policy "admin manage train days"
on public.train_days
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "public read visible slots"
on public.slots
for select
using (
  exists (
    select 1
    from public.train_days d
    join public.trains t on t.id = d.train_id
    where d.id = slots.train_day_id
      and (t.published = true or public.is_admin())
  )
);

create policy "admin manage slots"
on public.slots
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "admin manage members"
on public.members
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "admin read admin users"
on public.admin_users
for select
to authenticated
using (public.is_admin());

create policy "admin manage admin users"
on public.admin_users
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- Public callers should read visible event data and use RPCs for writes.
revoke all on public.trains from anon, authenticated;
revoke all on public.train_days from anon, authenticated;
revoke all on public.slots from anon, authenticated;
revoke all on public.members from anon, authenticated;
revoke all on public.admin_users from anon, authenticated;

grant select on public.trains, public.train_days, public.slots to anon, authenticated;
grant insert, update, delete on public.trains, public.train_days, public.slots to authenticated;
grant select, insert, update, delete on public.members to authenticated;
grant select, insert, update, delete on public.admin_users to authenticated;

-- ============================================================
-- STORAGE
-- ============================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'train-graphics',
  'train-graphics',
  true,
  10485760,
  array['image/png', 'image/jpeg', 'image/gif', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "public read train graphics" on storage.objects;
drop policy if exists "admin upload train graphics" on storage.objects;
drop policy if exists "admin update train graphics" on storage.objects;
drop policy if exists "admin delete train graphics" on storage.objects;

create policy "public read train graphics"
on storage.objects
for select
using (bucket_id = 'train-graphics');

create policy "admin upload train graphics"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'train-graphics' and public.is_admin());

create policy "admin update train graphics"
on storage.objects
for update
to authenticated
using (bucket_id = 'train-graphics' and public.is_admin())
with check (bucket_id = 'train-graphics' and public.is_admin());

create policy "admin delete train graphics"
on storage.objects
for delete
to authenticated
using (bucket_id = 'train-graphics' and public.is_admin());

-- ============================================================
-- ADMIN BOOTSTRAP
-- ============================================================
-- 1. Create an auth user in Supabase Auth.
-- 2. Find the user's id in auth.users.
-- 3. Run:
--      insert into public.admin_users (user_id)
--      values ('00000000-0000-0000-0000-000000000000');
