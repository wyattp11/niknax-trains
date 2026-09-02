/**
 * Conductor session storage.
 *
 * Previously this held a username the visitor simply typed, which verified
 * nothing. It now holds a session token issued by verify_conductor_code()
 * after the conductor proves control of a registered email address.
 *
 * localStorage rather than sessionStorage: trains get planned months ahead,
 * and sessions last 90 days, so closing the tab shouldn't sign anyone out.
 */

const key = (trainId) => `niknax_conductor_${trainId}`

/** @returns {{token:string, email:string, username:string|null, expiresAt:string}|null} */
export function getConductorSession(trainId) {
  if (!trainId) return null
  try {
    const raw = localStorage.getItem(key(trainId))
    if (!raw) return null

    const session = JSON.parse(raw)
    if (!session?.token) return null

    // Drop it locally once expired; the server would reject it anyway.
    if (session.expiresAt && new Date(session.expiresAt) <= new Date()) {
      clearConductorSession(trainId)
      return null
    }
    return session
  } catch {
    return null
  }
}

export function setConductorSession(trainId, session) {
  if (!trainId || !session?.token) return
  try {
    localStorage.setItem(key(trainId), JSON.stringify({
      token:     session.token,
      email:     session.email || '',
      username:  session.username || null,
      expiresAt: session.expiresAt || session.expires_at || null,
    }))
  } catch {
    // Private browsing — the session just won't persist.
  }
}

export function clearConductorSession(trainId) {
  try {
    localStorage.removeItem(key(trainId))
  } catch {
    // no-op
  }
}

/** Convenience for RPC calls that take a token. */
export function getConductorToken(trainId) {
  return getConductorSession(trainId)?.token || ''
}
