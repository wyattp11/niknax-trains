-- ============================================================
-- CONDUCTOR AUTHENTICATION — emailed passcodes
-- ============================================================
--
-- Conductor access was previously "type your own username", which verified
-- nothing: anyone who knew a conductor's handle could edit their train.
-- Access is now proven by receiving a one-time code at a registered email.
--
--   1. Conductor enters their email on the manage page.
--   2. request_conductor_code() issues a 6-digit code, stores only its hash,
--      and queues the plaintext in an outbox for the mailer.
--   3. verify_conductor_code() checks it and returns a session token; only
--      the token's hash is stored.
--   4. Every write RPC validates the token.
--
-- Codes expire in 30 minutes. Sessions last 90 days — trains get planned
-- months ahead and re-authenticating on every visit would be miserable.
--
-- Notes on the hashing: sha256() is core Postgres (11+). Salts come from
-- pgcrypto's gen_random_bytes(), which Supabase installs into the
-- `extensions` schema — hence `search_path = public, extensions` on the
-- functions below. Each code and token gets its own salt, so two identical
-- codes never share a hash.
-- ============================================================

create extension if not exists pgcrypto with schema extensions;


-- ── Conductors ────────────────────────────────────────────────────────────

create table if not exists public.train_conductors (
  id         uuid primary key default gen_random_uuid(),
  train_id   uuid not null references public.trains(id) on delete cascade,
  email      text not null,
  email_key  text not null,                    -- lowercased, for lookups
  username   text,                             -- display name, optional
  is_primary boolean not null default false,   -- the creator
  created_at timestamptz not null default now(),
  unique (train_id, email_key)
);

create index if not exists train_conductors_train_idx on public.train_conductors(train_id);
create index if not exists train_conductors_email_idx on public.train_conductors(email_key);

alter table public.train_conductors enable row level security;

drop policy if exists "admin manage conductors" on public.train_conductors;
create policy "admin manage conductors"
on public.train_conductors
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- Anon never reads this table directly; emails are private.
revoke all on public.train_conductors from anon;


-- ── One-time codes ────────────────────────────────────────────────────────

