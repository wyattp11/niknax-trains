<template>
  <div class="min-h-screen bg-base flex flex-col">

    <!-- ── Top accent stripe + back nav ── -->
    <div class="h-3 bg-niknax-600 shrink-0"></div>
    <div class="px-4 sm:px-6 py-3 border-b border-bd flex items-center justify-between max-w-4xl mx-auto w-full">
      <RouterLink to="/" class="font-display text-niknax-600 dark:text-niknax-400 hover:text-niknax-500 text-sm tracking-wide transition-colors">
        ← Niknax Train Station
      </RouterLink>
      <button
        @click="theme.toggle()"
        class="text-tx3 hover:text-tx1 transition-colors text-base"
        :title="theme.isDark ? 'Switch to light mode' : 'Switch to dark mode'"
        :aria-label="theme.isDark ? 'Switch to light mode' : 'Switch to dark mode'"
      ><span aria-hidden="true">{{ theme.isDark ? '☀' : '◑' }}</span></button>
    </div>

    <div v-if="loading" class="text-center py-32 text-tx3">Loading…</div>

    <template v-else-if="train">
      <!-- Hero — 60s style: strong typography, optional photo strip -->
      <div
        class="relative border-b border-bd"
        :class="train.cover_url ? '' : 'bg-base'"
        :style="train.cover_url ? `background-image: url(${train.cover_url}); background-size: cover; background-position: center;` : ''"
      >
        <div
          class="px-6 py-10 max-w-4xl mx-auto"
          :class="train.cover_url ? 'bg-black/70 backdrop-blur-sm' : ''"
        >
          <!-- Eyebrow -->
          <p class="text-[0.6rem] font-mono tracking-[0.5em] uppercase mb-3"
             :class="train.cover_url ? 'text-white/60' : 'text-tx3'">
            Niknax Train Station · Raid Train
          </p>
          <span :class="`badge-${STATUS_BADGE_CLASS[status.key]}`" class="inline-block mb-3">
            {{ status.label }}
          </span>
          <h1 class="font-display leading-tight mb-2"
              :class="['text-3xl sm:text-5xl', train.cover_url ? 'text-white' : 'text-tx1']">
            {{ train.name }}
          </h1>
          <p v-if="train.tagline"
             class="text-lg mb-3"
             :class="train.cover_url ? 'text-white/80' : 'text-tx2'">
            {{ train.tagline }}
          </p>
          <p v-if="train.description"
             class="mb-5 max-w-2xl text-sm"
             :class="train.cover_url ? 'text-white/70' : 'text-tx3'">
            {{ train.description }}
          </p>

          <div class="flex flex-wrap gap-3">
            <a
              v-if="effectiveDistrictLink"
              :href="effectiveDistrictLink"
              target="_blank"
              rel="noopener"
              class="btn-primary text-sm"
            >
              Watch on District ↗
            </a>
            <button @click="copyPageLink" class="btn-secondary text-sm" aria-live="polite">
              {{ pageLinkCopied ? '✓ Copied!' : '🔗 Share Event' }}
            </button>
            <button
              v-if="train.cover_url"
              @click="downloadGraphic"
              class="btn-secondary text-sm flex items-center gap-1.5"
            >
              📥 Download Graphic
            </button>
          </div>
        </div>
      </div>

      <!-- Schedule -->
      <main class="max-w-4xl mx-auto px-4 py-10 flex-1">
        <div v-for="day in days" :key="day.id" class="mb-12">
          <!-- 60s section header -->
          <div class="flex items-center gap-4 mb-4">
            <h2 class="font-display text-2xl sm:text-3xl text-tx1 shrink-0">
              {{ day.day_label ? `${day.day_label} — ` : '' }}{{ formatDate(day.day_date) }}
            </h2>
            <div class="flex-1 h-[3px] bg-niknax-600 rounded-full"></div>
          </div>
          <p class="text-tx3 text-xs font-mono mb-5 tracking-widest">ALL TIMES SHOWN · ET IS PRIMARY</p>

          <div class="overflow-x-auto">
            <table class="w-full text-sm min-w-[560px]">
              <thead>
                <tr class="bg-sur2 text-tx3">
                  <th class="text-left px-4 py-3 w-8">#</th>
                  <th class="text-left px-4 py-3">Seller</th>
                  <th class="text-left px-4 py-3 font-semibold text-niknax-500">ET</th>
                  <th class="text-left px-4 py-3">CT</th>
                  <th class="text-left px-4 py-3">MT</th>
                  <th class="text-left px-4 py-3">PT</th>
                  <th class="text-left px-4 py-3 w-28"></th>
                </tr>
              </thead>
              <tbody class="divide-y divide-bd">
                <tr
                  v-for="(slot, slotIdx) in slotsByDay[day.id] || []"
                  :key="slot.id"
                  :id="`slot-${slot.id}`"
                  :class="[
                    slot.id === activeSlotId
                      ? 'bg-[var(--badge-live-bg)] ring-1 ring-inset ring-[var(--badge-live-dot)]'
                      : slot.is_pre_assigned
                        ? 'bg-niknax-500/10'
                        : !slot.username ? 'hover:bg-sur2/60' : '',
                  ]"
                  class="transition-colors"
                >
                  <td class="px-4 py-3 text-tx3 text-xs">{{ slotIdx + 1 }}</td>
                  <td class="px-4 py-3">
                    <div class="flex items-center gap-2 flex-wrap">
                      <span v-if="slot.username" class="font-medium text-tx1">{{ slot.username }}</span>
                      <span v-else class="text-tx3 italic text-xs">— available —</span>
                      <span
                        v-if="slot.id === activeSlotId"
                        class="inline-flex items-center gap-1 text-xs font-bold px-2 py-0.5 rounded-full bg-[var(--badge-live-bg)] text-[var(--badge-live-text)]"
                      >
                        <span class="w-1.5 h-1.5 rounded-full bg-[var(--badge-live-dot)] animate-pulse inline-block"></span>
                        LIVE NOW
                      </span>
                      <span
                        v-if="slot.label"
                        class="text-xs font-semibold text-niknax-500 bg-niknax-500/15 px-1.5 py-0.5 rounded"
                      >{{ slot.label }}</span>

                      <!-- Show link — only offered once the slot is claimed -->
                      <template v-if="slot.username">
                        <a
                          v-if="slot.seller_link"
                          :href="slot.seller_link"
                          target="_blank"
                          rel="noopener"
                          class="text-xs font-semibold text-niknax-600 dark:text-niknax-400 hover:underline"
                        >Show link ↗</a>
                        <button
                          v-else-if="linkEditSlotId !== slot.id"
                          @click="startAddLink(slot)"
                          class="text-xs text-tx3 hover:text-niknax-600 dark:hover:text-niknax-400 underline"
                        >+ Add show link</button>
                        <span v-else class="flex items-center gap-1.5 basis-full mt-1">
                          <input
                            v-model="linkEditValue"
                            type="url"
                            placeholder="https://districtapp.tv/…"
                            class="input text-xs py-1 px-2 flex-1 min-w-0"
                            @keyup.enter="saveLink(slot)"
                            @keyup.esc="cancelAddLink"
                          />
                          <button @click="saveLink(slot)" class="text-xs font-semibold text-niknax-600 dark:text-niknax-400 shrink-0">Save</button>
                          <button @click="cancelAddLink" class="text-xs text-tx3 shrink-0">✕</button>
                        </span>
                      </template>
                    </div>
                  </td>
                  <td class="px-4 py-3 text-tx1 font-bold text-base">{{ zones(slot.start_time)[0].time }}</td>
                  <td class="px-4 py-3 text-tx2 font-semibold">{{ zones(slot.start_time)[1].time }}</td>
                  <td class="px-4 py-3 text-tx2 font-semibold">{{ zones(slot.start_time)[2].time }}</td>
                  <td class="px-4 py-3 text-tx2 font-semibold">{{ zones(slot.start_time)[3].time }}</td>
                  <td class="px-4 py-3 text-right">
                    <button
                      v-if="!slot.username && !slot.is_pre_assigned"
                      @click="openSignup(slot, day)"
                      class="bg-niknax-600 hover:bg-niknax-500 text-white text-xs font-semibold px-3 py-1.5 rounded-lg transition-colors"
                    >
                      Sign Up
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <p class="text-center text-tx3 text-xs mt-8 font-mono tracking-wide">
          Do not remove anyone from their slot — doing so may result in removal from the event.
        </p>
      </main>
    </template>

    <div v-else class="text-center py-32 text-tx3 flex-1">Event not found.</div>

    <!-- ── Bottom accent stripe ── -->
    <div class="h-3 bg-niknax-600 shrink-0 mt-auto"></div>

    <!-- ── Signup Modal ── -->
    <Teleport to="body">
      <div
        v-if="signupModal"
        class="fixed inset-0 bg-black/70 flex items-center justify-center z-50 px-4"
        @click.self="signupModal = null"
      >
        <div
          ref="modalRef"
          class="bg-surface border border-bd rounded-2xl p-6 w-full max-w-sm shadow-2xl"
          role="dialog"
          aria-modal="true"
          :aria-label="signupSuccess ? 'Signup confirmed' : 'Sign up for this slot'"
          tabindex="-1"
        >

          <!-- ── Success state ── -->
          <template v-if="signupSuccess">
            <div class="text-center mb-5">
              <div class="text-5xl mb-3" aria-hidden="true">🎉</div>
              <h3 ref="successHeadingRef" tabindex="-1" class="text-xl font-bold text-white mb-1">You're on the train!</h3>
              <p class="text-gray-400 text-sm">
                {{ signupSuccess.username }} · {{ zones(signupSuccess.slot.start_time)[0].time }} ET
                · {{ formatDate(signupSuccess.day.day_date) }}
              </p>
            </div>

            <!-- Graphic download card -->
            <div v-if="train.cover_url" class="bg-gray-800 rounded-xl overflow-hidden mb-5">
              <img :src="train.cover_url" class="w-full object-cover max-h-48" :alt="`${train.name} promotional graphic`" />
              <div class="p-3 flex items-center justify-between gap-3">
                <div>
                  <p class="text-white text-sm font-semibold">Train Graphic</p>
                  <p class="text-gray-400 text-xs">Share with your followers!</p>
                </div>
                <button
                  @click="downloadGraphic"
                  class="btn-primary text-sm py-1.5 shrink-0 flex items-center gap-1.5"
                >
                  📥 Download
                </button>
              </div>
            </div>

            <button @click="signupModal = null; signupSuccess = null" class="btn-secondary w-full">
              Close
            </button>
          </template>

          <!-- ── Input state ── -->
          <template v-else>
            <h3 class="text-lg font-bold text-tx1 mb-1">Sign Up for This Slot</h3>
            <p class="text-tx3 text-sm mb-5">
              {{ zones(signupModal.slot.start_time)[0].time }} ET
              · {{ signupModal.slot.duration_min }} min
              · {{ formatDate(signupModal.day.day_date) }}
            </p>

            <div class="space-y-4">
              <div class="relative">
                <label class="label" id="signup-username-label">Your District / Niknax Username *</label>
                <input
                  v-model="signupUsername"
                  class="input"
                  placeholder="@YourUsername"
                  autocomplete="off"
                  role="combobox"
                  aria-autocomplete="list"
                  aria-haspopup="listbox"
                  :aria-expanded="usernameSuggestions.length > 0"
                  aria-controls="username-suggestions-list"
                  :aria-activedescendant="activeSuggestion >= 0 ? `username-suggestion-${activeSuggestion}` : undefined"
                  aria-labelledby="signup-username-label"
                  @input="onUsernameInput"
                  @keyup.enter="submitSignup"
                  @keydown.down.prevent="moveSuggestion(1)"
                  @keydown.up.prevent="moveSuggestion(-1)"
                  @keydown.esc="onUsernameEscape"
                  @blur="hideSuggestionsSoon"
                  @focus="onUsernameInput"
                />
                <ul
                  v-if="usernameSuggestions.length"
                  id="username-suggestions-list"
                  role="listbox"
                  class="absolute z-10 left-0 right-0 mt-1 card p-1 max-h-48 overflow-y-auto shadow-lg"
                >
                  <li
                    v-for="(s, i) in usernameSuggestions"
                    :id="`username-suggestion-${i}`"
                    :key="s"
                    role="option"
                    :aria-selected="i === activeSuggestion"
                    class="px-3 py-1.5 rounded-md text-sm cursor-pointer"
                    :class="i === activeSuggestion ? 'bg-niknax-600 text-white' : 'text-tx1 hover:bg-sur2'"
                    @mousedown.prevent="pickSuggestion(s)"
                  >
                    @{{ s }}
                  </li>
                </ul>
              </div>
            </div>

            <p class="text-red-600 dark:text-red-400 text-sm mt-3 min-h-[1.25rem]" aria-live="polite">{{ signupError }}</p>

            <div class="flex gap-3 mt-6">
              <button @click="signupModal = null" class="btn-secondary flex-1">Cancel</button>
              <button @click="submitSignup" :disabled="signingUp" class="btn-primary flex-1">
                {{ signingUp ? 'Saving…' : 'Claim Slot ✓' }}
              </button>
            </div>
          </template>

        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted, onUnmounted, nextTick } from 'vue'
