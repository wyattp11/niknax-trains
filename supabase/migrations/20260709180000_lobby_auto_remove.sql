-- ============================================================
-- Leaving the lobby automatically when you get a slot
-- ============================================================
--
-- Someone can land in a slot by several routes: an admin typing their name
-- inline, the add-slot form, a drag-and-drop move, a public claim, a
-- substitution, or a schedule rebuild. Only substitution cleared the lobby,
-- so anyone added another way stayed listed as waiting.
--
-- Handling that in each UI path would mean remembering it in every future one
-- too. A trigger on slots covers every route, including ones not written yet.
--
-- Deliberately one-directional: clearing a slot does NOT put someone back in
-- the lobby. Being removed from a schedule isn't the same as asking to wait.
-- ============================================================

create or replace function public.remove_from_lobby_on_slot_claim()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_train_id uuid;
begin
  -- Only when a name is actually present, and only when it changed.
  if new.username is null then
    return null;
  end if;

  if tg_op = 'UPDATE' and new.username is not distinct from old.username then
    return null;
  end if;

  select d.train_id into v_train_id
  from public.train_days d
  where d.id = new.train_day_id;

  if v_train_id is null then
    return null;
  end if;

  delete from public.train_lobby
  where train_id = v_train_id
    and username_key = lower(trim(regexp_replace(new.username, '^@+', '')));

  return null;
end;
$$;

drop trigger if exists remove_from_lobby_on_slot_claim on public.slots;
create trigger remove_from_lobby_on_slot_claim
  after insert or update of username on public.slots
  for each row execute function public.remove_from_lobby_on_slot_claim();


-- ── Clean up anyone already in both places ───────────────────────────────

delete from public.train_lobby l
where exists (
  select 1
  from public.slots s
  join public.train_days d on d.id = s.train_day_id
  where d.train_id = l.train_id
    and lower(s.username) = l.username_key
);


-- Report what was cleaned, and confirm none remain.
select
  t.name                    as train,
  l.username                as still_double_listed
from public.train_lobby l
join public.trains t on t.id = l.train_id
where exists (
  select 1 from public.slots s
  join public.train_days d on d.id = s.train_day_id
  where d.train_id = l.train_id and lower(s.username) = l.username_key
);
