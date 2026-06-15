<template>
  <div class="min-h-screen bg-gray-950">
    <AdminNav />

    <main class="max-w-5xl mx-auto px-6 py-10">
      <RouterLink to="/admin/dashboard" class="text-niknax-400 hover:text-niknax-300 text-sm mb-6 inline-block">
        ← Back to dashboard
      </RouterLink>

      <div v-if="loading" class="text-gray-400 text-center py-20">Loading…</div>

      <template v-else-if="train">
        <!-- Header -->
        <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4 mb-8">
          <div>
            <div class="flex items-center gap-2 mb-1">
              <span
                :class="train.published ? 'bg-green-900 text-green-300' : 'bg-gray-700 text-gray-300'"
                class="text-xs font-semibold px-2 py-0.5 rounded-full"
              >
                {{ train.published ? 'LIVE' : 'DRAFT' }}
              </span>
            </div>
            <h2 class="text-2xl font-bold text-white">{{ train.name }}</h2>
            <p v-if="train.tagline" class="text-gray-400 mt-1">{{ train.tagline }}</p>
          </div>

          <div class="flex gap-3 shrink-0">
            <a
              v-if="train.published"
              :href="`/train/${train.id}`"
              target="_blank"
              class="btn-secondary text-sm"
            >
              View Public Page ↗
            </a>
            <button
              v-if="!train.published"
              @click="publish"
              :disabled="publishing"
              class="btn-primary text-sm"
            >
              {{ publishing ? 'Publishing…' : '🚀 Publish' }}
            </button>
            <button
              v-else
              @click="unpublish"
              :disabled="publishing"
              class="btn-secondary text-sm"
            >
              {{ publishing ? '…' : 'Unpublish' }}
            </button>
          </div>
        </div>

        <!-- Public link -->
        <div v-if="train.published" class="card mb-6 flex items-center gap-3">
          <span class="text-green-400 text-lg">🔗</span>
          <div class="flex-1 min-w-0">
            <p class="text-xs text-gray-400 mb-1">Public signup link</p>
            <p class="text-sm text-white font-mono truncate">{{ publicUrl }}</p>
          </div>
          <button @click="copyLink" class="btn-secondary text-sm py-1.5 shrink-0">
            {{ copied ? 'Copied!' : 'Copy' }}
          </button>
        </div>

        <!-- Schedule by day -->
        <div v-for="day in days" :key="day.id" class="mb-10">
          <h3 class="text-lg font-semibold text-niknax-300 mb-4">
            {{ day.day_label || formatDate(day.day_date) }} — {{ formatDate(day.day_date) }}
          </h3>

          <div class="card overflow-x-auto p-0">
            <table class="w-full text-sm">
              <thead>
                <tr class="bg-gray-800 text-gray-400">
                  <th class="text-left px-4 py-3 w-8">#</th>
                  <th class="text-left px-4 py-3">Username</th>
                  <th class="text-left px-4 py-3">ET</th>
                  <th class="text-left px-4 py-3">CT</th>
                  <th class="text-left px-4 py-3">MT</th>
                  <th class="text-left px-4 py-3">PT</th>
                  <th class="text-left px-4 py-3">Duration</th>
                  <th class="text-left px-4 py-3">Type</th>
                  <th class="px-4 py-3 w-24"></th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-800">
                <tr
                  v-for="slot in slotsByDay[day.id] || []"
                  :key="slot.id"
                  :class="slot.is_pre_assigned ? 'bg-niknax-950/40' : ''"
                  class="hover:bg-gray-800/50 transition-colors"
                >
                  <td class="px-4 py-2.5 text-gray-500">{{ slot.slot_order + 1 }}</td>
                  <td class="px-4 py-2.5">
                    <span v-if="editingSlot === slot.id">
                      <input
                        v-model="editUsername"
                        class="input py-1 text-sm"
                        @keyup.enter="saveSlotUsername(slot)"
                        @keyup.escape="editingSlot = null"
                        placeholder="username"
                        autofocus
                      />
                    </span>
                    <span v-else>
                      <span v-if="slot.username" class="text-white font-medium">{{ slot.username }}</span>
                      <span v-else class="text-gray-500 italic">— open —</span>
                      <span v-if="slot.label" class="ml-2 text-xs text-niknax-400 bg-niknax-900/50 px-1.5 py-0.5 rounded">{{ slot.label }}</span>
                    </span>
                  </td>
                  <td class="px-4 py-2.5 text-gray-300">{{ zones(slot.start_time)[0].time }}</td>
                  <td class="px-4 py-2.5 text-gray-300">{{ zones(slot.start_time)[1].time }}</td>
                  <td class="px-4 py-2.5 text-gray-300">{{ zones(slot.start_time)[2].time }}</td>
                  <td class="px-4 py-2.5 text-gray-300">{{ zones(slot.start_time)[3].time }}</td>
                  <td class="px-4 py-2.5 text-gray-400">{{ slot.duration_min }} min</td>
                  <td class="px-4 py-2.5">
                    <span v-if="slot.is_pre_assigned" class="text-xs text-niknax-400">Reserved</span>
                    <span v-else class="text-xs text-gray-500">Open</span>
                  </td>
                  <td class="px-4 py-2.5 text-right">
                    <span v-if="editingSlot === slot.id" class="flex gap-1 justify-end">
                      <button @click="saveSlotUsername(slot)" class="text-green-400 hover:text-green-300 text-xs font-medium">Save</button>
                      <button @click="editingSlot = null" class="text-gray-500 hover:text-gray-300 text-xs">Cancel</button>
                    </span>
                    <button
                      v-else
                      @click="startEdit(slot)"
                      class="text-niknax-400 hover:text-niknax-300 text-xs"
                    >
                      Edit
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <!-- Add slot to this day -->
          <button
            @click="addSlotToDay(day)"
            class="mt-3 text-sm text-niknax-400 hover:text-niknax-300"
          >
            + Add slot to this day
          </button>
        </div>

        <!-- Danger zone -->
        <div class="card border-red-800 mt-10 space-y-3">
          <h4 class="text-red-400 font-semibold text-sm">Danger Zone</h4>
          <button @click="confirmDelete" class="btn-danger text-sm">Delete Train</button>
        </div>
      </template>
    </main>

    <!-- Add slot modal -->
    <div v-if="addSlotDay" class="fixed inset-0 bg-black/60 flex items-center justify-center z-50 px-4">
      <div class="bg-gray-900 border border-gray-700 rounded-xl p-6 w-full max-w-sm space-y-4">
        <h4 class="font-semibold text-white">Add Slot</h4>
        <div>
          <label class="label">Username (leave blank for open slot)</label>
          <input v-model="newSlot.username" class="input" placeholder="@username" />
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="label">Start Time (ET)</label>
            <input v-model="newSlot.start_time" type="time" class="input" />
          </div>
          <div>
            <label class="label">Duration (min)</label>
            <input v-model.number="newSlot.duration_min" type="number" min="5" max="120" class="input" />
          </div>
        </div>
        <div>
          <label class="label">Label (optional)</label>
          <input v-model="newSlot.label" class="input" placeholder="Kickoff, Boost…" />
        </div>
        <label class="flex items-center gap-2 text-sm text-gray-300 cursor-pointer">
          <input v-model="newSlot.is_pre_assigned" type="checkbox" class="rounded" />
          Reserved (cannot be claimed via public signup)
        </label>
        <div class="flex gap-3 justify-end">
          <button @click="addSlotDay = null" class="btn-secondary">Cancel</button>
          <button @click="saveNewSlot" :disabled="savingSlot" class="btn-primary">
            {{ savingSlot ? 'Saving…' : 'Add Slot' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import AdminNav from '../../components/AdminNav.vue'
import { supabase } from '../../lib/supabase.js'
import { allZones, formatDate } from '../../lib/timeUtils.js'

const route  = useRoute()
const router = useRouter()

const train     = ref(null)
const days      = ref([])
const slots     = ref([])
const loading   = ref(true)
const publishing = ref(false)
const copied    = ref(false)

const editingSlot  = ref(null)
const editUsername = ref('')
const addSlotDay   = ref(null)
const savingSlot   = ref(false)
const newSlot = ref({ username: '', start_time: '12:00', duration_min: 30, label: '', is_pre_assigned: false })

const publicUrl = computed(() => `${location.origin}/train/${train.value?.id}`)

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

function zones(t) { return allZones(t) }

async function load() {
  loading.value = true
  const id = route.params.id

  const [{ data: t }, { data: d }, { data: s }] = await Promise.all([
    supabase.from('trains').select('*').eq('id', id).single(),
    supabase.from('train_days').select('*').eq('train_id', id).order('day_order'),
    supabase.from('slots').select('*').in(
      'train_day_id',
      (await supabase.from('train_days').select('id').eq('train_id', id)).data?.map(r => r.id) || []
    ).order('slot_order'),
  ])

  train.value = t
  days.value  = d || []
  slots.value = s || []
  loading.value = false
}

async function publish() {
  publishing.value = true
  await supabase.from('trains').update({ published: true }).eq('id', train.value.id)
  train.value.published = true
  publishing.value = false
}

async function unpublish() {
  publishing.value = true
  await supabase.from('trains').update({ published: false }).eq('id', train.value.id)
  train.value.published = false
  publishing.value = false
}

function copyLink() {
  navigator.clipboard.writeText(publicUrl.value)
  copied.value = true
  setTimeout(() => copied.value = false, 2000)
}

function startEdit(slot) {
  editingSlot.value  = slot.id
  editUsername.value = slot.username || ''
}

async function saveSlotUsername(slot) {
  const { error } = await supabase
    .from('slots')
    .update({ username: editUsername.value || null })
    .eq('id', slot.id)
  if (!error) {
    slot.username = editUsername.value || null
    editingSlot.value = null
  }
}

function addSlotToDay(day) {
  addSlotDay.value = day
  newSlot.value = { username: '', start_time: '12:00', duration_min: 30, label: '', is_pre_assigned: false }
}

async function saveNewSlot() {
  savingSlot.value = true
  const maxOrder = (slotsByDay.value[addSlotDay.value.id] || []).reduce((m, s) => Math.max(m, s.slot_order), -1)
  const { data, error } = await supabase.from('slots').insert({
    train_day_id: addSlotDay.value.id,
    start_time: newSlot.value.start_time,
    duration_min: newSlot.value.duration_min,
    username: newSlot.value.username || null,
    label: newSlot.value.label || null,
    is_pre_assigned: newSlot.value.is_pre_assigned,
    slot_order: maxOrder + 1,
  }).select().single()

  if (!error) {
    slots.value.push(data)
    addSlotDay.value = null
  }
  savingSlot.value = false
}

async function confirmDelete() {
  if (!confirm(`Delete "${train.value.name}"? This cannot be undone.`)) return
  await supabase.from('trains').delete().eq('id', train.value.id)
  router.push('/admin/dashboard')
}

onMounted(load)
</script>