import { RouterLink, useRoute } from 'vue-router'
import { supabase } from '../../lib/supabase.js'
import { allZones, formatDate, parseTime, trainStatus, STATUS_BADGE_CLASS } from '../../lib/timeUtils.js'
import { useThemeStore } from '../../stores/theme.js'
import { useModalA11y } from '../../composables/useModalA11y.js'

const route = useRoute()
const theme = useThemeStore()

const train   = ref(null)
const days    = ref([])
const slots   = ref([])
const loading = ref(true)

const signupModal    = ref(null)
const signupSuccess  = ref(null)   // { username, slot, day } after successful claim
const signupUsername = ref('')
const signupError    = ref('')
const signingUp      = ref(false)
const pageLinkCopied = ref(false)

// ── Inline "add show link" editing for already-claimed slots ─────────────
const linkEditSlotId = ref(null)
const linkEditValue  = ref('')

function startAddLink(slot) {
  linkEditSlotId.value = slot.id
  linkEditValue.value  = slot.seller_link || ''
}

function cancelAddLink() {
  linkEditSlotId.value = null
  linkEditValue.value  = ''
}

async function saveLink(slot) {
  const value = linkEditValue.value.trim()
  const { error } = await supabase
    .from('slots')
    .update({ seller_link: value || null })
    .eq('id', slot.id)
  if (!error) {
    const idx = slots.value.findIndex(s => s.id === slot.id)
    if (idx !== -1) slots.value[idx].seller_link = value || null
  }
  cancelAddLink()
}

