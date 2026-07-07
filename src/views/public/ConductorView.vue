<template>
  <div class="min-h-screen bg-base">
    <PublicNav />

    <main class="max-w-4xl mx-auto px-6 py-10">

      <!-- Loading -->
      <div v-if="loading" class="text-tx3 text-center py-20">Loading…</div>

      <!-- Not a member train -->
      <div v-else-if="!train || !train.is_member_train" class="card text-center py-16">
        <p class="text-tx1 text-lg mb-2">Train not found</p>
        <RouterLink to="/" class="btn-secondary mt-4">Back to home</RouterLink>
      </div>

      <!-- Username gate -->
      <div v-else-if="!authedUsername" class="max-w-md mx-auto mt-12">
        <div class="card space-y-5">
          <h1 class="text-xl font-semibold text-tx1">Conductor Access</h1>
          <p class="text-sm text-tx3">
            Enter your conductor username to manage <strong class="text-tx2">{{ train.name }}</strong>.
          </p>
          <form @submit.prevent="verifyCondutor" class="space-y-4">
            <div class="relative">
              <span class="absolute left-3 top-1/2 -translate-y-1/2 text-tx3 select-none">@</span>
              <input
                v-model="gateInput"
                class="input pl-7"
                placeholder="yourhandle"
                required
                maxlength="60"
                :disabled="gateLoading"
              />
            </div>
            <p v-if="gateError" class="text-red-600 dark:text-red-400 text-sm" role="alert">{{ gateError }}</p>
            <button type="submit" :disabled="gateLoading" class="btn-primary w-full">
              {{ gateLoading ? 'Checking…' : 'Access Train →' }}
            </button>
          </form>
        </div>
      </div>

      <!-- Management UI -->
      <template v-else>
        <div class="flex items-center gap-3 mb-2 flex-wrap">
          <RouterLink to="/" class="text-niknax-600 hover:text-niknax-500 dark:text-niknax-400 dark:hover:text-niknax-300 text-sm">← All trains</RouterLink>
          <RouterLink :to="`/train/${train.id}`" class="text-niknax-600 hover:text-niknax-500 dark:text-niknax-400 dark:hover:text-niknax-300 text-sm" target="_blank">View public page ↗</RouterLink>
        </div>

        <!-- Status banner -->
        <div v-if="!train.published && !train.is_upcoming" class="bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-700 rounded-lg px-4 py-3 mb-6 flex items-start gap-2">
          <span class="text-amber-600 dark:text-amber-400 mt-0.5">⏳</span>
          <p class="text-sm text-amber-800 dark:text-amber-300">
            <strong>Pending review.</strong> The Niknax team will publish this train once it's approved. You can still edit your train details and schedule while it's pending.
          </p>
        </div>
        <div v-else-if="train.is_upcoming" class="bg-niknax-50 dark:bg-niknax-900/20 border border-niknax-200 dark:border-niknax-700 rounded-lg px-4 py-3 mb-6">
          <p class="text-sm text-niknax-700 dark:text-niknax-300"><strong>Approved — Upcoming!</strong> Your train is visible on the public schedule.</p>
        </div>
        <div v-else-if="train.published" class="bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-700 rounded-lg px-4 py-3 mb-6">
          <p class="text-sm text-green-700 dark:text-green-300"><strong>Live — sign-ups are open!</strong> Sellers can now claim slots on your train.</p>
        </div>

        <div class="flex items-start justify-between gap-4 mb-8 flex-wrap">
          <div>
            <h1 class="text-2xl font-display font-bold text-tx1">{{ train.name }}</h1>
            <p v-if="train.tagline" class="text-tx3 mt-1">{{ train.tagline }}</p>
            <p class="text-xs text-tx3 mt-1">Conductor: <strong>@{{ train.conductor_username }}</strong></p>
          </div>
          <button
            @click="confirmDeleteTrain"
            :disabled="deleting"
            class="text-red-600 hover:text-red-500 dark:text-red-400 dark:hover:text-red-300 text-sm disabled:opacity-50 shrink-0"
          >{{ deleting ? 'Deleting…' : 'Delete Train' }}</button>
        </div>

        <!-- Edit details -->
        <section class="card space-y-5 mb-8">
          <div class="flex items-center justify-between">
            <h2 class="text-base font-semibold text-tx1">Train Details</h2>
            <span v-if="detailsSaved" class="text-green-600 dark:text-green-400 text-xs">Saved ✓</span>
          </div>
          <div>
            <label class="label">Event Name *</label>
            <input v-model="editForm.name" class="input" required maxlength="120" />
          </div>
          <div>
            <label class="label">Tagline</label>
            <input v-model="editForm.tagline" class="input" maxlength="200" />
          </div>
          <div>
            <label class="label">Description</label>
            <textarea v-model="editForm.description" class="input" rows="3" />
          </div>
          <div>
            <label class="label">District / Niknax Event Link</label>
            <input v-model="editForm.district_link" class="input" type="url" placeholder="https://districtapp.tv/…" />
          </div>
          <p v-if="detailsError" class="text-red-600 dark:text-red-400 text-sm">{{ detailsError }}</p>
          <div class="flex justify-end">
            <button @click="saveDetails" :disabled="savingDetails" class="btn-primary text-sm py-2">
              {{ savingDetails ? 'Saving…' : 'Save Details' }}
            </button>
          </div>
        </section>

        <!-- Days & slots -->
        <section class="space-y-6 mb-8">
          <div class="flex items-center justify-between">
            <h2 class="text-base font-semibold text-tx1">Schedule</h2>
            <button @click="showAddDay = !showAddDay" class="btn-secondary text-sm py-1.5">+ Add Day</button>
          </div>

          <!-- Add day form -->
          <div v-if="showAddDay" class="card border-2 border-niknax-200 dark:border-niknax-700 space-y-4">
            <h3 class="text-sm font-semibold text-tx2">New Day</h3>
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="label">Date *</label>
                <input v-model="newDay.day_date" type="date" class="input" required />
              </div>
              <div>
                <label class="label">Label (optional)</label>
                <input v-model="newDay.day_label" class="input" placeholder="Day 2" />
              </div>
            </div>
            <div class="grid grid-cols-3 gap-4">
              <div>
                <label class="label">Start Time (ET)</label>
                <input v-model="newDay.start_time" type="time" class="input" step="60" />
              </div>
              <div>
                <label class="label">Slot Duration (min)</label>
                <input v-model.number="newDay.slot_duration" type="number" min="5" max="120" class="input" />
              </div>
              <div>
                <label class="label">Slot Count</label>
                <input v-model.number="newDay.slot_count" type="number" min="1" max="100" class="input" />
              </div>
            </div>
            <p v-if="addDayError" class="text-red-600 dark:text-red-400 text-sm">{{ addDayError }}</p>
            <div class="flex gap-2 justify-end">
              <button @click="showAddDay = false" class="btn-secondary text-sm py-1.5">Cancel</button>
              <button @click="addDay" :disabled="addingDay" class="btn-primary text-sm py-1.5">
                {{ addingDay ? 'Adding…' : 'Add Day' }}
              </button>
            </div>
          </div>

          <!-- Day cards -->
          <div v-for="day in days" :key="day.id" class="card">
            <div class="flex items-center justify-between mb-4">
              <div>
                <span class="font-semibold text-tx1">{{ formatDate(day.day_date) }}</span>
                <span v-if="day.day_label" class="text-tx3 text-sm ml-2">{{ day.day_label }}</span>
              </div>
              <button
                @click="confirmRemoveDay(day)"
                class="text-red-600 hover:text-red-500 dark:text-red-400 dark:hover:text-red-300 text-xs"
              >Remove day</button>
            </div>

            <!-- Slot table -->
            <div class="overflow-x-auto -mx-2">
              <table class="w-full text-sm min-w-[500px]">
                <thead>
                  <tr class="border-b border-bd text-left text-xs text-tx3 uppercase tracking-wide">
                    <th class="px-2 py-1.5">#</th>
                    <th class="px-2 py-1.5">Time (ET)</th>
                    <th class="px-2 py-1.5">Duration</th>
                    <th class="px-2 py-1.5">Label</th>
                    <th class="px-2 py-1.5">Seller</th>
                    <th class="px-2 py-1.5 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    v-for="(slot, idx) in slotsByDay[day.id] || []"
                    :key="slot.id"
                    class="border-b border-bd/40 last:border-0"
                    :class="slot.id === editingSlotId ? 'bg-sur2' : ''"
                  >
                    <td class="px-2 py-2 text-tx3 font-mono text-xs">{{ slot.slot_order === 0 ? '★' : slot.slot_order }}</td>

                    <!-- View mode -->
                    <template v-if="editingSlotId !== slot.id">
                      <td class="px-2 py-2 font-mono text-xs">{{ formatSlotTime(slot.start_time) }}</td>
                      <td class="px-2 py-2 text-tx3 text-xs">{{ slot.duration_min }}m</td>
                      <td class="px-2 py-2 text-tx3 text-xs">{{ slot.label || '—' }}</td>
                      <td class="px-2 py-2">
                        <span v-if="slot.username" class="text-tx1 text-xs font-medium">@{{ slot.username }}</span>
                        <span v-else class="text-tx3 text-xs italic">— open —</span>
                      </td>
                      <td class="px-2 py-2 text-right">
                        <span class="flex gap-2 justify-end">
                          <button @click="startEditSlot(slot)" class="text-niknax-600 hover:text-niknax-500 dark:text-niknax-400 dark:hover:text-niknax-300 text-xs">Edit</button>
                          <button
                            @click="confirmDeleteSlot(slot, day)"
                            :disabled="deletingSlotId === slot.id"
                            class="text-red-600 hover:text-red-500 dark:text-red-400 dark:hover:text-red-300 text-xs disabled:opacity-50"
                          >{{ deletingSlotId === slot.id ? '…' : 'Delete' }}</button>
                        </span>
                      </td>
                    </template>

                    <!-- Edit mode -->
                    <template v-else>
                      <td class="px-2 py-2">
                        <input v-model="slotEdit.start_time" type="time" class="input text-xs py-1" step="60" />
                      </td>
                      <td class="px-2 py-2">
                        <input v-model.number="slotEdit.duration_min" type="number" min="5" max="120" class="input text-xs py-1 w-16" />
                      </td>
                      <td class="px-2 py-2">
                        <input v-model="slotEdit.label" class="input text-xs py-1" placeholder="Label" maxlength="60" />
                      </td>
                      <td class="px-2 py-2 text-tx3 text-xs italic">{{ slot.username ? `@${slot.username}` : '— open —' }}</td>
                      <td class="px-2 py-2 text-right">
                        <span class="flex gap-1 justify-end">
                          <button @click="saveSlotEdit(slot, day)" :disabled="savingSlotId === slot.id" class="text-green-700 dark:text-green-400 text-xs font-medium">{{ savingSlotId === slot.id ? '…' : 'Save' }}</button>
                          <button @click="editingSlotId = null" class="text-tx3 text-xs">✕</button>
                        </span>
                      </td>
                    </template>
                  </tr>
                </tbody>
              </table>
            </div>

            <!-- Add slot -->
            <div class="mt-4 pt-4 border-t border-bd">
              <details class="text-sm">
                <summary class="cursor-pointer text-niknax-600 hover:text-niknax-500 dark:text-niknax-400 dark:hover:text-niknax-300 text-xs font-medium list-none">+ Add slot to this day</summary>
                <div class="mt-3 grid grid-cols-3 gap-3 items-end">
                  <div>
                    <label class="label text-xs">Start Time (ET)</label>
                    <input v-model="newSlots[day.id].start_time" type="time" class="input text-sm py-1.5" step="60" />
                  </div>
                  <div>
                    <label class="label text-xs">Duration (min)</label>
                    <input v-model.number="newSlots[day.id].duration_min" type="number" min="5" max="120" class="input text-sm py-1.5" />
                  </div>
                  <div>
                    <label class="label text-xs">Label (optional)</label>
                    <input v-model="newSlots[day.id].label" class="input text-sm py-1.5" placeholder="e.g. Boost" maxlength="60" />
                  </div>
                  <div class="col-span-3 flex justify-end gap-2">
                    <button
                      @click="addSlot(day)"
                      :disabled="addingSlotDayId === day.id"
                      class="btn-primary text-xs py-1.5"
                    >{{ addingSlotDayId === day.id ? 'Adding…' : 'Add Slot' }}</button>
                  </div>
                </div>
              </details>
            </div>
          </div>

          <div v-if="days.length === 0" class="text-tx3 text-sm italic">No days scheduled yet.</div>
        </section>

        <!-- Error -->
        <p v-if="actionError" class="text-red-600 dark:text-red-400 text-sm mb-4" role="alert">{{ actionError }}</p>
      </template>
    </main>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import PublicNav from '../../components/PublicNav.vue'
