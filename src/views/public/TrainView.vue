<template>
  <div class="min-h-screen bg-gray-950">
    <!-- Nav -->
    <header class="border-b border-gray-800 px-6 py-4 flex items-center justify-between">
      <RouterLink to="/" class="flex items-center gap-2 text-gray-400 hover:text-white transition-colors text-sm">
        ← All Events
      </RouterLink>
      <span class="text-gray-600 text-xs">Niknax Raid Trains</span>
    </header>

    <div v-if="loading" class="text-center py-32 text-gray-500">Loading…</div>

    <template v-else-if="train">
      <!-- Hero -->
      <div
        class="relative bg-gradient-to-br from-niknax-900 via-gray-900 to-gray-950 border-b border-gray-800"
        :style="train.cover_url ? `background-image: url(${train.cover_url}); background-size: cover; background-position: center;` : ''"
      >
        <div class="bg-gray-950/80 backdrop-blur-sm px-6 py-10 max-w-4xl mx-auto">
          <h1 class="text-3xl sm:text-4xl font-bold font-display text-white mb-2">
            {{ train.name }}
          </h1>
          <p v-if="train.tagline" class="text-niknax-300 text-lg mb-3">{{ train.tagline }}</p>
          <p v-if="train.description" class="text-gray-300 mb-4 max-w-2xl">{{ train.description }}</p>

          <div class="flex flex-wrap gap-3">
            <a
              v-if="train.district_link"
              :href="train.district_link"
              target="_blank"
              rel="noopener"
              class="btn-primary text-sm"
            >
              Watch on District ↗
            </a>
            <button @click="copyPageLink" class="btn-secondary text-sm">
              {{ pageLinkCopied ? '✓ Copied!' : '🔗 Share Event' }}
            </button>
            <button
              v-if="train.cover_url"
              @click="downloadGraphic"
              class="btn-secondary text-sm flex items-center gap-1.5"
            >
              📥 Download Train Graphic
            </button>
          </div>
        </div>
      </div>

      <!-- Schedule -->
      <main class="max-w-4xl mx-auto px-4 py-10">
        <div v-for="day in days" :key="day.id" class="mb-12">
          <h2 class="text-xl font-bold text-white mb-1">
            {{ day.day_label ? `${day.day_label} — ` : '' }}{{ formatDate(day.day_date) }}
          </h2>
          <p class="text-gray-500 text-sm mb-5">All times shown in your local time zone below</p>

          <div class="overflow-x-auto">
            <table class="w-full text-sm min-w-[560px]">
              <thead>
                <tr class="bg-gray-800/80 text-gray-400 rounded-t-lg">
                  <th class="text-left px-4 py-3 w-8">#</th>
                  <th class="text-left px-4 py-3">Seller</th>
                  <th class="text-left px-4 py-3 font-semibold text-niknax-300">ET</th>
                  <th class="text-left px-4 py-3">CT</th>
                  <th class="text-left px-4 py-3">MT</th>
                  <th class="text-left px-4 py-3">PT</th>
                  <th class="text-left px-4 py-3 w-28"></th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-800">
                <tr
                  v-for="slot in slotsByDay[day.id] || []"
                  :key="slot.id"
                  :class="[
                    slot.is_pre_assigned ? 'bg-niknax-950/50' : '',
                    !slot.username && !slot.is_pre_assigned ? 'hover:bg-gray-800/40' : '',
                  ]"
                  class="transition-colors"
                >
                  <td class="px-4 py-3 text-gray-600 text-xs">{{ slot.slot_order + 1 }}</td>
                  <td class="px-4 py-3">
                    <div class="flex items-center gap-2">
                      <span v-if="slot.username" class="font-medium text-white">{{ slot.username }}</span>
                      <span v-else class="text-gray-500 italic text-xs">— available —</span>
                      <span
                        v-if="slot.label"
                        class="text-xs font-semibold text-niknax-300 bg-niknax-900/60 px-1.5 py-0.5 rounded"
                      >{{ slot.label }}</span>
                    </div>
                  </td>
                  <td class="px-4 py-3 text-white font-medium">{{ zones(slot.start_time)[0].time }}</td>
                  <td class="px-4 py-3 text-gray-300">{{ zones(slot.start_time)[1].time }}</td>
                  <td class="px-4 py-3 text-gray-300">{{ zones(slot.start_time)[2].time }}</td>
                  <td class="px-4 py-3 text-gray-300">{{ zones(slot.start_time)[3].time }}</td>
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

        <p class="text-center text-gray-600 text-xs mt-8">
          Remember: do not remove anyone from their slot. Doing so may result in removal from the event.
        </p>
      </main>
    </template>

    <div v-else class="text-center py-32 text-gray-500">Event not found.</div>

    <!-- ── Signup Modal ── -->
    <Teleport to="body">
      <div
        v-if="signupModal"
        class="fixed inset-0 bg-black/70 flex items-center justify-center z-50 px-4"
        @click.self="signupModal = null"
      >
        <div class="bg-gray-900 border border-gray-700 rounded-2xl p-6 w-full max-w-sm shadow-2xl">

          <!-- ── Success state ── -->
          <template v-if="signupSuccess">
            <div class="text-center mb-5">
              <div class="text-5xl mb-3">🎉</div>
              <h3 class="text-xl font-bold text-white mb-1">You're on the train!</h3>
              <p class="text-gray-400 text-sm">
                {{ signupSuccess.username }} · {{ zones(signupSuccess.slot.start_time)[0].time }} ET
                · {{ formatDate(signupSuccess.day.day_date) }}
              </p>
            </div>

            <!-- Graphic download card -->
            <div v-if="train.cover_url" class="bg-gray-800 rounded-xl overflow-hidden mb-5">
              <img :src="train.cover_url" class="w-full object-cover max-h-48" alt="Train graphic" />
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
            <h3 class="text-lg font-bold text-white mb-1">Sign Up for This Slot</h3>
            <p class="text-gray-400 text-sm mb-5">
              {{ zones(signupModal.slot.start_time)[0].time }} ET
              · {{ signupModal.slot.duration_min }} min
              · {{ formatDate(signupModal.day.day_date) }}
            </p>

            <div class="space-y-4">
              <div>
                <label class="label">Your District / Niknax Username *</label>
                <input
                  v-model="signupUsername"
                  class="input"
                  placeholder="@YourUsername"
                  @keyup.enter="submitSignup"
                  autofocus
                />
              </div>
              <div>
                <label class="label">Your District Show Link (optional)</label>
                <input
                  v-model="signupLink"
                  class="input"
                  type="url"
                  placeholder="https://districtapp.tv/…"
                />
              </div>
            </div>

            <p v-if="signupError" class="text-red-400 text-sm mt-3">{{ signupError }}</p>

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
import { ref, computed, onMounted } from 'vue'
import { RouterLink, useRoute } from 'vue-router'
import { supabase } from '../../lib/supabase.js'
import { allZones, formatDate } from '../../lib/timeUtils.js'

const route = useRoute()

const train   = ref(null)
const days    = ref([])
const slots   = ref([])
const loading = ref(true)

const signupModal    = ref(null)
const signupSuccess  = ref(null)   // { username, slot, day } after successful claim
const signupUsername = ref('')
const signupLink     = ref('')
const signupError    = ref('')
const signingUp      = ref(false)
const pageLinkCopied = ref(false)

function zones(t) { return allZones(t) }

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
  signupLink.value     = ''
  signupError.value    = ''
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
      seller_link: signupLink.value.trim() || null,
    })
    .eq('id', slot.id)
    .is('username', null)

  if (error) {
    signupError.value = 'Could not claim slot. Please try again.'
  } else {
    const idx = slots.value.findIndex(s => s.id === slot.id)
    if (idx !== -1) {
      slots.value[idx].username    = signupUsername.value.trim()
      slots.value[idx].seller_link = signupLink.value.trim() || null
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

onMounted(load)
</script>
