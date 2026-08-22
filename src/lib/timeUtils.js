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
 * Live-selling trains routinely run past midnight — a 4:30 PM kickoff with 21
 * half-hour slots ends at 2:40 AM the NEXT calendar day. Slots store only a
 * clock time against a single day_date, so anything after midnight looks
 * (naively) like it happened in the small hours of the *start* date, i.e.
 * ~16 hours before the train began.
 *
 * Walk a day's slots in schedule order and roll the date forward every time
 * the clock goes backwards. Returns a Map of slot id → whole days to add.
 *
 * @param {Array} daySlots slots for one day, already sorted by slot_order
 */
export function slotDayOffsets(daySlots) {
  const offsets = new Map()
  let dayOffset = 0
  let prevMinutes = null

  for (const slot of daySlots || []) {
    const { hours, minutes } = parseTime(slot.start_time)
    const mins = hours * 60 + minutes
    if (prevMinutes !== null && mins < prevMinutes) dayOffset++
    offsets.set(slot.id, dayOffset)
    prevMinutes = mins
  }
  return offsets
}

/**
 * Real Date for a slot, accounting for past-midnight rollover.
 *
 * @param {object} day           the train_day (needs day_date "YYYY-MM-DD")
 * @param {object} slot          the slot (needs start_time)
 * @param {number} dayOffset     whole days to add, from slotDayOffsets()
 * @param {number} extraMinutes  added to the start — pass duration for an end time
 */
export function slotDateTime(day, slot, dayOffset = 0, extraMinutes = 0) {
  const [year, month, date] = String(day.day_date).split('-').map(Number)
  const { hours, minutes } = parseTime(slot.start_time)
  return new Date(year, month - 1, date + dayOffset, hours, minutes + extraMinutes)
}

/**
 * Calculate the end time string (HH:MM) after adding duration minutes.
 */
export function addMinutes(timeStr, durationMin) {
  const { hours, minutes } = parseTime(timeStr)
  const totalMin = hours * 60 + minutes + durationMin
  // Normalize into 0–1439 first so negative durationMin (e.g. shifting a
  // slot earlier when an earlier slot is deleted) wraps correctly instead
  // of producing negative hours/minutes.
  const wrapped = ((totalMin % 1440) + 1440) % 1440
  const h = Math.floor(wrapped / 60)
  const m = wrapped % 60
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

/**
 * Determine a train's rider-facing status badge.
 *
 * - Not published (draft or upcoming/announced)  → "pending"   "Arriving Soon"
 * - Published, every slot filled                  → "full"      "All Aboard!"
 * - Published, at least one open slot              → "boarding"  "Now Boarding"
 *
 * @param {{ published?: boolean }} train
 * @param {number} totalSlots   total slot count across all days
 * @param {number} filledSlots  slots with a non-null username
 */
export function trainStatus(train, totalSlots = 0, filledSlots = 0) {
  if (!train?.published) {
    return { key: 'pending', label: 'Arriving Soon' }
  }
  if (totalSlots > 0 && filledSlots >= totalSlots) {
    return { key: 'full', label: 'All Aboard!' }
  }
  return { key: 'boarding', label: 'Now Boarding' }
}

/** Maps a trainStatus() key to its .badge- (or .chip-) CSS class suffix. */
export const STATUS_BADGE_CLASS = {
  pending:  'upcoming',
  boarding: 'live',
  full:     'full',
  past:     'past',
}

/**
 * Today's date as a "YYYY-MM-DD" string, in local time (matches how
 * day_date values are stored/compared — no timezone math needed since
 * trains are always scheduled and viewed against US wall-clock dates).
 */
export function todayDateStr() {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

/**
 * A single "YYYY-MM-DD" date string is in the past (strictly before today).
 */
export function isPastDate(dateStr) {
  return !!dateStr && dateStr < todayDateStr()
}

/**
 * A train (given its list of day_date strings) has fully wrapped — every
 * scheduled day is in the past. Trains with no days yet (fresh drafts)
 * are never considered past.
 */
export function isPastTrain(dates) {
  if (!dates || !dates.length) return false
  const lastDate = [...dates].sort().at(-1)
  return isPastDate(lastDate)
}
