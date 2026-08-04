<template>
  <div class="min-h-screen bg-base">
    <AdminNav />

    <main class="max-w-4xl mx-auto px-6 py-10 space-y-8">

      <div>
        <h1 class="text-2xl font-display font-bold text-tx1">Seller Strikes</h1>
        <p class="text-sm text-tx3 mt-1">
          An active strike keeps a seller out of the next Niknax-sponsored train they try to join.
          Member-created trains are never affected, and NN owners, admins, and moderators are exempt.
        </p>
      </div>

      <!-- ── Add a strike ────────────────────────────────────────────────── -->
      <section class="card space-y-4">
        <h2 class="font-semibold text-niknax-600 dark:text-niknax-300">Flag a Seller</h2>

        <!-- Member search -->
        <div class="relative">
          <label class="label" for="strike-member">Member</label>
          <input
            id="strike-member"
            v-model="memberQuery"
            class="input"
            placeholder="Start typing a username…"
            autocomplete="off"
            role="combobox"
            :aria-expanded="showSuggestions"
            aria-controls="member-suggestions"
            @input="onMemberInput"
            @focus="onMemberInput"
            @keydown.down.prevent="moveSuggestion(1)"
            @keydown.up.prevent="moveSuggestion(-1)"
            @keydown.enter.prevent="acceptSuggestion()"
            @keydown.escape="showSuggestions = false"
          />
          <ul
            v-if="showSuggestions && suggestions.length"
            id="member-suggestions"
            role="listbox"
            class="absolute z-20 left-0 right-0 mt-1 bg-surface border border-bd rounded-lg shadow-lg max-h-52 overflow-y-auto"
          >
            <li
              v-for="(s, i) in suggestions"
              :key="s.id"
              role="option"
              :aria-selected="i === activeSuggestion"
              class="px-3 py-2 text-sm cursor-pointer flex items-center justify-between gap-2"
              :class="i === activeSuggestion ? 'bg-niknax-600 text-white' : 'text-tx1 hover:bg-sur2'"
              @mousedown.prevent="acceptSuggestion(s)"
            >
              <span>@{{ s.username }}</span>
              <span
                v-if="s.role"
                class="text-xs shrink-0"
                :class="i === activeSuggestion ? 'text-white/70' : 'text-tx3'"
              >{{ s.role }}</span>
            </li>
          </ul>
        </div>

        <p v-if="selectedIsStaff" class="text-xs text-amber-700 dark:text-amber-400 bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-900/50 rounded-lg px-3 py-2">
          Heads up — @{{ selectedMember.username }} is <strong>{{ selectedMember.role }}</strong>.
          Staff are exempt from the sign-up gate, so this strike will be recorded for your
          reference but won't block them from any train.
        </p>

        <div class="grid sm:grid-cols-2 gap-4">
          <div>
            <label class="label" for="strike-reason">Reason</label>
            <select id="strike-reason" v-model="form.reason" class="input">
              <option value="no_show">No-show</option>
              <option value="late">Showed up late</option>
              <option value="left_early">Left slot early</option>
              <option value="rule_violation">Rule violation</option>
              <option value="other">Other</option>
            </select>
          </div>
          <div>
            <label class="label" for="strike-train">Related event (optional)</label>
            <select id="strike-train" v-model="form.train_id" class="input">
              <option :value="null">— none —</option>
              <option v-for="t in trains" :key="t.id" :value="t.id">{{ t.name }}</option>
            </select>
          </div>
        </div>

        <div>
          <label class="label" for="strike-notes">Notes (admin only)</label>
          <textarea id="strike-notes" v-model="form.notes" class="input" rows="2" placeholder="Optional context — never shown to the seller." />
        </div>

        <p v-if="addError" class="text-red-600 dark:text-red-400 text-sm" role="alert">{{ addError }}</p>

        <div class="flex items-center justify-end gap-3">
          <span v-if="addedMsg" class="text-sm text-green-700 dark:text-green-400" aria-live="polite">{{ addedMsg }}</span>
          <button
            @click="addStrike"
            :disabled="adding || !selectedMember"
            class="btn-primary !bg-red-600 hover:!bg-red-500 disabled:opacity-50"
          >{{ adding ? 'Saving…' : 'Log Strike' }}</button>
        </div>
      </section>

      <!-- ── Currently blocked ───────────────────────────────────────────── -->
      <section>
        <div class="flex items-center gap-4 mb-4">
          <h2 class="font-display text-2xl text-tx1 shrink-0">
            Currently Blocked
            <span v-if="!loading" class="text-base font-sans text-tx3">({{ standing.length }})</span>
          </h2>
          <div class="flex-1 h-[3px] bg-niknax-600 rounded-full"></div>
        </div>

        <p v-if="loading" class="text-tx3 text-sm">Loading…</p>

        <div v-else-if="standing.length === 0" class="card text-center py-10">
          <p class="text-tx3">Nobody is blocked right now. 🎉</p>
        </div>

        <div v-else class="space-y-3">
          <div v-for="s in standing" :key="s.username_key" class="card">
            <div class="flex items-start justify-between gap-4 flex-wrap">
              <div class="min-w-0">
                <p class="font-semibold text-tx1">
                  @{{ s.username }}
                  <span class="ml-1 text-xs font-semibold px-2 py-0.5 rounded-full bg-red-100 dark:bg-red-900/40 text-red-700 dark:text-red-300">
                    ⚑ {{ s.active_strikes }} active
                  </span>
                </p>
                <p class="text-xs text-tx3 mt-0.5">Last flagged {{ formatDate(s.last_strike_at) }}</p>
              </div>
              <button
                @click="clearAllFor(s)"
                :disabled="clearingKey === s.username_key"
                class="btn-secondary text-sm py-1.5 shrink-0 disabled:opacity-50"
              >{{ clearingKey === s.username_key ? '…' : 'Clear all' }}</button>
            </div>

            <div class="mt-3 space-y-2">
              <div
                v-for="st in activeStrikesFor(s.username_key)"
                :key="st.id"
                class="border border-red-200 dark:border-red-900/50 bg-red-50 dark:bg-red-900/20 rounded-lg px-3 py-2"
              >
                <div class="flex items-start justify-between gap-3">
                  <div class="min-w-0">
                    <p class="text-sm font-medium text-red-800 dark:text-red-200">
                      {{ reasonLabel(st.reason) }}
                      <span class="font-normal text-xs text-tx3">· {{ formatDate(st.created_at) }}</span>
                    </p>
                    <p v-if="trainName(st.train_id)" class="text-xs text-tx3">From: {{ trainName(st.train_id) }}</p>
                    <p v-if="st.notes" class="text-xs text-red-700 dark:text-red-300 mt-0.5">{{ st.notes }}</p>
                    <p class="text-xs text-tx3 mt-0.5">{{ statusText(st) }}</p>
                  </div>
                  <button
                    @click="clearStrike(st)"
                    :disabled="clearingId === st.id"
                    class="text-xs font-medium text-niknax-600 hover:text-niknax-500 dark:text-niknax-400 dark:hover:text-niknax-300 shrink-0 disabled:opacity-50"
                  >{{ clearingId === st.id ? '…' : 'Clear' }}</button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- ── History ─────────────────────────────────────────────────────── -->
      <section v-if="resolvedStrikes.length">
        <button
          @click="showHistory = !showHistory"
          class="flex items-center gap-4 w-full mb-4 text-left"
          :aria-expanded="showHistory"
        >
          <h2 class="font-display text-2xl text-tx3 shrink-0">
            History <span class="text-base font-sans">({{ resolvedStrikes.length }})</span>
          </h2>
          <div class="flex-1 h-[3px] bg-bd rounded-full"></div>
          <span class="text-tx3 text-lg shrink-0">{{ showHistory ? '▲' : '▼' }}</span>
        </button>

        <div v-show="showHistory" class="space-y-2">
          <div
            v-for="st in resolvedStrikes"
            :key="st.id"
            class="card py-3 flex items-start justify-between gap-3"
          >
            <div class="min-w-0">
              <p class="text-sm text-tx1">
                <span class="font-semibold">@{{ st.username }}</span>
                <span class="text-tx3"> · </span>{{ reasonLabel(st.reason) }}
                <span class="text-xs text-tx3"> · {{ formatDate(st.created_at) }}</span>
              </p>
              <p v-if="trainName(st.train_id)" class="text-xs text-tx3">From: {{ trainName(st.train_id) }}</p>
              <p v-if="st.notes" class="text-xs text-tx3 mt-0.5">{{ st.notes }}</p>
              <p class="text-xs text-tx3 mt-0.5">{{ statusText(st) }}</p>
            </div>
          </div>
        </div>
      </section>
    </main>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import AdminNav from '../../components/AdminNav.vue'