const successHeadingRef = ref(null)

const { modalRef } = useModalA11y(
  () => !!signupModal.value,
  () => { signupModal.value = null }
)

watch(signupSuccess, async (val) => {
  if (val) {
    await nextTick()
    successHeadingRef.value?.focus?.()
  }
})

// ── Username autocomplete (from members_signup_search view) ──────────────
const usernameSuggestions = ref([])
const activeSuggestion    = ref(-1)
let usernameTimer = null

function onUsernameInput() {
  clearTimeout(usernameTimer)
  const term = signupUsername.value.trim()
  if (term.length < 2) {
    usernameSuggestions.value = []
    return
  }
  usernameTimer = setTimeout(async () => {
    const { data, error } = await supabase
      .from('members_signup_search')
      .select('username')
      .ilike('username', `%${term}%`)
      .limit(8)
    if (!error) {
      usernameSuggestions.value = (data || []).map(r => r.username)
      activeSuggestion.value = -1
    }
  }, 250)
}

function pickSuggestion(username) {
  signupUsername.value = username
  usernameSuggestions.value = []
}

function onUsernameEscape(e) {
  // If the suggestion list is open, Escape should dismiss just the list
  // (not the whole signup modal). Stop it from bubbling to the modal's
  // document-level Escape-to-close handler.
  if (usernameSuggestions.value.length) {
    e.stopPropagation()
    usernameSuggestions.value = []
    activeSuggestion.value = -1
  }
}

