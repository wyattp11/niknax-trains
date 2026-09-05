-- ============================================================
-- ADMIN-ISSUED ACCESS CODES — no email required
-- ============================================================
--
-- Email delivery to anyone other than the Resend account's own verified
-- address needs a verified domain, which isn't in place. Rather than block
-- conductors on DNS, the admin now issues a code directly and passes it on
-- however they like — text, DM, in person.
--
--   Admin clicks "Generate code" on a conductor  ->  code valid 48 hours
--   Conductor clicks "Manage your train", enters the code  ->  90-day session
--
-- No email step, and no email address required at all: a conductor can be
-- registered by username alone.
--
-- The code itself identifies which conductor is redeeming it, so attribution
-- in the audit log still works — each person gets their own code.
--
-- Codes are longer than the old 6-digit ones (8 characters from a 32-symbol
-- alphabet, ~10^12 combinations) because there's no second factor now that
-- the email step is gone.
-- ============================================================


-- ── Schema ────────────────────────────────────────────────────────────────

-- Email is now optional; a conductor can be identified by username alone.
alter table public.train_conductors alter column email drop not null;
alter table public.train_conductors alter column email_key drop not null;

-- Tie codes and sessions to the conductor row rather than to an email.
alter table public.conductor_access_codes
  add column if not exists conductor_id uuid references public.train_conductors(id) on delete cascade;

alter table public.conductor_sessions
  add column if not exists conductor_id uuid references public.train_conductors(id) on delete cascade;

create index if not exists conductor_codes_conductor_idx
  on public.conductor_access_codes(conductor_id) where used_at is null;

-- Backfill existing rows so live sessions keep working.
update public.conductor_access_codes c
set conductor_id = tc.id
from public.train_conductors tc
where c.conductor_id is null
  and tc.train_id = c.train_id
  and tc.email_key = c.email_key;

update public.conductor_sessions s
set conductor_id = tc.id
from public.train_conductors tc
where s.conductor_id is null
  and tc.train_id = s.train_id
  and tc.email_key = s.email_key;

-- A conductor needs some way to be identified.
alter table public.train_conductors drop constraint if exists train_conductors_identity_check;
alter table public.train_conductors add constraint train_conductors_identity_check
  check (email_key is not null or username is not null);


-- ── Readable code generator ───────────────────────────────────────────────
-- Alphabet excludes 0/O/1/I/L so codes can be read aloud or texted without
-- being mistyped. Formatted as XXXX-XXXX for legibility.

create or replace function public.generate_access_code()
returns text
language plpgsql
volatile
set search_path = public, extensions
as $$
declare
  alphabet constant text := '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  result   text := '';
  i        integer;
begin
  for i in 1..8 loop
    result := result || substr(alphabet, 1 + floor(random() * length(alphabet))::integer, 1);
    if i = 4 then result := result || '-'; end if;
  end loop;
  return result;
end;
$$;


-- Normalizes user input: uppercase, strip anything that isn't in the
-- alphabet, then re-insert the dash. So "abcd efgh" and "ABCD-EFGH" match.
create or replace function public.normalize_access_code(p_code text)
returns text
language sql
immutable
as $$
  select case
    when length(cleaned) = 8 then substr(cleaned, 1, 4) || '-' || substr(cleaned, 5, 4)
    else cleaned
  end
  from (
    select regexp_replace(upper(coalesce(p_code, '')), '[^2-9A-HJ-NP-Z]', '', 'g') as cleaned
  ) t;
$$;


-- ── Admin issues a code ───────────────────────────────────────────────────

