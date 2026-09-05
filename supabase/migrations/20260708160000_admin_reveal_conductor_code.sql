-- ============================================================
-- Admin can read a conductor's access code directly
-- ============================================================
--
-- Codes are stored hashed, so once issued nobody — including an admin — can
-- read one back. That's correct for security but leaves no way to help a
-- conductor when email delivery fails, which it currently does for every
-- recipient except the Resend account's own verified address.
--
-- admin_resend_conductor_code now returns the plaintext of the code it just
-- generated, so an admin can read it out or text it while domain
-- verification is pending. This does not weaken the model:
--
--   • Admin-only, already gated by is_admin().
--   • Returns only the code it generated in this call — past codes stay
--     unreadable because only their hashes were ever stored.
--   • The emailed copy is still sent as normal.
--
-- Also records why a send failed, so failures stop being silent.
-- ============================================================

create or replace function public.admin_resend_conductor_code(
  p_train_id uuid,
  p_email    text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions   -- pgcrypto lives in extensions
as $$
declare
  v_email_key  text;
  v_conductor  public.train_conductors;
  v_code       text;
  v_salt       text;
  v_train_name text;
begin
  if not public.is_admin() then
    raise exception 'Admins only.' using errcode = 'P0001';
  end if;

  v_email_key := lower(nullif(trim(coalesce(p_email, '')), ''));

  select * into v_conductor
  from public.train_conductors
  where train_id = p_train_id and email_key = v_email_key;

  if not found then
    raise exception 'That email is not a conductor on this train.' using errcode = 'P0001';
  end if;

  select name into v_train_name from public.trains where id = p_train_id;

  v_code := lpad((floor(random() * 1000000))::integer::text, 6, '0');
  v_salt := encode(gen_random_bytes(16), 'hex');

  update public.conductor_access_codes
  set used_at = now()
  where train_id = p_train_id and email_key = v_email_key and used_at is null;

  insert into public.conductor_access_codes
    (train_id, email_key, code_hash, salt, expires_at)
  values
    (p_train_id, v_email_key, public.hash_secret(v_code, v_salt), v_salt,
     now() + interval '30 minutes');

  insert into public.email_outbox (kind, recipient, payload)
  values (
    'conductor_code',
    v_conductor.email,
    jsonb_build_object(
      'code',       v_code,
      'train_id',   p_train_id,
      'train_name', coalesce(v_train_name, 'your train'),
      'expires_in', '30 minutes'
    )
  );

  -- Returned so an admin can pass it along directly when email can't reach
  -- the recipient. Expires in 30 minutes like any other code.
  return jsonb_build_object(
    'ok',         true,
    'code',       v_code,
    'email',      v_conductor.email,
    'expires_at', now() + interval '30 minutes'
  );
end;
$$;

grant execute on function public.admin_resend_conductor_code(uuid, text) to authenticated;


-- ── Surface delivery failures ────────────────────────────────────────────
-- Admins need to see why a send failed; the outbox already has an error
-- column but nothing could write to it.

grant select, update on public.email_outbox to authenticated;

drop policy if exists "admin read email outbox" on public.email_outbox;
create policy "admin read email outbox"
on public.email_outbox
for select
to authenticated
using (public.is_admin());

drop policy if exists "admin update email outbox" on public.email_outbox;
create policy "admin update email outbox"
on public.email_outbox
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());
