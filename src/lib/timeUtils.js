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
  const list = daySlots || []
  if (!list.length) return offsets

  // Anchor on the day's first slot rather than accumulating step by step.
  //
  // The step-by-step version incremented the offset every time the clock went
  // backwards, so a single out-of-order row shifted every slot after it onto
  // the wrong date — one stale kickoff was enough to relabel a whole day.
  // Anchoring caps the damage at one rollover and keeps a bad row local to
  // itself. A show night is always under 24 hours, so one is the true maximum.
  const { hours: baseH, minutes: baseM } = parseTime(list[0].start_time)
  const baseMinutes = baseH * 60 + baseM

  for (const slot of list) {
    const { hours, minutes } = parseTime(slot.start_time)
    const mins = hours * 60 + minutes
    offsets.set(slot.id, mins < baseMinutes ? 1 : 0)
  }
  return offsets
}

/**
 * Group a day's slots by the calendar date they actually fall on.
 *
 * A train day stores one date plus bare clock times, so an overnight event
 * keeps its 12:10 AM slots under the start date. Rendering those inside the
 * start date's container reads as a mistake. This splits them, so each
 * container holds exactly one calendar day.
 *
 * @returns {Array<{date: Date, dateKey: string, offset: number, slots: Array}>}
 */
export function groupSlotsByCalendarDay(day, daySlots) {
  const list = daySlots || []
  if (!list.length) return []

  const offsets = slotDayOffsets(list)
  const groups = new Map()

  for (const slot of list) {
    const offset = offsets.get(slot.id) || 0
    if (!groups.has(offset)) {
      const [y, m, d] = String(day.day_date).split('-').map(Number)
      groups.set(offset, {
        offset,
        date: new Date(y, m - 1, d + offset),
        slots: [],
      })
    }
    groups.get(offset).slots.push(slot)
  }

  return [...groups.values()]
    .sort((a, b) => a.offset - b.offset)
    .map(g => ({
      ...g,
      dateKey: `${g.date.getFullYear()}-${String(g.date.getMonth() + 1).padStart(2, '0')}-${String(g.date.getDate()).padStart(2, '0')}`,
    }))
}

/** Gap between consecutive slots beyond this is treated as a broken schedule. */
const MAX_PLAUSIBLE_GAP_MIN = 240   // 4 hours

/**
 * True when a day's schedule looks broken — worth warning an admin about.
 *
 * Checking only for "times go backwards" isn't enough: once rollover is
 * anchored, a stale row simply lands on the next day and the sequence still
 * reads as ascending. The reliable signal is an implausible jump. A kickoff
 * left at 4:30 PM while its sellers moved to 11:40 AM shows up as a 19-hour
 * gap, which no real schedule has.
 *
 * Overlaps count too — a slot starting before the previous one has finished.
 */
export function hasOutOfOrderSlots(daySlots) {
  const list = daySlots || []
  if (list.length < 2) return false

  const offsets = slotDayOffsets(list)
  const abs = (slot) => {
    const { hours, minutes } = parseTime(slot.start_time)
    return (offsets.get(slot.id) || 0) * 1440 + hours * 60 + minutes
  }

  for (let i = 1; i < list.length; i++) {
    const prevStart = abs(list[i - 1])
    const prevEnd   = prevStart + (list[i - 1].duration_min || 30)
    const thisStart = abs(list[i])

    if (thisStart < prevStart) return true                        // out of order
    if (thisStart < prevEnd) return true                          // overlap
    if (thisStart - prevEnd > MAX_PLAUSIBLE_GAP_MIN) return true  // stranded row
  }
  return false
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
 * Absolute minutes within a show night, anchored to the day's first slot.
 * A bare clock time is ambiguous on a train that runs past midnight — anything
 * earlier than the anchor belongs to the next morning. Mirrors
 * public.slot_abs_minutes() in the SQL migrations.
 */
export function absMinutes(timeStr, baseMinutes = 0) {
  const { hours, minutes } = parseTime(timeStr)
  const mins = hours * 60 + minutes
  return mins < baseMinutes ? mins + 1440 : mins
}

/**
 * Where a new slot belongs in a day, and how the existing slots renumber
 * around it. Slot order is derived from the clock so the two can never
 * disagree — appending blindly is what made schedules read as scrambled.
 *
 * @returns {{ order:number, shifted:Array<{id:string, slot_order:number}> }}
 */
export function slotInsertPosition(daySlots, newStartTime) {
  const existing = [...(daySlots || [])].sort((a, b) => a.slot_order - b.slot_order)
  if (!existing.length) return { order: 0, shifted: [] }

  const base = absMinutes(existing[0].start_time, 0)
  const newAbs = absMinutes(newStartTime, base)

  const order = existing.filter(s => absMinutes(s.start_time, base) < newAbs).length
  const shifted = existing
    .filter(s => absMinutes(s.start_time, base) >= newAbs)
    .map(s => ({ id: s.id, slot_order: s.slot_order + 1 }))

  return { order, shifted }
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
