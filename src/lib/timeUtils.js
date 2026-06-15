/**
 * All times are stored in the DB as Eastern Time (ET).
 * These utilities handle display across US time zones.
 */

export const TZ_OFFSETS = [
  { label: 'ET', offset: 0 },
  { label: 'CT', offset: -1 },
  { label: 'MT', offset: -2 },
  { label: 'PT', offset: -3 },
]

/**
 * Parse "HH:MM:SS" or "HH:MM" time string → { hours, minutes }
 */
export function parseTime(timeStr) {
  const [h, m] = timeStr.split(':').map(Number)
  return { hours: h, minutes: m }
}

/**
 * Format hours + minutes as "H:MM AM/PM"
 */
export function formatHHMM(hours, minutes) {
  const h = ((hours % 24) + 24) % 24
  const ampm = h < 12 ? 'AM' : 'PM'
  const displayH = h === 0 ? 12 : h > 12 ? h - 12 : h
  return `${displayH}:${String(minutes).padStart(2, '0')} ${ampm}`
}

/**
 * Given an ET time string, return formatted times for all 4 US zones.
 */
export function allZones(etTimeStr) {
  const { hours, minutes } = parseTime(etTimeStr)
  return TZ_OFFSETS.map(({ label, offset }) => ({
    label,
    time: formatHHMM(hours + offset, minutes),
  }))
}

/**
 * Calculate the end time string (HH:MM) after adding duration minutes.
 */
export function addMinutes(timeStr, durationMin) {
  const { hours, minutes } = parseTime(timeStr)
  const totalMin = hours * 60 + minutes + durationMin
  const h = Math.floor(totalMin / 60) % 24
  const m = totalMin % 60
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`
}

/**
 * Generate an array of time strings (HH:MM) spaced by intervalMin,
 * starting at startTime, for count slots.
 */
export function generateSlotTimes(startTime, intervalMin, count) {
  const times = []
  let current = startTime
  for (let i = 0; i < count; i++) {
    times.push(current)
    current = addMinutes(current, intervalMin)
  }
  return times
}

/**
 * Format a date string (YYYY-MM-DD) as "Saturday, June 28"
 */
export function formatDate(dateStr) {
  // Parse as local to avoid UTC offset shifting the date
  const [y, m, d] = dateStr.split('-').map(Number)
  const date = new Date(y, m - 1, d)
  return date.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })
}