import { supabase } from '../../lib/supabase.js'
import { formatDate } from '../../lib/timeUtils.js'

const REASON_LABELS = {
  no_show:        'No-show',
  late:           'Late',
  left_early:     'Left early',
  rule_violation: 'Rule violation',
  other:          'Other',
}
const STAFF_ROLES = ['nn owner', 'nn admin', 'nn moderator']

function reasonLabel(r) { return REASON_LABELS[r] || 'Flagged' }

const loading      = ref(true)
const strikes      = ref([])
const standing     = ref([])
const trains       = ref([])
const trainLastDay = ref({})     // train_id -> ISO date of final day
const showHistory  = ref(false)
const clearingId   = ref(null)
const clearingKey  = ref(null)

// ── Add form ──────────────────────────────────────────────────────────────
const memberQuery      = ref('')
const suggestions      = ref([])
const showSuggestions  = ref(false)
const activeSuggestion = ref(0)
const selectedMember   = ref(null)
const adding           = ref(false)
const addError         = ref('')
const addedMsg         = ref('')
const form = ref({ reason: 'no_show', notes: '', train_id: null })

const selectedIsStaff = computed(() =>
  !!selectedMember.value?.role &&
  STAFF_ROLES.includes(String(selectedMember.value.role).toLowerCase())
)

