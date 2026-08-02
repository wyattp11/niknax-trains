-- ============================================================
-- MEMBER STRIKES — accountability system
-- ============================================================
--
-- Sellers who no-show or break rules get a "strike". An active strike
-- blocks them from claiming a slot on the NEXT Niknax-sponsored train
-- they attempt to join. Member-created trains are always exempt.
--
-- Lifecycle:
--   1. Admin logs a strike from a slot row on a past train.
--      penalty_train_id starts NULL ("not yet served").
--   2. The seller tries to claim a slot on a Niknax train -> blocked,
--      and penalty_train_id is locked to that train.
--   3. Once that train's last day has passed, the strike is considered
--      served and no longer counts toward their standing.
--
-- Admins can clear a strike manually at any time (cleared_at).
-- NN owners/admins/moderators are exempt from the gate — a no-show by
-- staff is a conversation, not an automated ban, and blocking them
-- would break the reserved/kickoff slots they're needed for.
-- ============================================================


-- ── App settings (key/value) ───────────────────────────────────────────────

create table if not exists public.app_settings (
  key        text primary key,
  value      text,
  updated_at timestamptz not null default now()
);

alter table public.app_settings enable row level security;

drop policy if exists "admin manage app settings" on public.app_settings;
create policy "admin manage app settings"
on public.app_settings
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

insert into public.app_settings (key, value)
values
  ('strike_block_message',
   'You''re sitting out this event because of {reason} at {train}. You can still sign up for member-created trains. Reach out to the Niknax team if you think this is a mistake.'),
  ('strike_block_threshold', '1')
on conflict (key) do nothing;


-- ── Strikes table ──────────────────────────────────────────────────────────

create table if not exists public.member_strikes (
  id               uuid primary key default gen_random_uuid(),
  username         text not null,
  username_key     text not null,
  train_id         uuid references public.trains(id) on delete set null,
  slot_id          uuid references public.slots(id) on delete set null,
  reason           text not null default 'no_show',
  points           integer not null default 1,
  notes            text,
  penalty_train_id uuid references public.trains(id) on delete set null,
  cleared_at       timestamptz,
  cleared_note     text,
  created_at       timestamptz not null default now(),
  created_by       uuid references auth.users(id) on delete set null,
  constraint member_strikes_reason_check check (
    reason in ('no_show', 'late', 'left_early', 'rule_violation', 'other')
  ),
  constraint member_strikes_points_check check (points between 1 and 10)
);

create index if not exists member_strikes_username_key_idx on public.member_strikes(username_key);
create index if not exists member_strikes_train_id_idx     on public.member_strikes(train_id);
create index if not exists member_strikes_slot_id_idx      on public.member_strikes(slot_id);
create index if not exists member_strikes_active_idx       on public.member_strikes(username_key) where cleared_at is null;

alter table public.member_strikes enable row level security;

drop policy if exists "admin manage member strikes" on public.member_strikes;
create policy "admin manage member strikes"
on public.member_strikes
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());


-- ── Helper: has a train finished? ──────────────────────────────────────────

