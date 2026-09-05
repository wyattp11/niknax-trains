-- ============================================================
-- DATABASE WEBHOOKS — created in SQL instead of the dashboard
-- ============================================================
--
-- Supabase's "Database Webhooks" UI just creates triggers that POST to a URL
-- using pg_net. That page has moved around between dashboard versions and
-- isn't always present, so this does the same thing directly.
--
-- Creates all four webhooks the edge function handles:
--   slots           UPDATE  -> "train is full" email
--   train_proposals INSERT  -> proposal submitted email
--   trains          INSERT  -> member train submitted email
--   email_outbox    INSERT  -> conductor access codes
--
-- ── BEFORE RUNNING ──────────────────────────────────────────────────────
-- Replace PASTE_YOUR_ANON_KEY_HERE below with your project's anon key:
--   Supabase Dashboard -> Project Settings -> API Keys -> anon / public
--
-- Safe to re-run: triggers are dropped and recreated.
-- ============================================================

create extension if not exists pg_net with schema extensions;


-- ── Config ────────────────────────────────────────────────────────────────
-- Held in app_settings so the key isn't baked into the trigger body and can
-- be rotated with a single UPDATE.

insert into public.app_settings (key, value)
values
  ('webhook_function_url',
   'https://favwuajyktuwuikkpmxe.supabase.co/functions/v1/send-notification'),
  ('webhook_anon_key',
   'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZhdnd1YWp5a3R1d3Vpa2twbXhlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE0NTcyNzcsImV4cCI6MjA5NzAzMzI3N30.ne1kblyZlwbXKvfH_Grl3wo6isPVImRou6MwICqhHyQ')
on conflict (key) do update set value = excluded.value;


-- ── Dispatcher ────────────────────────────────────────────────────────────
-- Builds the same payload shape the dashboard sends, so the edge function
-- needs no changes: { type, table, schema, record, old_record }

create or replace function public.notify_edge_function()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url  text;
  v_key  text;
  v_body jsonb;
begin
  select value into v_url from public.app_settings where key = 'webhook_function_url';
  select value into v_key from public.app_settings where key = 'webhook_anon_key';

  -- Not configured yet — do nothing rather than break the write
  if v_url is null or v_key is null or v_key = 'PASTE_YOUR_ANON_KEY_HERE' then
    return null;
  end if;

  v_body := jsonb_build_object(
    'type',       tg_op,
    'table',      tg_table_name,
    'schema',     tg_table_schema,
    'record',     case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) else null end,
    'old_record', case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) else null end
  );

  -- Fire and forget. pg_net is async, so a slow or failing mailer never
  -- blocks or rolls back the write that triggered it.
  perform net.http_post(
    url     := v_url,
    headers := jsonb_build_object(
                 'Content-Type',  'application/json',
                 'Authorization', 'Bearer ' || v_key
               ),
    body    := v_body
  );

  return null;
exception when others then
  -- Never let a notification failure take down a signup or an edit.
  raise warning 'notify_edge_function failed: %', sqlerrm;
  return null;
end;
$$;


-- ── Attach ────────────────────────────────────────────────────────────────

drop trigger if exists webhook_slots_update      on public.slots;
drop trigger if exists webhook_proposals_insert  on public.train_proposals;
drop trigger if exists webhook_trains_insert     on public.trains;
drop trigger if exists webhook_outbox_insert     on public.email_outbox;

-- 1. Train full
create trigger webhook_slots_update
  after update of username on public.slots
  for each row execute function public.notify_edge_function();

-- 2. Proposal submitted
create trigger webhook_proposals_insert
  after insert on public.train_proposals
  for each row execute function public.notify_edge_function();

-- 3. Member train submitted
create trigger webhook_trains_insert
  after insert on public.trains
  for each row execute function public.notify_edge_function();

-- 4. Conductor access codes
--    Only exists once the conductor-auth migration has run.
do $$
begin
  if to_regclass('public.email_outbox') is not null then
    execute '
      create trigger webhook_outbox_insert
        after insert on public.email_outbox
        for each row execute function public.notify_edge_function()';
  else
    raise notice 'email_outbox not found — run 20260708100000_conductor_auth first, then re-run this.';
  end if;
end
$$;


-- ── Verify ────────────────────────────────────────────────────────────────

select
  c.relname                                  as table_name,
  t.tgname                                   as webhook,
  case when t.tgenabled = 'D' then 'disabled' else 'active' end as status
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and t.tgname like 'webhook_%'
  and not t.tgisinternal
order by c.relname;

-- Confirm the key was set (shows only the last 6 characters)
select
  key,
  case
    when value = 'PASTE_YOUR_ANON_KEY_HERE' then '❌ NOT SET — edit and re-run'
    else '✅ set … ' || right(value, 6)
  end as value
from public.app_settings
where key in ('webhook_function_url', 'webhook_anon_key');
