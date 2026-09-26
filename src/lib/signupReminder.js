// Helpers for a train's "sign-ups open" moment: countdown text, the time in
// the three zones the site shows, and a calendar reminder.
//
// `signups_open_at` is a real timestamp (timestamptz), unlike slot times which
// are bare clock times — so everything here works in UTC and lets Intl handle
// the zones.

const ZONES = [
  { tz: 'America/New_York',    label: 'ET' },
  { tz: 'America/Chicago',     label: 'CT' },
  { tz: 'America/Los_Angeles', label: 'PT' },
]

const REMINDER_MINUTES = 15   // length of the calendar event
const ALERT_MINUTES    = 10   // phone alert this long before sign-ups open

export function parseOpenAt(value) {
  if (!value) return null
  const d = value instanceof Date ? value : new Date(value)
  return Number.isNaN(d.getTime()) ? null : d
}

/**
 * "in 2d 4h", "in 3h 12m", "in 45m", "in under a minute", or null once passed.
 */
export function countdownText(openAt, now = new Date()) {
  const at = parseOpenAt(openAt)
  if (!at) return null
  const ms = at.getTime() - now.getTime()
  if (ms <= 0) return null

  const totalMin = Math.floor(ms / 60000)
  if (totalMin < 1) return 'in under a minute'
  const days  = Math.floor(totalMin / 1440)
  const hours = Math.floor((totalMin % 1440) / 60)
  const mins  = totalMin % 60

  if (days > 0)  return hours ? `in ${days}d ${hours}h` : `in ${days}d`
  if (hours > 0) return mins ? `in ${hours}h ${mins}m` : `in ${hours}h`
  return `in ${mins}m`
}

/** "Fri, Oct 3" in Eastern — the date the site's schedule is keyed to. */
export function openDateLabel(openAt) {
  const at = parseOpenAt(openAt)
  if (!at) return ''
  return at.toLocaleDateString('en-US', {
    weekday: 'short', month: 'short', day: 'numeric', timeZone: 'America/New_York',
  })
}

/** "7:00 PM ET · 6:00 PM CT · 4:00 PM PT" */
export function openTimeZonesLabel(openAt) {
  const at = parseOpenAt(openAt)
  if (!at) return ''
  return ZONES.map(({ tz, label }) =>
    `${at.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', timeZone: tz })} ${label}`
  ).join(' · ')
}

function utcStamp(date) {
  return date.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '')
}

function escapeIcsText(value) {
  return String(value)
    .replace(/\\/g, '\\\\')
    .replace(/;/g, '\\;')
    .replace(/,/g, '\\,')
    .replace(/\r?\n/g, '\\n')
}

function reminderTitle(train) {
  return `Sign-ups open: ${train?.name || 'Niknax Train'}`
}

function reminderDetails(train, pageUrl) {
  return [
    `Sign-ups for ${train?.name || 'this Niknax train'} open now. Grab your slot:`,
    pageUrl,
  ].join('\n')
}

export function googleReminderUrl(train, pageUrl) {
  const at = parseOpenAt(train?.signups_open_at)
  if (!at) return null
  const end = new Date(at.getTime() + REMINDER_MINUTES * 60000)
  const params = new URLSearchParams({
    action: 'TEMPLATE',
    text: reminderTitle(train),
    dates: `${utcStamp(at)}/${utcStamp(end)}`,
    details: reminderDetails(train, pageUrl),
    location: pageUrl,
  })
  return `https://calendar.google.com/calendar/render?${params.toString()}`
}

export function reminderIcs(train, pageUrl, now = new Date()) {
  const at = parseOpenAt(train?.signups_open_at)
  if (!at) return null
  const end = new Date(at.getTime() + REMINDER_MINUTES * 60000)
  return [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Niknax//Train Station//EN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'BEGIN:VEVENT',
    `UID:signups-${train.id}@niknax-trains`,
    `DTSTAMP:${utcStamp(now)}`,
    `DTSTART:${utcStamp(at)}`,
    `DTEND:${utcStamp(end)}`,
    `SUMMARY:${escapeIcsText(reminderTitle(train))}`,
    `DESCRIPTION:${escapeIcsText(reminderDetails(train, pageUrl))}`,
    `LOCATION:${escapeIcsText(pageUrl)}`,
    `URL:${pageUrl}`,
    'BEGIN:VALARM',
    'ACTION:DISPLAY',
    `DESCRIPTION:${escapeIcsText(reminderTitle(train))}`,
    `TRIGGER:-PT${ALERT_MINUTES}M`,
    'END:VALARM',
    'END:VEVENT',
    'END:VCALENDAR',
  ].join('\r\n') + '\r\n'
}

export function downloadReminderIcs(train, pageUrl) {
  const content = reminderIcs(train, pageUrl)
  if (!content) return
  const slug = String(train?.name || 'niknax-train')
    .replace(/[^a-z0-9]+/gi, '-').replace(/^-|-$/g, '').toLowerCase() || 'niknax-train'
  const blob = new Blob([content], { type: 'text/calendar;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = Object.assign(document.createElement('a'), { href: url, download: `${slug}-signups.ics` })
  a.click()
  URL.revokeObjectURL(url)
}

// ── datetime-local <-> timestamptz, for the admin/conductor forms ──────────
// The input works in the editor's own local time; the stored value is absolute.

export function toLocalInputValue(value) {
  const at = parseOpenAt(value)
  if (!at) return ''
  const pad = (n) => String(n).padStart(2, '0')
  return `${at.getFullYear()}-${pad(at.getMonth() + 1)}-${pad(at.getDate())}` +
         `T${pad(at.getHours())}:${pad(at.getMinutes())}`
}

export function fromLocalInputValue(value) {
  if (!value) return null
  const at = new Date(value)          // parsed as local time
  return Number.isNaN(at.getTime()) ? null : at.toISOString()
}