let searchTimer = null
function onMemberInput() {
  selectedMember.value = null
  const q = memberQuery.value.trim().replace(/^@/, '')
  clearTimeout(searchTimer)
  if (!q) {
    suggestions.value = []
    showSuggestions.value = false
    return
  }
  searchTimer = setTimeout(async () => {
    const { data } = await supabase
      .from('members')
      .select('id, username, role')
      .ilike('username', `%${q}%`)
      .order('username')
      .limit(8)
    suggestions.value      = data || []
    activeSuggestion.value = 0
    showSuggestions.value  = true
  }, 180)
}

function moveSuggestion(delta) {
  if (!suggestions.value.length) return
  const n = suggestions.value.length
  activeSuggestion.value = (activeSuggestion.value + delta + n) % n
}

function acceptSuggestion(s) {
  const pick = s || suggestions.value[activeSuggestion.value]
  if (!pick) return
  selectedMember.value  = pick
  memberQuery.value     = pick.username
  showSuggestions.value = false
}

async function addStrike() {
  if (!selectedMember.value) return
  addError.value = ''
  addedMsg.value = ''
  adding.value   = true

  const { data: userData } = await supabase.auth.getUser()
  const username = selectedMember.value.username

  const { error } = await supabase.from('member_strikes').insert({
    username,
    username_key: username.toLowerCase(),
    train_id:     form.value.train_id,
    reason:       form.value.reason,
    notes:        form.value.notes.trim() || null,
    created_by:   userData?.user?.id || null,
  })

  if (error) {
    addError.value = error.message || 'Could not log the strike.'
  } else {
    addedMsg.value       = `Strike logged for @${username}.`
    memberQuery.value    = ''
    selectedMember.value = null
    form.value           = { reason: 'no_show', notes: '', train_id: null }
    await loadAll()
    setTimeout(() => { addedMsg.value = '' }, 4000)
  }
  adding.value = false
}

// ── Data ──────────────────────────────────────────────────────────────────
function trainName(id) {
  if (!id) return ''
  return trains.value.find(t => t.id === id)?.name || ''
}

function trainFinished(id) {
  const last = trainLastDay.value[id]
  if (!last) return false
  return new Date(last) < new Date(new Date().toDateString())
}

/** True when a strike still counts against the seller. */
function isActive(st) {
  if (st.cleared_at) return false
  if (!st.penalty_train_id) return true
  return !trainFinished(st.penalty_train_id)
}

function statusText(st) {
  if (st.cleared_at) return `Cleared ${formatDate(st.cleared_at)}`
  if (!st.penalty_train_id) return 'Waiting to be served on their next Niknax train attempt.'
  const name = trainName(st.penalty_train_id) || 'an event'
  return trainFinished(st.penalty_train_id)
    ? `Served — they sat out ${name}.`
    : `Sitting out ${name}.`
}

function activeStrikesFor(key) {
  return strikes.value.filter(s => s.username_key === key && isActive(s))
}

const resolvedStrikes = computed(() => strikes.value.filter(s => !isActive(s)))

async function clearStrike(strike) {
  clearingId.value = strike.id
  const { error } = await supabase
    .from('member_strikes')
    .update({ cleared_at: new Date().toISOString() })
    .eq('id', strike.id)
  if (!error) await loadAll()
  clearingId.value = null
}

async function clearAllFor(s) {
  clearingKey.value = s.username_key
  const ids = activeStrikesFor(s.username_key).map(x => x.id)
  if (ids.length) {
    const { error } = await supabase
      .from('member_strikes')
      .update({ cleared_at: new Date().toISOString() })
      .in('id', ids)
    if (!error) await loadAll()
  }
  clearingKey.value = null
}

async function loadAll() {
  const [strikeRes, standingRes, trainRes, dayRes] = await Promise.all([
    supabase.from('member_strikes').select('*').order('created_at', { ascending: false }),
    supabase.from('member_standing').select('*').order('last_strike_at', { ascending: false }),
    supabase.from('trains').select('id, name').order('created_at', { ascending: false }),
    supabase.from('train_days').select('train_id, day_date'),
  ])

  strikes.value  = strikeRes.data  || []
  standing.value = standingRes.data || []
  trains.value   = trainRes.data   || []

  const map = {}
  for (const d of dayRes.data || []) {
    if (!map[d.train_id] || d.day_date > map[d.train_id]) map[d.train_id] = d.day_date
  }
  trainLastDay.value = map
  loading.value = false
}

onMounted(loadAll)
</script>