function moveSuggestion(delta) {
  if (!usernameSuggestions.value.length) return
  const max = usernameSuggestions.value.length - 1
  let next = activeSuggestion.value + delta
  if (next < 0) next = max
  if (next > max) next = 0
  activeSuggestion.value = next
  signupUsername.value = usernameSuggestions.value[next]
}

function hideSuggestionsSoon() {
  setTimeout(() => { usernameSuggestions.value = [] }, 150)
}

function zones(t) { return allZones(t) }

// ── Live-now tracking ─────────────────────────────────────────────────────
function getCurrentET() {
  return new Date(new Date().toLocaleString('en-US', { timeZone: 'America/New_York' }))
}

const nowET = ref(getCurrentET())
let clockInterval = null

const activeSlotId = computed(() => {
  const d = nowET.value
  const dateStr = [
    d.getFullYear(),
    String(d.getMonth() + 1).padStart(2, '0'),
    String(d.getDate()).padStart(2, '0'),
  ].join('-')
  const nowMin = d.getHours() * 60 + d.getMinutes()

  for (const day of days.value) {
    if (day.day_date !== dateStr) continue
    for (const slot of (slotsByDay.value[day.id] || [])) {
      const { hours, minutes } = parseTime(slot.start_time)
      const startMin = hours * 60 + minutes
      const endMin   = startMin + (slot.duration_min || 30)
      if (nowMin >= startMin && nowMin < endMin) return slot.id
    }
  }
  return null
})

