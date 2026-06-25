-- Add a per-train, admin-editable rules/criteria markdown field.
-- Shown to public sellers on the signup flow before they can claim a slot;
-- never required for admin-driven actions (manual username entry, train edits).

alter table public.trains add column if not exists rules_md text;