create or replace function public.train_has_finished(p_train_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(max(d.day_date) < current_date, false)
  from public.train_days d
  where d.train_id = p_train_id;
$$;

grant execute on function public.train_has_finished(uuid) to anon, authenticated;


-- ── Standing view (admin only) ─────────────────────────────────────────────
-- A strike counts toward standing while it is uncleared AND either not yet
-- assigned to a penalty train, or assigned to one that hasn't finished.

create or replace view public.member_standing
with (security_invoker = true)
as
select
  s.username_key,
  min(s.username)                       as username,
  count(*)::int                         as active_strikes,
  coalesce(sum(s.points), 0)::int       as active_points,
  max(s.created_at)                     as last_strike_at
from public.member_strikes s
where s.cleared_at is null
  and (
    s.penalty_train_id is null
    or not public.train_has_finished(s.penalty_train_id)
  )
group by s.username_key;

grant select on public.member_standing to authenticated;


-- ── Reason labels for messaging ────────────────────────────────────────────

create or replace function public.strike_reason_label(p_reason text)
returns text
language sql
immutable
as $$
  select case p_reason
    when 'no_show'        then 'a no-show'
    when 'late'           then 'showing up late'
    when 'left_early'     then 'leaving your slot early'
    when 'rule_violation' then 'a rule violation'
    else 'a reported issue'
  end;
$$;

grant execute on function public.strike_reason_label(text) to anon, authenticated;


-- ============================================================
-- claim_slot — now enforces the strike gate
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
  target_train_id uuid;
  target_published boolean := false;
  target_is_upcoming boolean := false;
  target_is_kickoff boolean := false;
  target_is_pre_assigned boolean := false;
  target_is_member_train boolean := false;
  is_unlimited_claimant boolean := false;
  strike_points integer := 0;
  strike_threshold integer := 1;
  strike_reason text;
  strike_train_name text;
  block_message text;
begin
  clean_username := nullif(trim(regexp_replace(coalesce(claimant_username, ''), '^@+', '')), '');

  if clean_username is null then
    raise exception 'Please enter your username.' using errcode = '22023';
  end if;

  if length(clean_username) > 60 then
    raise exception 'Username is too long.' using errcode = '22023';
  end if;

  select exists (
    select 1
    from public.members m
    where lower(m.username) = lower(clean_username)
      and lower(m.role) in ('nn owner', 'nn admin', 'nn moderator')
  )
  into is_unlimited_claimant;

  select d.train_id, t.published, t.is_upcoming,
         (lower(coalesce(s.label, '')) = 'kickoff' or s.slot_order = 0),
         s.is_pre_assigned,
         coalesce(t.is_member_train, false)
  into target_train_id, target_published, target_is_upcoming, target_is_kickoff,
       target_is_pre_assigned, target_is_member_train
  from public.slots s
  join public.train_days d on d.id = s.train_day_id
  join public.trains t on t.id = d.train_id
  where s.id = slot_id;

  if target_train_id is null then
    raise exception 'Sorry - this slot is no longer available.' using errcode = 'P0001';
  end if;

  if target_is_kickoff and not is_unlimited_claimant then
    raise exception 'Only NN moderators and admins can claim the Kickoff slot.' using errcode = 'P0001';
  end if;

  if target_is_pre_assigned and not target_is_kickoff and not is_unlimited_claimant then
    raise exception 'This is a reserved slot for NN moderators and admins.' using errcode = 'P0001';
  end if;

  if not target_published and not (target_is_upcoming and is_unlimited_claimant) then
    raise exception 'Only NN moderators and admins can sign up before this train is published.' using errcode = 'P0001';
  end if;

  -- ── Strike gate ────────────────────────────────────────────────────────
  -- Only applies to Niknax-sponsored trains, and never to NN staff.
  if not target_is_member_train and not is_unlimited_claimant then

    select coalesce(sum(st.points), 0)
    into strike_points
    from public.member_strikes st
    where st.username_key = lower(clean_username)
      and st.cleared_at is null
      and (st.penalty_train_id is null or st.penalty_train_id = target_train_id);

    select coalesce(nullif(value, '')::integer, 1)
    into strike_threshold
    from public.app_settings
    where key = 'strike_block_threshold';

    strike_threshold := coalesce(strike_threshold, 1);

    if strike_points >= strike_threshold then
      -- Lock any unassigned strikes to this train, so they're served by
      -- sitting this one out and clear automatically once it's over.
      update public.member_strikes
      set penalty_train_id = target_train_id
      where username_key = lower(clean_username)
        and cleared_at is null
        and penalty_train_id is null;

      -- Pull the most recent reason + origin train for the message
      select public.strike_reason_label(st.reason), coalesce(t.name, 'a previous event')
      into strike_reason, strike_train_name
      from public.member_strikes st
      left join public.trains t on t.id = st.train_id
      where st.username_key = lower(clean_username)
        and st.cleared_at is null
        and st.penalty_train_id = target_train_id
      order by st.created_at desc
      limit 1;

      select value into block_message
      from public.app_settings
      where key = 'strike_block_message';

      block_message := coalesce(
        nullif(block_message, ''),
        'You''re sitting out this event because of {reason} at {train}. You can still sign up for member-created trains.'
      );

      block_message := replace(block_message, '{reason}', coalesce(strike_reason, 'a reported issue'));
      block_message := replace(block_message, '{train}',  coalesce(strike_train_name, 'a previous event'));
      block_message := replace(block_message, '{username}', clean_username);

      -- detail = 'strike_block' lets the client render this distinctly
      -- from ordinary "slot taken" errors.
      raise exception '%', block_message
        using errcode = 'P0001', detail = 'strike_block';
    end if;
  end if;
  -- ── End strike gate ────────────────────────────────────────────────────

  perform pg_advisory_xact_lock(hashtext(target_train_id::text), hashtext(lower(clean_username)));

  if not is_unlimited_claimant and exists (
    select 1
    from public.slots existing
    join public.train_days existing_day on existing_day.id = existing.train_day_id
    where existing_day.train_id = target_train_id
      and lower(existing.username) = lower(clean_username)
  ) then
    raise exception 'You are already signed up for a slot on this train.' using errcode = 'P0001';
  end if;

  update public.slots s
  set username = clean_username
  where s.id = slot_id
    and s.username is null
    and (s.is_pre_assigned = false or is_unlimited_claimant)
    and exists (
      select 1
      from public.train_days d
      join public.trains t on t.id = d.train_id
      where d.id = s.train_day_id
        and (t.published = true or (t.is_upcoming = true and is_unlimited_claimant))
        and ((lower(coalesce(s.label, '')) <> 'kickoff' and s.slot_order <> 0) or is_unlimited_claimant)
    )
  returning s.* into claimed;

  if not found then
    raise exception 'Sorry - this slot is no longer available.' using errcode = 'P0001';
  end if;

  return claimed;
end;
$$;

grant execute on function public.claim_slot(uuid, text) to anon, authenticated;