const status = computed(() =>
  trainStatus(train.value, slots.value.length, slots.value.filter(s => s.username).length)
)

const slotsByDay = computed(() => {
  const map = {}
  for (const s of slots.value) {
    if (!map[s.train_day_id]) map[s.train_day_id] = []
    map[s.train_day_id].push(s)
  }
  for (const k in map) {
    map[k].sort((a, b) => a.slot_order - b.slot_order || a.start_time.localeCompare(b.start_time))
  }
  return map
})

// ── Dynamic "Watch on District" link ──────────────────────────────────────
// Always points at whichever seller should currently have eyes on them:
// the slot live right now, or — if nothing's live yet/anymore today — the
// next slot chronologically (which naturally rolls over to the next day's
// slot #1 once today's slots have all ended). If that anchor slot hasn't
// had its show link filled in yet, we walk forward to the next slot that
// has one. Falls back to the admin-set generic event link if nothing else
// is available (e.g. the whole event has wrapped).
const flatSlotsChrono = computed(() => {
  const list = []
  for (const day of days.value) {
    for (const slot of (slotsByDay.value[day.id] || [])) {
      list.push({ day, slot })
    }
  }
  return list
})

function slotEndsAt(day, slot) {
  const [y, m, d] = day.day_date.split('-').map(Number)
  const { hours, minutes } = parseTime(slot.start_time)
  const start = new Date(y, m - 1, d, hours, minutes)
  return new Date(start.getTime() + (slot.duration_min || 30) * 60000)
}

const effectiveDistrictLink = computed(() => {
  const now = nowET.value
  const list = flatSlotsChrono.value
  const anchorIdx = list.findIndex(({ day, slot }) => slotEndsAt(day, slot) > now)
  if (anchorIdx === -1) return train.value?.district_link || null

  for (let i = anchorIdx; i < list.length; i++) {
    const link = list[i].slot.seller_link
    if (link) return link
  }
  return train.value?.district_link || null
})

