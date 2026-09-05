-- ============================================================
-- WHY ISN'T THE CODE EMAIL ARRIVING?
-- Walks the chain and shows where it stops. Run all six.
-- ============================================================
--
--   request_conductor_code()  ->  conductor_access_codes   [1]
--                             ->  email_outbox             [2]
--   trigger  ->  pg_net  ->  edge function                 [3][4]
--                        ->  Resend  ->  inbox             [5]
-- ============================================================


-- ── 1. Is the conductor registered? ──────────────────────────────────────
-- request_conductor_code returns success even for an unregistered email, by
-- design, so nothing is sent if this comes back empty.

select 'STEP 1: conductors' as step, c.email, c.username, c.is_primary, t.name as train
from public.train_conductors c
join public.trains t on t.id = c.train_id
order by t.name, c.is_primary desc;


-- ── 2. Were codes actually generated? ────────────────────────────────────

select
  'STEP 2: codes' as step,
  to_char(created_at, 'Mon DD HH24:MI:SS') as created,
  email_key,
  case when used_at is not null then 'used/superseded' else 'active' end as state,
  case when expires_at < now() then 'expired' else 'valid' end as expiry
from public.conductor_access_codes
order by created_at desc
limit 10;


-- ── 3. Did anything reach the outbox? ────────────────────────────────────
-- sent_at null = the edge function never confirmed sending it.

select
  'STEP 3: outbox' as step,
  to_char(created_at, 'Mon DD HH24:MI:SS') as queued,
  kind,
  recipient,
  case when sent_at is null then '❌ NEVER SENT' else '✅ sent ' || to_char(sent_at, 'HH24:MI:SS') end as status,
  coalesce(error, '')                       as error,
  payload ? 'code'                          as still_has_code
from public.email_outbox
order by created_at desc
limit 10;


-- ── 4. Is the webhook trigger attached? ──────────────────────────────────

select
  'STEP 4: triggers' as step,
  c.relname as table_name,
  t.tgname  as trigger_name,
  case when t.tgenabled = 'D' then '❌ disabled' else '✅ active' end as status
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and t.tgname like 'webhook_%' and not t.tgisinternal
order by c.relname;


-- ── 5. Did pg_net actually make the HTTP call, and what came back? ───────
-- This is usually where the answer is. A 401 means the anon key is wrong,
-- 404 the function isn't deployed, 500 the function threw. No rows at all
-- means the trigger never fired.

select
  'STEP 5: http calls' as step,
  to_char(r.created, 'Mon DD HH24:MI:SS') as called,
  r.status_code,
  case
    when r.status_code between 200 and 299 then '✅ edge function accepted it'
    when r.status_code = 401 then '❌ bad anon key'
    when r.status_code = 404 then '❌ function not deployed at that URL'
    when r.status_code >= 500 then '❌ function errored — check its logs'
    when r.status_code is null then '❌ no response (timeout / bad URL)'
    else '⚠ unexpected'
  end                                       as verdict,
  coalesce(r.error_msg, '')                 as error_msg,
  left(coalesce(r.content, ''), 300)        as response_body
from net._http_response r
order by r.created desc
limit 10;


-- ── 6. Is the outbox trigger config present? ─────────────────────────────

select
  'STEP 6: config' as step,
  key,
  case
    when value is null or value = '' then '❌ empty'
    when value = 'PASTE_YOUR_ANON_KEY_HERE' then '❌ placeholder — not set'
    when key = 'webhook_anon_key' then '✅ set … ' || right(value, 8)
    else '✅ ' || value
  end as value
from public.app_settings
where key in ('webhook_function_url', 'webhook_anon_key');
