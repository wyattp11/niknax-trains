-- ============================================================
-- Add a conductor to Belts, Buckles & Bags
-- ============================================================
-- One-off. After this, use the Conductors panel on the admin train page.
-- Requires migration 20260708100000_conductor_auth.

insert into public.train_conductors (train_id, email, email_key, username, is_primary)
select
  t.id,
  'maximalistmonica@gmail.com',
  'maximalistmonica@gmail.com',
  'maximalistmonica',
  true                                   -- first conductor on this train
from public.trains t
where t.name ilike '%belts%buckles%'
on conflict (train_id, email_key) do update
  set email    = excluded.email,
      username = excluded.username;

-- Confirm
select c.email, c.username, c.is_primary, t.name as train
from public.train_conductors c
join public.trains t on t.id = c.train_id
where t.name ilike '%belts%buckles%';