async function load() {
  loading.value = true
  const id = route.params.id

  const { data: t } = await supabase
    .from('trains')
    .select('*')
    .eq('id', id)
    .single()

  if (!t) { loading.value = false; return }
  train.value = t

  document.title = `${t.name} — Niknax Raid Train`
  setMeta('og:title', t.name)
  setMeta('og:description', t.tagline || 'Join the live-selling train on District!')
  if (t.cover_url) setMeta('og:image', t.cover_url)
  setMeta('og:url', location.href)

  const { data: d } = await supabase
    .from('train_days')
    .select('*')
    .eq('train_id', id)
    .order('day_order')

  days.value = d || []

  if (days.value.length) {
    const dayIds = days.value.map(d => d.id)
    const { data: s } = await supabase
      .from('slots')
      .select('*')
      .in('train_day_id', dayIds)
      .order('slot_order')
    slots.value = s || []
  }

  loading.value = false
}

function setMeta(name, content) {
  let el = document.querySelector(`meta[property="${name}"]`)
  if (!el) { el = document.createElement('meta'); el.setAttribute('property', name); document.head.appendChild(el) }
  el.setAttribute('content', content)
}

function openSignup(slot, day) {
  signupSuccess.value  = null
  signupModal.value    = { slot, day }
  signupUsername.value = ''
  signupError.value    = ''
  usernameSuggestions.value = []
}

async function submitSignup() {
  if (!signupUsername.value.trim()) {
    signupError.value = 'Please enter your username.'
    return
  }
  signingUp.value   = true
  signupError.value = ''

  const { slot, day } = signupModal.value

  // Re-check slot is still open
  const { data: fresh } = await supabase
    .from('slots').select('username').eq('id', slot.id).single()

  if (fresh?.username) {
    signupError.value = 'Sorry — this slot was just claimed! Please pick another.'
    signingUp.value = false
    await load()
    return
  }

  const { error } = await supabase
    .from('slots')
    .update({
      username: signupUsername.value.trim(),
    })
    .eq('id', slot.id)
    .is('username', null)

  if (error) {
    signupError.value = 'Could not claim slot. Please try again.'
  } else {
    const idx = slots.value.findIndex(s => s.id === slot.id)
    if (idx !== -1) {
      slots.value[idx].username = signupUsername.value.trim()
    }
    // Show success screen with graphic download
    signupSuccess.value = { username: signupUsername.value.trim(), slot, day }
  }
  signingUp.value = false
}

async function downloadGraphic() {
  if (!train.value?.cover_url) return
  const filename = `${train.value.name.replace(/[^a-z0-9]/gi, '-').toLowerCase()}-train-graphic`
  try {
    const res  = await fetch(train.value.cover_url)
    const blob = await res.blob()
    const ext  = blob.type.includes('png') ? 'png' : blob.type.includes('gif') ? 'gif' : 'jpg'
    const url  = URL.createObjectURL(blob)
    const a    = Object.assign(document.createElement('a'), { href: url, download: `${filename}.${ext}` })
    a.click()
    URL.revokeObjectURL(url)
  } catch {
    // CORS blocked — open in new tab so user can save manually
    window.open(train.value.cover_url, '_blank')
  }
}

function copyPageLink() {
  navigator.clipboard.writeText(location.href)
  pageLinkCopied.value = true
  setTimeout(() => pageLinkCopied.value = false, 2000)
}

async function loadAndScroll() {
  await load()
  clockInterval = setInterval(() => { nowET.value = getCurrentET() }, 30_000)
  await nextTick()
  if (activeSlotId.value) {
    document.getElementById(`slot-${activeSlotId.value}`)
      ?.scrollIntoView({ behavior: 'smooth', block: 'center' })
  }
}

onMounted(loadAndScroll)
onUnmounted(() => { if (clockInterval) clearInterval(clockInterval) })
</script>
