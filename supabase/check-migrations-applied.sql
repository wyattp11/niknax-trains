-- ============================================================
-- WHICH MIGRATIONS ARE APPLIED?
-- Checks for each migration's key object. Run in the SQL Editor.
-- ============================================================

with checks(seq, migration, what_it_adds, applied) as (
  values
    (1, '20260707120000_member_strikes',
        'Seller strikes + Settings page',
        to_regclass('public.member_strikes') is not null),

    (2, '20260707140000_train_chat',
        'Train chat',
        to_regclass('public.train_chat_messages') is not null),

    (3, '20260707160000_flexible_staff_roles',
        'MODERATOR badge can claim mod slots',
        exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                where n.nspname = 'public' and p.proname = 'is_staff_role')),

    (4, '20260707180000_fix_slot_ordering_and_midnight_shift',
        'Slots insert in time order; midnight-safe delete  ← THE BELTS FIX',
        exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                where n.nspname = 'public' and p.proname = 'shift_time')),

    (5, '20260707200000_audit_log',
        'Change history',
        to_regclass('public.audit_log') is not null),

    (6, '20260707200100_audit_actor_attribution',
        'History records who made each change',
        exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                where n.nspname = 'public' and p.proname = 'set_audit_actor')),

    (7, '20260707220000_optional_kickoff',
        'Kickoff checkbox for member trains',
        exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                where n.nspname = 'public' and p.proname = 'add_member_train_day'
                  and pg_get_function_identity_arguments(p.oid) like '%boolean%')),

    (8, '20260708100000_conductor_auth',
        'Conductor emails + passcodes',
        to_regclass('public.train_conductors') is not null),

    (9, '20260708100100_conductor_token_rpcs',
        'Conductor writes require a verified session',
        exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                where n.nspname = 'public' and p.proname = 'require_conductor')),

    (10, '20260708100200_create_member_train_with_email',
        'Train creation captures the conductor email',
        exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                where n.nspname = 'public' and p.proname = 'create_member_train'
                  and pg_get_function_identity_arguments(p.oid) like 'text, text, text%'))
)
select
  seq                                        as "#",
  case when applied then '✅ applied' else '❌ MISSING' end as status,
  migration,
  what_it_adds
from checks
order by seq;
