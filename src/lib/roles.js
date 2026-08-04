/**
 * Staff role matching — must stay in sync with public.is_staff_role() in
 * supabase/migrations/20260707160000_flexible_staff_roles.sql
 *
 * Role badges arrive from the members CSV and aren't consistently spelled:
 * "NN Moderator" and "MODERATOR" are the same job. Rather than maintaining an
 * exact-match list that silently breaks on the next spelling, we normalize the
 * badge and look for owner / admin / moderator as a whole word.
 *
 * Qualifying: "NN Moderator", "MODERATOR", "nn_moderator", "Mod",
 *             "NN Owner", "OWNER", "NN Admin", "Administrator"
 */

const STAFF_PATTERN = /(^| )(owner|admin|administrator|moderator|mod)( |$)/

/** Normalize a badge: lowercase, punctuation and underscores become spaces. */
function normalize(role) {
  return String(role || '').toLowerCase().replace(/[^a-z]+/g, ' ').trim()
}

/** True when this role grants staff privileges (reserved slots, kickoff, etc.). */
export function isStaffRole(role) {
  return STAFF_PATTERN.test(normalize(role))
}

/**
 * Which tier of staff a badge represents, or null. Owner outranks admin,
 * which outranks moderator — so "NN Owner / Admin" reads as owner.
 */
export function staffTier(role) {
  const n = normalize(role)
  if (!n) return null
  if (/(^| )owner( |$)/.test(n)) return 'owner'
  if (/(^| )(admin|administrator)( |$)/.test(n)) return 'admin'
  if (/(^| )(moderator|mod)( |$)/.test(n)) return 'moderator'
  return null
}
