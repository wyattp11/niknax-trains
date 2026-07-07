/**
 * send-notification — Supabase Edge Function
 *
 * Receives Supabase Database Webhook POST payloads and sends email via Resend.
 *
 * Handles two webhooks (configure both in Supabase Dashboard → Database → Webhooks):
 *   1. Table: slots     | Event: UPDATE  → checks if train is now full, emails if so
 *   2. Table: train_proposals | Event: INSERT → emails the proposal details immediately
 *
 * Required secrets (set in Supabase Dashboard → Settings → Edge Functions → Secrets,
 * or via `supabase secrets set KEY=value`):
 *   RESEND_API_KEY   — from resend.com dashboard
 *   NOTIFY_EMAIL     — the address that receives all notifications (e.g. wife@email.com)
 *   FROM_EMAIL       — optional sender, defaults to "Niknax Trains <onboarding@resend.dev>"
 *                      (free resend.dev sender only delivers to verified addresses;
 *                       add a verified domain in Resend for production)
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// ── Environment ────────────────────────────────────────────────────────────

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? ''
const NOTIFY_EMAIL   = Deno.env.get('NOTIFY_EMAIL') ?? ''
const FROM_EMAIL     = Deno.env.get('FROM_EMAIL') ?? 'Niknax Trains <onboarding@resend.dev>'
const SUPABASE_URL   = Deno.env.get('SUPABASE_URL') ?? ''
const SERVICE_KEY    = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

// ── Resend helper ──────────────────────────────────────────────────────────

async function sendEmail(subject: string, html: string) {
  if (!RESEND_API_KEY || !NOTIFY_EMAIL) {
    console.warn('send-notification: RESEND_API_KEY or NOTIFY_EMAIL not set — skipping email')
    return
  }
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${RESEND_API_KEY}`,
      'Content-Type':  'application/json',
    },
    body: JSON.stringify({
      from:    FROM_EMAIL,
      to:      NOTIFY_EMAIL,
      subject,
      html,
    }),
  })
  if (!res.ok) {
    const body = await res.text()
    throw new Error(`Resend error ${res.status}: ${body}`)
  }
}

// ── Train-full handler ─────────────────────────────────────────────────────

async function handleSlotUpdate(record: Record<string, unknown>, oldRecord: Record<string, unknown>) {
  // Only act when a username was just claimed (null → non-null)
  if (oldRecord.username || !record.username) return

  const supabase = createClient(SUPABASE_URL, SERVICE_KEY)

  // Resolve train from train_day_id
  const { data: dayData } = await supabase
    .from('train_days')
    .select('train_id, trains(id, name)')
    .eq('id', record.train_day_id)
    .single()

  if (!dayData) return
  const trainId   = dayData.train_id
  const trainName = (dayData.trains as Record<string, string>)?.name ?? 'Unknown Train'

  // Count all slots across all days of this train
  const { data: daySlots } = await supabase
    .from('train_days')
    .select('slots(id, username)')
    .eq('train_id', trainId)

  const allSlots = (daySlots ?? []).flatMap((d: Record<string, unknown>) => (d.slots as unknown[]) ?? []) as { username: string | null }[]
  const total  = allSlots.length
  const filled = allSlots.filter(s => s.username).length

  if (total === 0 || filled < total) return  // not full yet

  const adminUrl = `${Deno.env.get('PUBLIC_SITE_URL') ?? ''}/admin/trains/${trainId}`

  await sendEmail(
    `🎉 ${trainName} is FULL!`,
    `
    <div style="font-family:sans-serif;max-width:520px;margin:0 auto">
      <h2 style="color:#7c3aed">🚂 Train Full!</h2>
      <p><strong>${trainName}</strong> just had its last slot claimed.</p>
      <p>All <strong>${total} slots</strong> are now filled.</p>
      ${adminUrl ? `<p><a href="${adminUrl}" style="color:#7c3aed">View in admin →</a></p>` : ''}
    </div>
    `,
  )
  console.log(`send-notification: sent "train full" email for ${trainName} (${trainId})`)
}

// ── Proposal handler ───────────────────────────────────────────────────────

async function handleProposalInsert(record: Record<string, unknown>) {
  const { name, tagline, proposed_date, contact_username, message, id } = record
  const adminUrl = `${Deno.env.get('PUBLIC_SITE_URL') ?? ''}/admin/dashboard`

  await sendEmail(
    `📋 New Train Proposal: ${name}`,
    `
    <div style="font-family:sans-serif;max-width:520px;margin:0 auto">
      <h2 style="color:#7c3aed">📋 New Train Proposal</h2>
      <table style="border-collapse:collapse;width:100%">
        <tr><td style="padding:6px 0;color:#666;width:140px">Event Name</td><td style="padding:6px 0"><strong>${name}</strong></td></tr>
        <tr><td style="padding:6px 0;color:#666">Tagline</td><td style="padding:6px 0">${tagline || '—'}</td></tr>
        <tr><td style="padding:6px 0;color:#666">Proposed Date</td><td style="padding:6px 0">${proposed_date || '—'}</td></tr>
        <tr><td style="padding:6px 0;color:#666">Contact</td><td style="padding:6px 0">@${contact_username}</td></tr>
        <tr><td style="padding:6px 0;color:#666;vertical-align:top">Message</td><td style="padding:6px 0">${message ? message.replace(/\n/g, '<br>') : '—'}</td></tr>
      </table>
      ${adminUrl ? `<p style="margin-top:20px"><a href="${adminUrl}" style="color:#7c3aed">Review in admin →</a></p>` : ''}
    </div>
    `,
  )
  console.log(`send-notification: sent proposal email for "${name}" (id: ${id})`)
}

// ── Main handler ───────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 })
    }

    const payload = await req.json()
    const { type, table, record, old_record } = payload

    if (table === 'slots' && type === 'UPDATE') {
      await handleSlotUpdate(record, old_record ?? {})
    }

    if (table === 'train_proposals' && type === 'INSERT') {
      await handleProposalInsert(record)
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err)
    console.error('send-notification error:', message)
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