create table if not exists public.conductor_access_codes (
  id         uuid primary key default gen_random_uuid(),
  train_id   uuid not null references public.trains(id) on delete cascade,
  email_key  text not null,
  code_hash  text not null,
  salt       text not null,
  attempts   integer not null default 0,
  expires_at timestamptz not null,
  used_at    timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists conductor_codes_lookup_idx
  on public.conductor_access_codes(train_id, email_key, expires_at desc);

alter table public.conductor_access_codes enable row level security;
revoke all on public.conductor_access_codes from anon, authenticated;


-- ── Sessions ──────────────────────────────────────────────────────────────

create table if not exists public.conductor_sessions (
  id           uuid primary key default gen_random_uuid(),
  train_id     uuid not null references public.trains(id) on delete cascade,
  email_key    text not null,
  token_hash   text not null,
  salt         text not null,
  expires_at   timestamptz not null,
  revoked_at   timestamptz,
  last_seen_at timestamptz,
  created_at   timestamptz not null default now()
);

create index if not exists conductor_sessions_lookup_idx
  on public.conductor_sessions(train_id, expires_at desc);

alter table public.conductor_sessions enable row level security;
revoke all on public.conductor_sessions from anon, authenticated;


-- ── Email outbox ──────────────────────────────────────────────────────────
-- The codes table stores only hashes, so the mailer can't read a code from
-- it. The plaintext is queued here instead, and the edge function deletes
-- each row once sent.

create table if not exists public.email_outbox (
  id         uuid primary key default gen_random_uuid(),
  kind       text not null,
  recipient  text not null,
  payload    jsonb not null default '{}'::jsonb,
  sent_at    timestamptz,
  error      text,
  created_at timestamptz not null default now()
);

create index if not exists email_outbox_unsent_idx
  on public.email_outbox(created_at) where sent_at is null;

alter table public.email_outbox enable row level security;
revoke all on public.email_outbox from anon, authenticated;


-- ── Hash helper ───────────────────────────────────────────────────────────

create or replace function public.hash_secret(p_secret text, p_salt text)
returns text
language sql
immutable
as $$
  select encode(sha256((coalesce(p_salt, '') || ':' || coalesce(p_secret, ''))::bytea), 'hex');
$$;


-- ── Request a code ────────────────────────────────────────────────────────

create or replace function public.request_conductor_code(
  p_train_id uuid,
  p_email    text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions   -- pgcrypto lives in extensions
as $$
declare
  v_email_key   text;
  v_is_member   boolean := false;
  v_conductor   public.train_conductors;
  v_code        text;
  v_salt        text;
  v_recent      integer;
  v_train_name  text;
begin
  v_email_key := lower(nullif(trim(coalesce(p_email, '')), ''));

  if v_email_key is null or v_email_key !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'Please enter a valid email address.' using errcode = '22023';
  end if;

  select coalesce(is_member_train, false), name
  into v_is_member, v_train_name
  from public.trains where id = p_train_id;

  if not coalesce(v_is_member, false) then
    raise exception 'This train does not use conductor access.' using errcode = 'P0001';
  end if;

  select * into v_conductor
  from public.train_conductors
  where train_id = p_train_id and email_key = v_email_key;

  -- Don't reveal whether an email is registered. Return the same shape
  -- either way; only send mail when it actually matches.
  if not found then
    return jsonb_build_object('ok', true);
  end if;

  -- Throttle: at most 3 codes per email per train in 15 minutes
  select count(*) into v_recent
  from public.conductor_access_codes
  where train_id = p_train_id
    and email_key = v_email_key
    and created_at > now() - interval '15 minutes';

  if v_recent >= 3 then
    raise exception 'Too many code requests. Please wait 15 minutes and try again.'
      using errcode = 'P0001';
  end if;

  -- 6 digits, zero-padded
  v_code := lpad((floor(random() * 1000000))::integer::text, 6, '0');
  v_salt := encode(gen_random_bytes(16), 'hex');

  -- Any earlier unused codes for this email are superseded
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

  return jsonb_build_object('ok', true);
end;
$$;

grant execute on function public.request_conductor_code(uuid, text) to anon, authenticated;


-- ── Verify a code, issue a session ────────────────────────────────────────

create or replace function public.verify_conductor_code(
  p_train_id uuid,
  p_email    text,
  p_code     text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions   -- pgcrypto lives in extensions
as $$
declare
  v_email_key text;
  v_row       public.conductor_access_codes;
  v_token     text;
  v_salt      text;
  v_conductor public.train_conductors;
begin
  v_email_key := lower(nullif(trim(coalesce(p_email, '')), ''));

  select * into v_row
  from public.conductor_access_codes
  where train_id = p_train_id
    and email_key = v_email_key
    and used_at is null
  order by created_at desc
  limit 1;

  if not found then
    raise exception 'That code is not valid. Request a new one.' using errcode = 'P0001';
  end if;

  if v_row.expires_at < now() then
    raise exception 'That code has expired. Request a new one.' using errcode = 'P0001';
  end if;

  if v_row.attempts >= 5 then
    raise exception 'Too many incorrect attempts. Request a new code.' using errcode = 'P0001';
  end if;

  if public.hash_secret(trim(coalesce(p_code, '')), v_row.salt) <> v_row.code_hash then
    update public.conductor_access_codes set attempts = attempts + 1 where id = v_row.id;
    raise exception 'That code is not correct.' using errcode = 'P0001';
  end if;

  update public.conductor_access_codes set used_at = now() where id = v_row.id;

  select * into v_conductor
  from public.train_conductors
  where train_id = p_train_id and email_key = v_email_key;

  -- 256 bits of entropy across two UUIDs
  v_token := replace(gen_random_uuid()::text, '-', '')
          || replace(gen_random_uuid()::text, '-', '');
  v_salt  := encode(gen_random_bytes(16), 'hex');

  insert into public.conductor_sessions
    (train_id, email_key, token_hash, salt, expires_at, last_seen_at)
  values
    (p_train_id, v_email_key, public.hash_secret(v_token, v_salt), v_salt,
     now() + interval '90 days', now());

  return jsonb_build_object(
    'token',      v_token,
    'expires_at', (now() + interval '90 days'),
    'email',      v_conductor.email,
    'username',   v_conductor.username
  );
end;
$$;

grant execute on function public.verify_conductor_code(uuid, text, text) to anon, authenticated;


-- ── Validate a session ────────────────────────────────────────────────────
-- Returns the conductor's email_key, or null. Every write RPC calls this.

create or replace function public.conductor_email_for_token(
  p_train_id uuid,
  p_token    text
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.conductor_sessions;
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
      return v_row.email_key;
    end if;
  end loop;

  return null;
end;
$$;

grant execute on function public.conductor_email_for_token(uuid, text) to anon, authenticated;


-- Raises unless the token is a valid conductor session for this train.
create or replace function public.require_conductor(p_train_id uuid, p_token text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
begin
  v_email := public.conductor_email_for_token(p_train_id, p_token);

  if v_email is null then
    raise exception 'Your access has expired. Request a new code to continue.'
      using errcode = 'P0001', detail = 'conductor_auth';
  end if;

  perform public.set_audit_actor(v_email);
  return v_email;
end;
$$;

grant execute on function public.require_conductor(uuid, text) to anon, authenticated;


-- ── Session info (for the UI) ─────────────────────────────────────────────

create or replace function public.conductor_session_info(p_train_id uuid, p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
  v_row   public.train_conductors;
begin
  v_email := public.conductor_email_for_token(p_train_id, p_token);
  if v_email is null then
    return jsonb_build_object('valid', false);
  end if;

  select * into v_row
  from public.train_conductors
  where train_id = p_train_id and email_key = v_email;

  return jsonb_build_object(
    'valid',      true,
    'email',      v_row.email,
    'username',   v_row.username,
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


-- ── Co-conductors ─────────────────────────────────────────────────────────

create or replace function public.add_train_conductor(
  p_train_id uuid,
  p_token    text,
  p_email    text,
  p_username text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor     text;
  v_email_key text;
  v_count     integer;
begin
  v_actor     := public.require_conductor(p_train_id, p_token);
  v_email_key := lower(nullif(trim(coalesce(p_email, '')), ''));

  if v_email_key is null or v_email_key !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'Please enter a valid email address.' using errcode = '22023';
  end if;

  select count(*) into v_count from public.train_conductors where train_id = p_train_id;
  if v_count >= 5 then
    raise exception 'A train can have at most 5 conductors.' using errcode = 'P0001';
  end if;

  insert into public.train_conductors (train_id, email, email_key, username, is_primary)
  values (p_train_id, trim(p_email), v_email_key,
          nullif(trim(regexp_replace(coalesce(p_username, ''), '^@+', '')), ''), false)
  on conflict (train_id, email_key) do nothing;

  return jsonb_build_object('ok', true);
end;
$$;

grant execute on function public.add_train_conductor(uuid, text, text, text) to anon, authenticated;


create or replace function public.remove_train_conductor(
  p_train_id uuid,
  p_token    text,
  p_email    text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor     text;
  v_email_key text;
  v_target    public.train_conductors;
begin
  v_actor     := public.require_conductor(p_train_id, p_token);
  v_email_key := lower(nullif(trim(coalesce(p_email, '')), ''));

  select * into v_target
  from public.train_conductors
  where train_id = p_train_id and email_key = v_email_key;

  if not found then
    return jsonb_build_object('ok', true);
  end if;

  if v_target.is_primary then
    raise exception 'The primary conductor cannot be removed.' using errcode = 'P0001';
  end if;

  -- Revoke their sessions so removal takes effect immediately
  update public.conductor_sessions
  set revoked_at = now()
  where train_id = p_train_id and email_key = v_email_key and revoked_at is null;

  delete from public.train_conductors where id = v_target.id;

  return jsonb_build_object('ok', true);
end;
$$;

grant execute on function public.remove_train_conductor(uuid, text, text) to anon, authenticated;


-- ── Admin: resend a code ──────────────────────────────────────────────────

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
      'code', v_code,
      'train_id', p_train_id,
      'train_name', coalesce(v_train_name, 'your train'),
      'expires_in', '30 minutes'
    )
  );

  return jsonb_build_object('ok', true);
end;
$$;

grant execute on function public.admin_resend_conductor_code(uuid, text) to authenticated;


-- ── Admin view of conductors ──────────────────────────────────────────────

create or replace view public.train_conductors_admin
with (security_invoker = true)
as
select
  c.id, c.train_id, c.email, c.username, c.is_primary, c.created_at,
  (select max(s.last_seen_at)
     from public.conductor_sessions s
    where s.train_id = c.train_id
      and s.email_key = c.email_key
      and s.revoked_at is null) as last_seen_at
from public.train_conductors c;

grant select on public.train_conductors_admin to authenticated;


-- ── Housekeeping ──────────────────────────────────────────────────────────
-- Expired codes and sessions serve no purpose; drop them opportunistically.

create or replace function public.purge_expired_conductor_auth()
returns void
language sql
security definer
set search_path = public
as $$
  with c as (
    delete from public.conductor_access_codes
    where expires_at < now() - interval '7 days' returning 1
  ), s as (
    delete from public.conductor_sessions
    where expires_at < now() - interval '30 days' returning 1
  )
  select;
$$;