import { supabase } from '../../lib/supabase.js'
import { getConductorSession, setConductorSession } from '../../lib/conductorAuth.js'
import { formatDate, parseTime } from '../../lib/timeUtils.js'

const route  = useRoute()
const router = useRouter()

const loading = ref(true)
const train   = ref(null)
const days    = ref([])
const slots   = ref([])

// ── Auth gate ──────────────────────────────────────────────────────────────
const authedUsername = ref(null)
const gateInput      = ref('')
const gateLoading    = ref(false)
const gateError      = ref('')

function verifyCondutor() {
  gateError.value   = ''
  gateLoading.value = true
  const handle = gateInput.value.trim().replace(/^@+/, '')
  if (train.value?.conductor_username && handle.toLowerCase() === train.value.conductor_username.toLowerCase()) {
    setConductorSession(train.value.id, handle)
    authedUsername.value = handle
  } else {
    gateError.value = 'That username doesn\'t match the conductor on file for this train.'
  }
  gateLoading.value = false
}

// ── Data loading ───────────────────────────────────────────────────────────
const slotsByDay = computed(() => {
  const map = {}
  for (const s of slots.value) {
    if (!map[s.train_day_id]) map[s.train_day_id] = []
    map[s.train_day_id].push(s)
  }
  for (const k in map) {
    map[k].sort((a, b) => (a.slot_order - b.slot_order) || a.start_time.localeCompare(b.start_time))
  }
  return map
})

