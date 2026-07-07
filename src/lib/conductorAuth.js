/**
 * Lightweight sessionStorage-based "conductor session."
 * When a member verifies their username as the conductor for a specific train,
 * we record it here. The session lasts until the browser tab is closed —
 * the same trust model as the existing slot signup flow.
 */

const key = (trainId) => `niknax_conductor_${trainId}`

export function getConductorSession(trainId) {
  try { return sessionStorage.getItem(key(trainId)) || null } catch { return null }
}

export function setConductorSession(trainId, username) {
  try { sessionStorage.setItem(key(trainId), username) } catch {}
}

export function clearConductorSession(trainId) {
  try { sessionStorage.removeItem(key(trainId)) } catch {}
}
