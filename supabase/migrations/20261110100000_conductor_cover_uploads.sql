-- ============================================================
-- Conductors can upload their train's graphic
-- ============================================================
--
-- Storage only allowed admins to upload to train-graphics, so a conductor
-- choosing a graphic got an error. Conductors aren't Supabase-authenticated
-- (they use their own session token), so the storage policy can't check them
-- directly.
--
-- Instead, a conductor asks for an upload slot. After checking their token,
-- conductor_cover_upload_slot() reserves two file names for their own train:
--   <train_id>/cover-<random digits>.jpg        (+ the -thumb.jpg twin)
-- valid for 10 minutes. The storage policy lets anyone upload ONLY to a name
-- that's currently reserved. The names are random, so nobody else can guess
-- one, and existing files can't be overwritten.
-- ============================================================

create table if not exists public.cover_upload_grants (
  object_name text primary key,          -- full path inside the bucket
  train_id    uuid not null references public.trains(id) on delete cascade,
  expires_at  timestamptz not null,
  created_at  timestamptz not null default now()
);

alter table public.cover_upload_grants enable row level security;
revoke all on public.cover_upload_grants from anon, authenticated;


-- Checked by the storage policy.
create or replace function public.cover_upload_allowed(p_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.cover_upload_grants
    where object_name = p_name and expires_at > now()
  );
$$;

grant execute on function public.cover_upload_allowed(text) to anon, authenticated;


create or replace function public.conductor_cover_upload_slot(
  p_train_id uuid,
  p_token    text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_base text;
begin
  perform public.require_conductor(p_train_id, p_token);

  if not exists (select 1 from public.trains where id = p_train_id and is_member_train) then
    raise exception 'Train not found.' using errcode = 'P0001';
  end if;

  -- Tidy up old reservations while we're here.
  delete from public.cover_upload_grants where expires_at < now() - interval '1 day';

  -- Timestamp plus 8 random digits: unguessable, and still matches the
  -- cover-<digits>.jpg pattern the site uses to find the thumbnail.
  v_base := p_train_id::text || '/cover-'
         || (extract(epoch from clock_timestamp()) * 1000)::bigint::text
         || lpad((floor(random() * 100000000))::bigint::text, 8, '0');

  insert into public.cover_upload_grants (object_name, train_id, expires_at)
  values
    (v_base || '.jpg',       p_train_id, now() + interval '10 minutes'),
    (v_base || '-thumb.jpg', p_train_id, now() + interval '10 minutes');

  return jsonb_build_object('base', v_base);
end;
$$;

grant execute on function public.conductor_cover_upload_slot(uuid, text) to anon, authenticated;


-- Anyone may upload to a reserved name — and only to a reserved name.
drop policy if exists "reserved cover uploads" on storage.objects;
create policy "reserved cover uploads"
on storage.objects
for insert
to anon, authenticated
with check (
  bucket_id = 'train-graphics'
  and public.cover_upload_allowed(name)
);