async function load() {
  loading.value = true
  const id = route.params.id

  const { data: t } = await supabase.from('trains').select('*').eq('id', id).single()
  if (!t || !t.is_member_train) { loading.value = false; return }
  train.value = t

  // Check conductor session
  const session = getConductorSession(id)
  if (session && t.conductor_username && session.toLowerCase() === t.conductor_username.toLowerCase()) {
    authedUsername.value = session
  }

  const { data: d } = await supabase.from('train_days').select('*').eq('train_id', id).order('day_order')
  days.value = d || []

  if (days.value.length) {
    const { data: s } = await supabase
      .from('slots').select('*')
      .in('train_day_id', days.value.map(d => d.id))
      .order('slot_order')
    slots.value = s || []
  }

  // Seed per-day new slot forms
  for (const day of days.value) {
    if (!newSlots.value[day.id]) {
      newSlots.value[day.id] = { start_time: '10:30', duration_min: 30, label: '' }
    }
  }

  // Pre-fill edit form
  editForm.value = {
    name:          t.name,
    tagline:       t.tagline || '',
    description:   t.description || '',
    district_link: t.district_link || '',
  }

  loading.value = false
}

onMounted(load)

// ── Train details editing ──────────────────────────────────────────────────
const editForm     = ref({ name: '', tagline: '', description: '', district_link: '' })
const savingDetails = ref(false)
const detailsError  = ref('')
const detailsSaved  = ref(false)

