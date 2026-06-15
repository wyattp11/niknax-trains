-- Run this in your Supabase SQL editor to set up the schema.
-- Go to: https://supabase.com → your project → SQL Editor → New query

-- ============================================================
-- TABLES
-- ============================================================

create table trains (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  tagline     text,
  description text,
  cover_url   text,
  district_link text,
  published   boolean not null default false,
  created_at  timestamptz not null default now()
);

create table train_days (
  id          uuid primary key default gen_random_uuid(),
  train_id    uuid not null references trains(id) on delete cascade,
  day_date    date not null,
  day_label   text,
  day_order   integer not null default 0
);

create table slots (
  id              uuid primary key default gen_random_uuid(),
  train_day_id    uuid not null references train_days(id) on delete cascade,
  start_time      time not null,          -- stored as Eastern Time
  duration_min    integer not null default 30,
  username        text,                   -- null = open slot
  seller_link     text,                   -- optional District link for seller
  label           text,                   -- e.g. "Kickoff" or "Niknax Boost"
  is_pre_assigned boolean not null default false,
  slot_order      integer not null default 0,
  created_at      timestamptz not null default now()
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
-- For this MVP we leave RLS disabled so the anon key can do everything.
-- The admin area is protected by your VITE_ADMIN_PIN in the frontend.
-- To harden security later, enable RLS and add the policies below.

-- (RLS is disabled by default on new tables — nothing else needed for MVP)

-- ── OPTIONAL: enable these later for proper security ──────────────────────
-- alter table trains     enable row level security;
-- alter table train_days enable row level security;
-- alter table slots      enable row level security;
--
-- create policy "public read trains"     on trains     for select using (published = true);
-- create policy "public read train_days" on train_days for select using (
--   exists (select 1 from trains where trains.id = train_days.train_id and trains.published = true)
-- );
-- create policy "public read slots"      on slots      for select using (
--   exists (select 1 from train_days join trains on trains.id = train_days.train_id
--           where train_days.id = slots.train_day_id and trains.published = true)
-- );
-- create policy "public claim slot"      on slots      for update
--   using (is_pre_assigned = false and username is null)
--   with check (username is not null);
