-- ── Train Proposals ───────────────────────────────────────────────────────
-- Sellers can propose a new Niknax Raid Train from the public /propose page.
-- Inserting a row here triggers a DB webhook → send-notification edge function
-- which emails the admin immediately.

create table public.train_proposals (
  id               uuid primary key default gen_random_uuid(),
  name             text not null,
  tagline          text,
  proposed_date    text,           -- freeform, e.g. "mid-July" or "2026-08-15"
  contact_username text not null,  -- District / Niknax handle
  message          text,
  created_at       timestamptz default now(),
  reviewed         boolean not null default false
);

-- RLS: anyone can submit, only admins can read/update
alter table public.train_proposals enable row level security;

create policy "Anyone can submit a train proposal"
  on public.train_proposals
  for insert
  to anon, authenticated
  with check (true);

create policy "Admins can read proposals"
  on public.train_proposals
  for select
  using (public.is_admin());

create policy "Admins can mark proposals reviewed"
  on public.train_proposals
  for update
  using (public.is_admin())
  with check (public.is_admin());

-- ── Slots replica identity ─────────────────────────────────────────────────
-- The DB webhook for "train full" detection needs old_record on UPDATE events.
-- REPLICA IDENTITY FULL ensures Postgres includes the full old row in WAL,
-- which Supabase surfaces in the webhook payload as "old_record".

alter table public.slots replica identity full;