async function saveDetails() {
  detailsError.value = ''
  savingDetails.value = true
  const { data, error } = await supabase.rpc('update_member_train', {
    p_train_id:      train.value.id,
    p_conductor:     authedUsername.value,
    p_name:          editForm.value.name.trim(),
    p_tagline:       editForm.value.tagline.trim() || null,
    p_description:   editForm.value.description.trim() || null,
    p_district_link: editForm.value.district_link.trim() || null,
  })
  if (error) {
    detailsError.value = error.message
  } else {
    Object.assign(train.value, data)
    detailsSaved.value = true
    setTimeout(() => detailsSaved.value = false, 2000)
  }
  savingDetails.value = false
}

// ── Delete train ───────────────────────────────────────────────────────────
const deleting     = ref(false)
const actionError  = ref('')

async function confirmDeleteTrain() {
  if (!confirm(`Delete "${train.value.name}"? This cannot be undone.`)) return
  deleting.value = true
  const { error } = await supabase.rpc('delete_member_train', {
    p_train_id:  train.value.id,
    p_conductor: authedUsername.value,
  })
  if (error) {
    actionError.value = error.message
    deleting.value = false
  } else {
    router.push('/')
  }
}

// ── Add / remove day ───────────────────────────────────────────────────────
const showAddDay  = ref(false)
const addingDay   = ref(false)
const addDayError = ref('')
const newDay      = ref({ day_date: '', day_label: '', start_time: '10:30', slot_duration: 30, slot_count: 24 })
const newSlots    = ref({})

async function addDay() {
  addDayError.value = ''
  if (!newDay.value.day_date) { addDayError.value = 'Date is required.'; return }
  addingDay.value = true

  const { data, error } = await supabase.rpc('add_member_train_day', {
    p_train_id:      train.value.id,
    p_conductor:     authedUsername.value,
    p_day_date:      newDay.value.day_date,
    p_day_label:     newDay.value.day_label || null,
    p_start_time:    newDay.value.start_time,
    p_slot_duration: newDay.value.slot_duration,
    p_slot_count:    newDay.value.slot_count,
  })

  if (error) {
    addDayError.value = error.message
  } else {
    const result = typeof data === 'string' ? JSON.parse(data) : data
    days.value.push(result.day)
    slots.value.push(...(result.slots || []))
    newSlots.value[result.day.id] = { start_time: '10:30', duration_min: 30, label: '' }
    newDay.value = { day_date: '', day_label: '', start_time: '10:30', slot_duration: 30, slot_count: 24 }
    showAddDay.value = false
  }
  addingDay.value = false
}

