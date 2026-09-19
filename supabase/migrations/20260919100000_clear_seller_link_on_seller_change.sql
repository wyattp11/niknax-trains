-- ============================================================
-- A slot's seller_link must never outlive the seller who set it
-- ============================================================
--
-- `seller_link` is the "Watch on District" URL that a seller adds to their
-- own slot. It belongs to that one person. When the slot changes hands —
-- swapped, substituted, renamed by an admin, cleared, or reopened — the old
-- link has to go with them, or the public page sends viewers to the wrong
-- shop.
--
-- There are a lot of ways a slot changes hands: admin inline rename, admin
-- drag/tap move, reserved-slot toggle, conductor removal, lobby substitution,
-- public claim, and whatever gets added next. Fixing each call site is
-- whack-a-mole, so the rule lives here instead, where every path goes
-- through it.
--
-- The rule: if `username` changed and the same statement did NOT deliberately
-- set a `seller_link`, drop the link.
--
-- That exception matters. Moving a seller from one slot to another is
-- supposed to carry their link along, and it writes both columns together —
-- so `new.seller_link` differs from `old.seller_link` and the trigger leaves
-- it alone. A rename that only writes `username` leaves the link untouched,
-- which is exactly the case we want to catch.
--
-- Known limit: if two different sellers were swapped and both happened to hold
-- the *identical* link, the new value equals the old one and the trigger can't
-- tell that apart from "not written", so it clears the link. That needs two
-- sellers sharing one District URL, and the seller can just re-add it. Erring
-- toward a missing link over a wrong one is the whole point here — a wrong
-- link sends buyers to someone else's shop.


create or replace function public.clear_seller_link_on_seller_change()
returns trigger
language plpgsql
as $$
begin
  if new.username is distinct from old.username
     and new.seller_link is not distinct from old.seller_link
  then
    new.seller_link := null;
  end if;
  return new;
end;
$$;

comment on function public.clear_seller_link_on_seller_change() is
  'Drops a slot''s seller_link when the slot changes hands, unless the same '
  'statement set a link explicitly (which is how a seller move carries theirs).';

drop trigger if exists trg_clear_seller_link_on_seller_change on public.slots;

-- BEFORE, so the audit-log AFTER trigger records the final value rather than
-- a seller_link that no longer exists a moment later.
create trigger trg_clear_seller_link_on_seller_change
  before update of username on public.slots
  for each row
  execute function public.clear_seller_link_on_seller_change();


-- ── One-time cleanup ───────────────────────────────────────────────────────
-- An empty slot holding a link is unambiguous: whoever set it is gone.
update public.slots
set seller_link = null
where username is null
  and seller_link is not null;


-- Slots whose link *might* be stale can't be cleaned automatically — a
-- District URL doesn't always contain the handle, and guessing wrong would
-- delete a working link. `supabase/audit-stale-seller-links.sql` lists the
-- suspicious ones so they can be checked by eye.
