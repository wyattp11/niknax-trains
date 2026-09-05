-- ============================================================
-- Admin management of conductor sessions
-- ============================================================
--
-- conductor_sessions was revoked from every role so tokens could only be
-- checked through security-definer functions. That also blocked admins from
-- revoking a session, which means removing a conductor in the admin UI would
-- delete their row but leave their 90-day token working until it expired.
--
-- Admins get SELECT and UPDATE only — enough to see and revoke sessions.
-- No INSERT, so nobody can mint a session by hand; issuing one still requires
-- a verified code through verify_conductor_code().
-- ============================================================

grant select, update on public.conductor_sessions to authenticated;

drop policy if exists "admin read conductor sessions" on public.conductor_sessions;
create policy "admin read conductor sessions"
on public.conductor_sessions
for select
to authenticated
using (public.is_admin());

drop policy if exists "admin revoke conductor sessions" on public.conductor_sessions;
create policy "admin revoke conductor sessions"
on public.conductor_sessions
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());


-- Removing a conductor should take their access with it. Belt and braces
-- alongside the UI doing the same thing, so a session can't outlive its row.

create or replace function public.revoke_sessions_on_conductor_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.conductor_sessions
  set revoked_at = now()
  where train_id = old.train_id
    and email_key = old.email_key
    and revoked_at is null;
  return old;
end;
$$;

drop trigger if exists revoke_sessions_on_conductor_delete on public.train_conductors;
create trigger revoke_sessions_on_conductor_delete
  after delete on public.train_conductors
  for each row execute function public.revoke_sessions_on_conductor_delete();