async function confirmRemoveDay(day) {
  const daySlots = slotsByDay.value[day.id] || []
  if (!confirm(`Remove ${formatDate(day.day_date)} and all ${daySlots.length} of its slots?`)) return

  const { error } = await supabase.rpc('remove_member_train_day', {
    p_train_id:  train.value.id,
    p_conductor: authedUsername.value,
    p_day_id:    day.id,
  })
  if (error) {
    actionError.value = error.message
  } else {
    days.value = days.value.filter(d => d.id !== day.id)
    slots.value = slots.value.filter(s => s.train_day_id !== day.id)
    delete newSlots.value[day.id]
  }
}

// ── Slot editing ───────────────────────────────────────────────────────────
const editingSlotId = ref(null)
const savingSlotId  = ref(null)
const slotEdit      = ref({ start_time: '', duration_min: 30, label: '' })

function startEditSlot(slot) {
  editingSlotId.value = slot.id
  slotEdit.value = {
    start_time:   slot.start_time.slice(0, 5),
    duration_min: slot.duration_min,
    label:        slot.label || '',
  }
}

async function saveSlotEdit(slot, day) {
  savingSlotId.value = slot.id
  const { data, error } = await supabase.rpc('edit_member_train_slot', {
    p_train_id:   train.value.id,
    p_conductor:  authedUsername.value,
    p_slot_id:    slot.id,
    p_start_time: slotEdit.value.start_time || null,
    p_duration:   slotEdit.value.duration_min,
    p_label:      slotEdit.value.label || null,
  })
  if (error) {
    actionError.value = error.message
  } else {
    Object.assign(slot, data)
    editingSlotId.value = null
  }
  savingSlotId.value = null
}

// ── Slot deletion ──────────────────────────────────────────────────────────
const deletingSlotId = ref(null)

async function confirmDeleteSlot(slot, day) {
  const daySlots = slotsByDay.value[day.id] || []
  const idx = daySlots.findIndex(s => s.id === slot.id)
  const later = daySlots.slice(idx + 1).length
  const label = slot.username ? `@${slot.username}'s slot` : 'this open slot'
  const msg = later
    ? `Delete ${label}? The ${later} slot${later === 1 ? '' : 's'} after it will shift ${slot.duration_min}m earlier.`
    : `Delete ${label}?`
  if (!confirm(msg)) return

  deletingSlotId.value = slot.id
  const { error } = await supabase.rpc('delete_member_train_slot', {
    p_train_id:  train.value.id,
    p_conductor: authedUsername.value,
    p_slot_id:   slot.id,
  })
  if (error) {
    actionError.value = error.message
  } else {
    // Apply the time shift locally (mirrors the DB logic)
    const idx2 = daySlots.indexOf(slot)
    for (let i = idx2 + 1; i < daySlots.length; i++) {
      const s = daySlots[i]
      const { hours, minutes } = parseTime(s.start_time)
      const totalMin = hours * 60 + minutes - slot.duration_min
      const wrapped = ((totalMin % 1440) + 1440) % 1440
      s.start_time = `${String(Math.floor(wrapped / 60)).padStart(2, '0')}:${String(wrapped % 60).padStart(2, '0')}`
      s.slot_order--
    }
    slots.value = slots.value.filter(s => s.id !== slot.id)
  }
  deletingSlotId.value = null
}

// ── Add slot ───────────────────────────────────────────────────────────────
const addingSlotDayId = ref(null)

async function addSlot(day) {
  addingSlotDayId.value = day.id
  const ns = newSlots.value[day.id]
  const { data, error } = await supabase.rpc('add_member_train_slot', {
    p_train_id:   train.value.id,
    p_conductor:  authedUsername.value,
    p_day_id:     day.id,
    p_start_time: ns.start_time,
    p_duration:   ns.duration_min,
    p_label:      ns.label || null,
  })
  if (error) {
    actionError.value = error.message
  } else {
    slots.value.push(data)
    ns.label = ''
  }
  addingSlotDayId.value = null
}

// ── Helpers ────────────────────────────────────────────────────────────────
function formatSlotTime(t) {
  if (!t) return '—'
  const { hours, minutes } = parseTime(t)
  const h = ((hours % 12) || 12)
  const ampm = hours < 12 ? 'AM' : 'PM'
  return `${h}:${String(minutes).padStart(2, '0')} ${ampm}`
}
</script>
