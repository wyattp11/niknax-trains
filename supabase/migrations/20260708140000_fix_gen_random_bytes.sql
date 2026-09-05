-- ============================================================
-- FIX: "function gen_random_bytes(integer) does not exist"
-- ============================================================
--
-- gen_random_bytes() comes from pgcrypto, which Supabase installs into the
-- `extensions` schema — not `public`. The conductor auth functions are
-- declared with `set search_path = public`, so the call couldn't resolve and
-- every attempt to issue an access code failed.
--
-- (gen_random_uuid() worked in the same functions because it's core
-- Postgres, not pgcrypto, which is why this only showed up on the salt.)
--
-- Rather than restate four function bodies and risk them drifting from the
-- originals, this ensures pgcrypto is present and adds `extensions` to each
-- function's search_path. Behaviour is otherwise unchanged.
--
-- Run this after 20260708100000 and 20260708100200.
-- ============================================================

create extension if not exists pgcrypto with schema extensions;


do $$
declare
  fn text;
begin
  foreach fn in array array[
    'public.request_conductor_code(uuid, text)',
    'public.verify_conductor_code(uuid, text, text)',
    'public.admin_resend_conductor_code(uuid, text)',
    'public.create_member_train(text, text, text, text, text, text, text, jsonb)'
  ]
  loop
    -- Skip anything not present yet, so this is safe to run in any order.
    if to_regprocedure(fn) is not null then
      execute format('alter function %s set search_path = public, extensions', fn);
      raise notice 'search_path updated: %', fn;
    else
      raise notice 'not found, skipped: %', fn;
    end if;
  end loop;
end
$$;


-- ── Verify ───────────────────────────────────────────────────────────────
-- Every function below should list "public, extensions".

select
  p.proname                                        as function,
  coalesce(
    (select cfg from unnest(p.proconfig) as cfg where cfg like 'search_path=%'),
    '(none)'
  )                                                as search_path
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'request_conductor_code', 'verify_conductor_code',
    'admin_resend_conductor_code', 'create_member_train'
  )
order by p.proname;


-- Smoke test: this is what was failing. Should return a 32-character hex
-- string rather than an error.
select encode(extensions.gen_random_bytes(16), 'hex') as sample_salt;