create or replace function public.admin_create_conductor_code(
  p_conductor_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_conductor public.train_conductors;
  v_code      text;
  v_salt      text;
  v_expires   timestamptz;
begin
  if not public.is_admin() then
    raise exception 'Admins only.' using errcode = 'P0001';
  end if;

  select * into v_conductor from public.train_conductors where id = p_conductor_id;

  if not found then
    raise exception 'Conductor not found.' using errcode = 'P0001';
  end if;

  v_code    := public.generate_access_code();
  v_salt    := encode(gen_random_bytes(16), 'hex');
  v_expires := now() + interval '48 hours';

  -- Issuing a new code retires any earlier one for this conductor.
  update public.conductor_access_codes
  set used_at = now()
  where conductor_id = p_conductor_id and used_at is null;

  insert into public.conductor_access_codes
    (train_id, conductor_id, email_key, code_hash, salt, expires_at)
  values
    (v_conductor.train_id, p_conductor_id, v_conductor.email_key,
     public.hash_secret(v_code, v_salt), v_salt, v_expires);

  return jsonb_build_object(
    'ok',         true,
    'code',       v_code,
    'expires_at', v_expires,
    'conductor',  coalesce(v_conductor.username, v_conductor.email)
  );
end;
$$;

grant execute on function public.admin_create_conductor_code(uuid) to authenticated;


-- ── Conductor redeems a code ──────────────────────────────────────────────
-- Takes only the code. Matching it identifies the conductor, so there's no
-- email or username to enter.

create or replace function public.redeem_conductor_code(
  p_train_id uuid,
  p_code     text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_clean     text;
  v_row       public.conductor_access_codes;
  v_conductor public.train_conductors;
  v_token     text;
  v_salt      text;
  v_expires   timestamptz;
  v_attempts  integer;
begin
  v_clean := public.normalize_access_code(p_code);

  if length(coalesce(v_clean, '')) < 9 then
    raise exception 'Enter the 8-character code your Niknax admin gave you.'
      using errcode = '22023';
  end if;

  -- Rate limit: 10 misses against the codes currently live on this train.
  -- Scoped to live codes only — counting expired ones would accumulate
  -- indefinitely and eventually lock out a legitimate conductor. Issuing a
  -- fresh code retires the old ones, which resets the counter.
  select coalesce(sum(attempts), 0) into v_attempts
  from public.conductor_access_codes
  where train_id = p_train_id
    and used_at is null
    and expires_at > now();

  if v_attempts >= 10 then
    raise exception 'Too many incorrect attempts. Ask your Niknax admin for a new code.'
      using errcode = 'P0001';
  end if;

  -- Find the code by comparing hashes; each row has its own salt.
  for v_row in
    select * from public.conductor_access_codes
    where train_id = p_train_id
      and used_at is null
      and expires_at > now()
      and conductor_id is not null
  loop
    if public.hash_secret(v_clean, v_row.salt) = v_row.code_hash then
      exit;
    end if;
    v_row := null;
  end loop;

  if v_row.id is null then
    -- Record the miss against every live code on this train
    update public.conductor_access_codes
    set attempts = attempts + 1
    where train_id = p_train_id and used_at is null and expires_at > now();

    raise exception 'That code isn''t valid or has expired. Ask your Niknax admin for a new one.'
      using errcode = 'P0001';
  end if;

  select * into v_conductor from public.train_conductors where id = v_row.conductor_id;

  if not found then
    raise exception 'That code is no longer linked to a conductor.' using errcode = 'P0001';
  end if;

  -- A code is single-use: redeeming it issues the long session.
  update public.conductor_access_codes set used_at = now() where id = v_row.id;

  v_token   := replace(gen_random_uuid()::text, '-', '')
            || replace(gen_random_uuid()::text, '-', '');
  v_salt    := encode(gen_random_bytes(16), 'hex');
  v_expires := now() + interval '90 days';

  insert into public.conductor_sessions
    (train_id, conductor_id, email_key, token_hash, salt, expires_at, last_seen_at)
  values
    (p_train_id, v_conductor.id, v_conductor.email_key,
     public.hash_secret(v_token, v_salt), v_salt, v_expires, now());

  return jsonb_build_object(
    'token',      v_token,
    'expires_at', v_expires,
    'email',      v_conductor.email,
    'username',   v_conductor.username
  );
end;
$$;

grant execute on function public.redeem_conductor_code(uuid, text) to anon, authenticated;


-- ── Session validation, now keyed on conductor_id ─────────────────────────
-- Returns a display label for the audit actor rather than an email, since a
-- conductor may not have one.

create or replace function public.conductor_email_for_token(
  p_train_id uuid,
  p_token    text
)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_row   public.conductor_sessions;
  v_label text;
begin
  if nullif(trim(coalesce(p_token, '')), '') is null then
    return null;
  end if;

  for v_row in
    select * from public.conductor_sessions
    where train_id = p_train_id
      and revoked_at is null
      and expires_at > now()
  loop
    if public.hash_secret(p_token, v_row.salt) = v_row.token_hash then
      update public.conductor_sessions set last_seen_at = now() where id = v_row.id;

      select coalesce(username, email, email_key) into v_label
      from public.train_conductors
      where id = v_row.conductor_id;

      -- Sessions predating conductor_id still carry an email_key
      return coalesce(v_label, v_row.email_key);
    end if;
  end loop;

  return null;
end;
$$;

grant execute on function public.conductor_email_for_token(uuid, text) to anon, authenticated;


-- ── Session info ──────────────────────────────────────────────────────────

create or replace function public.conductor_session_info(p_train_id uuid, p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_label text;
  v_row   public.train_conductors;
begin
  v_label := public.conductor_email_for_token(p_train_id, p_token);
  if v_label is null then
    return jsonb_build_object('valid', false);
  end if;

  select tc.* into v_row
  from public.conductor_sessions s
  join public.train_conductors tc on tc.id = s.conductor_id
  where s.train_id = p_train_id
    and s.revoked_at is null
    and s.expires_at > now()
    and public.hash_secret(p_token, s.salt) = s.token_hash
  limit 1;

  return jsonb_build_object(
    'valid',      true,
    'email',      v_row.email,
    'username',   coalesce(v_row.username, v_row.email, v_label),
    'is_primary', coalesce(v_row.is_primary, false),
    'conductors', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'email', c.email, 'username', c.username, 'is_primary', c.is_primary
             ) order by c.is_primary desc, c.created_at), '[]'::jsonb)
      from public.train_conductors c where c.train_id = p_train_id
    )
  );
end;
$$;

grant execute on function public.conductor_session_info(uuid, text) to anon, authenticated;


-- ── Retire the email-based flow ───────────────────────────────────────────
-- request_conductor_code and verify_conductor_code are no longer reachable
-- from the UI; dropping them keeps the surface honest.

drop function if exists public.request_conductor_code(uuid, text);
drop function if exists public.verify_conductor_code(uuid, text, text);
drop function if exists public.admin_resend_conductor_code(uuid, text);
