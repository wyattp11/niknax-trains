-- ============================================================
-- ACTOR ATTRIBUTION FOR PUBLIC WRITES
-- ============================================================
--
-- Public writes run through security-definer RPCs as the anon role, so every
-- audit row would read "unknown". Each RPC needs to name its actor before it
-- touches a table, so the audit trigger can record who acted.
--
-- Rather than restate several hundred lines of RPC logic (and have to keep
-- two copies in sync forever), the existing functions are renamed to _impl
-- and a thin wrapper takes the original name. The wrapper records the actor,
-- delegates, and returns the result. Exceptions propagate unchanged.
--
-- The renames are guarded so this migration is safe to re-run.
-- ============================================================


-- ── Rename originals to _impl (idempotent) ────────────────────────────────

do $$
declare
  fn record;
begin
  for fn in
    select * from (values
      ('claim_slot',                'claim_slot_impl',                'uuid, text'),
      ('add_member_train_slot',     'add_member_train_slot_impl',     'uuid, text, uuid, time, integer, text'),
      ('edit_member_train_slot',    'edit_member_train_slot_impl',    'uuid, text, uuid, time, integer, text'),
      ('delete_member_train_slot',  'delete_member_train_slot_impl',  'uuid, text, uuid'),
      ('create_member_train',       'create_member_train_impl',       'text, text, text, text, text, text, jsonb')
    ) as t(orig, impl, args)
  loop
    -- Only rename if the _impl doesn't already exist and the original does
    if not exists (
      select 1 from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = fn.impl
    ) and exists (
      select 1 from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = fn.orig
    ) then
      execute format('alter function public.%I(%s) rename to %I', fn.orig, fn.args, fn.impl);
    end if;
  end loop;
end
$$;


-- ── Wrappers ──────────────────────────────────────────────────────────────

create or replace function public.claim_slot(slot_id uuid, claimant_username text)
returns public.slots
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.set_audit_actor(
    nullif(trim(regexp_replace(coalesce(claimant_username, ''), '^@+', '')), '')
  );
  return public.claim_slot_impl(slot_id, claimant_username);
end;
$$;

grant execute on function public.claim_slot(uuid, text) to anon, authenticated;


create or replace function public.add_member_train_slot(
  p_train_id uuid, p_conductor text, p_day_id uuid,
  p_start_time time, p_duration integer default 30, p_label text default null
)
returns public.slots
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.set_audit_actor(
    nullif(trim(regexp_replace(coalesce(p_conductor, ''), '^@+', '')), '')
  );
  return public.add_member_train_slot_impl(
    p_train_id, p_conductor, p_day_id, p_start_time, p_duration, p_label
  );
end;
$$;

grant execute on function public.add_member_train_slot(uuid, text, uuid, time, integer, text)
  to anon, authenticated;


create or replace function public.edit_member_train_slot(
  p_train_id uuid, p_conductor text, p_slot_id uuid,
  p_start_time time default null, p_duration integer default null, p_label text default null
)
returns public.slots
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.set_audit_actor(
    nullif(trim(regexp_replace(coalesce(p_conductor, ''), '^@+', '')), '')
  );
  return public.edit_member_train_slot_impl(
    p_train_id, p_conductor, p_slot_id, p_start_time, p_duration, p_label
  );
end;
$$;

grant execute on function public.edit_member_train_slot(uuid, text, uuid, time, integer, text)
  to anon, authenticated;


create or replace function public.delete_member_train_slot(
  p_train_id uuid, p_conductor text, p_slot_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.set_audit_actor(
    nullif(trim(regexp_replace(coalesce(p_conductor, ''), '^@+', '')), '')
  );
  perform public.delete_member_train_slot_impl(p_train_id, p_conductor, p_slot_id);
end;
$$;

grant execute on function public.delete_member_train_slot(uuid, text, uuid)
  to anon, authenticated;


create or replace function public.create_member_train(
  p_username text, p_name text, p_tagline text default null,
  p_description text default null, p_district_link text default null,
  p_rules_md text default null, p_days jsonb default '[]'::jsonb
)
returns public.trains
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.set_audit_actor(
    nullif(trim(regexp_replace(coalesce(p_username, ''), '^@+', '')), '')
  );
  return public.create_member_train_impl(
    p_username, p_name, p_tagline, p_description, p_district_link, p_rules_md, p_days
  );
end;
$$;

grant execute on function public.create_member_train(text, text, text, text, text, text, jsonb)
  to anon, authenticated;


-- The _impl functions must not be callable directly — that would bypass
-- actor recording (the checks inside them still apply either way).
revoke all on function public.claim_slot_impl(uuid, text) from anon, authenticated;
revoke all on function public.add_member_train_slot_impl(uuid, text, uuid, time, integer, text) from anon, authenticated;
revoke all on function public.edit_member_train_slot_impl(uuid, text, uuid, time, integer, text) from anon, authenticated;
revoke all on function public.delete_member_train_slot_impl(uuid, text, uuid) from anon, authenticated;
revoke all on function public.create_member_train_impl(text, text, text, text, text, text, jsonb) from anon, authenticated;
