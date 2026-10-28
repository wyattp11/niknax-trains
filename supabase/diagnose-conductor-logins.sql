-- ============================================================
-- Why can't a conductor get back in?
-- Paste into Supabase → SQL Editor, edit the train name, run.
-- ============================================================
--
-- Read the "verdict" column:
--   • "still valid on the server" for a conductor who says they're locked out
--     means the server never ended their session — their phone/browser lost
--     the stored sign-in (new device, different app's browser, cleared data,
--     or iPhone Safari wiping site data after 7 days without a visit).
--   • "revoked" means someone removed them or their access was reset.
--   • "expired" means the 90 days ran out.

select
  t.name                                           as train,
  coalesce(tc.username, tc.email, s.email_key)     as conductor,
  to_char(s.created_at,   'Mon DD HH24:MI')        as signed_in,
  to_char(s.last_seen_at, 'Mon DD HH24:MI')        as last_used,
  to_char(s.expires_at,   'Mon DD')                as expires,
  case
    when s.revoked_at is not null then 'revoked ' || to_char(s.revoked_at, 'Mon DD HH24:MI')
    when s.expires_at <= now()     then 'expired'
    else 'still valid on the server'
  end                                              as verdict
from public.conductor_sessions s
join public.trains t              on t.id = s.train_id
left join public.train_conductors tc on tc.id = s.conductor_id
-- ↓↓↓ EDIT THIS ↓↓↓
where t.name ilike '%your train name%'
order by conductor, s.created_at;


-- Codes issued for the same train: when, whether used, and failed attempts.
-- Several used codes for one conductor = they've had to come back for a new
-- code more than once.
select
  coalesce(tc.username, tc.email)            as conductor,
  to_char(c.created_at, 'Mon DD HH24:MI')    as issued,
  to_char(c.used_at,    'Mon DD HH24:MI')    as used,
  to_char(c.expires_at, 'Mon DD HH24:MI')    as code_expires,
  c.attempts                                 as wrong_tries
from public.conductor_access_codes c
join public.trains t              on t.id = c.train_id
left join public.train_conductors tc on tc.id = c.conductor_id
where t.name ilike '%your train name%'      -- same name as above
order by conductor, c.created_at;
