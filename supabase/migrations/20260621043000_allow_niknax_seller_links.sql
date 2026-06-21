create or replace function public.set_slot_seller_link(slot_id uuid, link text)
returns public.slots
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_slot public.slots;
  clean_link text;
begin
  clean_link := nullif(trim(coalesce(link, '')), '');

  if clean_link is not null and clean_link !~* '^https://([a-z0-9-]+\.)*(districtapp\.tv|niknax\.net)([/?#]|$)' then
    raise exception 'Please enter a valid https:// District or Niknax link.' using errcode = '22023';
  end if;

  update public.slots s
  set seller_link = clean_link
  where s.id = slot_id
    and s.username is not null
    and exists (
      select 1
      from public.trains t
      where t.id = s.train_id
        and t.published = true
    )
  returning s.* into updated_slot;

  if updated_slot.id is null then
    raise exception 'Show links can only be added to claimed slots on published trains.' using errcode = 'P0001';
  end if;

  return updated_slot;
end;
$$;

grant execute on function public.set_slot_seller_link(uuid, text) to anon, authenticated;
