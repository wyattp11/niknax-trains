<template>
  <div class="min-h-screen bg-base">
    <AdminNav />

    <main class="max-w-5xl mx-auto px-6 py-10">
      <RouterLink to="/admin/dashboard" class="text-niknax-600 hover:text-niknax-500 dark:text-niknax-400 dark:hover:text-niknax-300 text-sm mb-6 inline-block">
        ← Back to dashboard
      </RouterLink>

      <div v-if="loading" class="text-tx3 text-center py-20">Loading…</div>

      <template v-else-if="train">

        <!-- ── Status bar ── -->
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
          <div class="flex items-center gap-3 flex-wrap">
            <span :class="statusBadge.class" class="text-xs font-bold px-2.5 py-1 rounded-full">
              {{ statusBadge.label }}
            </span>
            <h2 class="text-2xl font-bold text-tx1">{{ train.name }}</h2>
          </div>
          <div class="flex flex-col sm:flex-row gap-2 shrink-0 w-full sm:w-auto">
            <a v-if="train.published" :href="`/train/${train.id}`" target="_blank" class="btn-secondary text-sm text-center whitespace-nowrap">
              View Public ↗
            </a>
            <button v-if="!train.published" @click="publish" :disabled="publishing" class="btn-primary text-sm whitespace-nowrap">
              {{ publishing ? '…' : '🚀 Publish' }}
            </button>
            <button v-else @click="unpublish" :disabled="publishing" class="btn-secondary text-sm whitespace-nowrap">
              {{ publishing ? '…' : 'Unpublish' }}
            </button>
          </div>
        </div>

        <!-- ── Public link ── -->
        <div v-if="train.published" class="card mb-4 flex flex-col sm:flex-row sm:items-center gap-3">
          <span class="text-green-400">🔗</span>
          <p class="text-sm font-mono text-tx1 w-full sm:flex-1 truncate">{{ publicUrl }}</p>
          <button @click="copyLink" class="btn-secondary text-sm py-1.5 shrink-0 w-full sm:w-auto">
            {{ copied ? 'Copied!' : 'Copy' }}
          </button>
        </div>

        <!-- ── Upcoming toggle (only for drafts) ── -->
        <div v-if="!train.published" class="card mb-6 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div>
            <p class="font-medium text-tx1">Show as Upcoming Event</p>
            <p class="text-sm text-tx3 mt-0.5">
              Displays this event on the public home page and calendar before it's fully live.
              Sellers can see the dates but won't be able to sign up yet.
            </p>
          </div>
          <button
            @click="toggleUpcoming"
            :class="train.is_upcoming
              ? 'bg-amber-500 hover:bg-amber-400'
              : 'bg-sur2 hover:bg-bd'"
            class="relative inline-flex items-center shrink-0 w-11 h-6 rounded-full transition-colors"
          >
            <span
              :class="train.is_upcoming ? 'translate-x-6' : 'translate-x-1'"
              class="inline-block w-4 h-4 bg-white rounded-full shadow transition-transform duration-200"
            />
          </button>
        </div>

        <!-- ── Edit Details ── -->
        <div class="card mb-6">
          <button
            @click="showEdit = !showEdit"
            class="flex items-center justify-between w-full text-left"
          >
            <span class="font-semibold text-niknax-600 dark:text-niknax-300">Edit Event Details</span>
            <span class="text-tx3 text-lg">{{ showEdit ? '▲' : '▼' }}</span>
          </button>

          <div v-if="showEdit" class="mt-5 space-y-5 border-t border-bd pt-5">
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label class="label">Event Name *</label>
                <input v-model="editForm.name" class="input" />
              </div>
              <div>
                <label class="label">Tagline</label>
                <input v-model="editForm.tagline" class="input" />
              </div>
            </div>
            <div>
              <label class="label">Description</label>
              <textarea v-model="editForm.description" class="input" rows="3" />
            </div>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label class="label">Event Link</label>
                <input v-model="editForm.district_link" class="input" type="url" placeholder="https://districtapp.tv/… or https://niknax.net/…" />
              </div>
              <div>
                <label class="label">Train Graphic</label>
                <ImageUpload
                  :current-url="editForm.cover_url"
                  @file-selected="editCoverFile = $event; editUploadPct = 0; editUploadStatus = ''"
                  @cleared="editForm.cover_url = null; editCoverFile = null; editUploadPct = 0; editUploadStatus = ''"
                />
                <div v-if="editUploadStatus" class="mt-2">
                  <div class="flex items-center justify-between text-xs text-tx3 mb-1">
                    <span>{{ editUploadStatus }}</span>
                    <span>{{ editUploadPct }}%</span>
                  </div>
                  <div class="w-full bg-sur2 rounded-full h-1.5">
                    <div
                      class="bg-niknax-500 h-1.5 rounded-full transition-all duration-200"
                      :style="{ width: editUploadPct + '%' }"
                    />
                  </div>
                </div>
              </div>
            </div>

            <!-- Day dates -->
            <div>
              <label class="label">Event Dates</label>
              <div class="space-y-2">
                <div v-for="day in days" :key="day.id" class="flex items-center gap-3">
                  <input
                    v-model="editDayDates[day.id]"
                    type="date"
                    class="input w-44"
                  />
                  <input
                    v-model="editDayLabels[day.id]"
                    class="input flex-1"
                    :placeholder="`Day ${day.day_order + 1} label (optional)`"
                  />
                </div>
              </div>
            </div>

            <div class="flex flex-col-reverse sm:flex-row gap-3 sm:justify-end">
              <button @click="showEdit = false" class="btn-secondary w-full sm:w-auto">Cancel</button>
              <button @click="saveDetails" :disabled="savingDetails" class="btn-primary w-full sm:w-auto">
                {{ editUploadStatus && editUploadPct < 100 ? editUploadStatus : savingDetails ? 'Saving…' : 'Save Changes' }}
              </button>
            </div>
            <p v-if="detailsSaved" class="text-green-400 text-sm text-right">✓ Saved</p>
          </div>
        </div>

        <!-- ── Schedule ── -->
        <div v-for="day in days" :key="day.id" class="mb-10">
          <h3 class="text-lg font-semibold text-niknax-600 dark:text-niknax-300 mb-4">
            {{ day.day_label ? `${day.day_label} — ` : '' }}{{ formatDate(day.day_date) }}
          </h3>

          <div class="card overflow-x-auto p-0">
            <p class="text-xs text-tx3 px-4 pt-3 pb-1">Drag a row to move or swap sellers between slots.</p>
            <table class="w-full text-sm">
              <thead>
                <tr class="bg-sur2 text-tx3">
                  <th class="px-3 py-3 w-6"></th>
                  <th class="text-left px-3 py-3 w-8">#</th>
                  <th class="text-left px-3 py-3">Username</th>
                  <th class="text-left px-3 py-3">ET</th>
                  <th class="text-left px-3 py-3">CT</th>
                  <th class="text-left px-3 py-3">MT</th>
                  <th class="text-left px-3 py-3">PT</th>
                  <th class="text-left px-3 py-3">Dur.</th>
                  <th class="text-left px-3 py-3">Type</th>
                  <th class="px-3 py-3 w-20"></th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-800">
                <tr
                  v-for="(slot, slotIdx) in slotsByDay[day.id] || []"
                  :key="slot.id"
                  :draggable="true"
                  @dragstart="onDragStart(slot, $event)"
                  @dragend="onDragEnd"
                  @dragover.prevent="onDragOver(slot)"
                  @dragleave="onDragLeave(slot)"
                  @drop.prevent="onDrop(slot)"
                  :class="[
                    slot.is_pre_assigned ? 'bg-niknax-950/40' : '',
                    dragOver === slot.id && dragSource?.id !== slot.id
                      ? 'bg-niknax-900/60 outline outline-2 outline-niknax-500' : '',
                    dragSource?.id === slot.id ? 'opacity-40' : '',
                  ]"
                  class="hover:bg-sur2/40 transition-colors cursor-grab active:cursor-grabbing"
                >
                  <!-- Drag handle -->
                  <td class="px-3 py-2.5 text-tx3 select-none text-base">⠿</td>
                  <td class="px-3 py-2.5 text-tx3 text-xs">{{ slotIdx + 1 }}</td>
                  <td class="px-3 py-2.5">
                    <span v-if="editingSlot === slot.id">
                      <input
                        v-model="editUsername"
                        class="input py-1 text-sm"
                        @keyup.enter="saveSlotUsername(slot)"
                        @keyup.escape="editingSlot = null"
                        autofocus
                      />
                    </span>
                    <span v-else class="flex items-center gap-2">
                      <span v-if="slot.username" class="text-tx1 font-medium">{{ slot.username }}</span>
                      <span v-else class="text-tx3 italic text-xs">— open —</span>
                      <span v-if="slot.label" class="text-xs text-niknax-400 bg-niknax-900/50 px-1.5 py-0.5 rounded">{{ slot.label }}</span>
                    </span>
                  </td>
                  <td class="px-3 py-2.5 text-tx1 font-bold text-base">{{ zones(slot.start_time)[0].time }}</td>
                  <td class="px-3 py-2.5 text-tx2 font-semibold">{{ zones(slot.start_time)[1].time }}</td>
                  <td class="px-3 py-2.5 text-tx2 font-semibold">{{ zones(slot.start_time)[2].time }}</td>
                  <td class="px-3 py-2.5 text-tx2 font-semibold">{{ zones(slot.start_time)[3].time }}</td>
                  <td class="px-3 py-2.5 text-tx3 text-xs">{{ slot.duration_min }}m</td>
                  <td class="px-3 py-2.5">
                    <button
                      type="button"
                      @click="toggleSlotReserved(slot)"
                      class="text-xs font-medium px-2 py-1 rounded-full border transition-colors"
                      :class="slot.is_pre_assigned
                        ? 'border-niknax-500 text-niknax-600 dark:text-niknax-300 bg-niknax-500/10 hover:bg-niknax-500/20'
                        : 'border-bd text-tx3 hover:text-tx1 hover:bg-sur2'"
                      :title="slot.is_pre_assigned ? 'Make this slot open for public signup' : 'Reserve this slot so it cannot be claimed publicly'"
                    >
                      {{ slot.is_pre_assigned ? 'Reserved' : 'Open' }}
                    </button>
                  </td>
                  <td class="px-3 py-2.5 text-right">
                    <span v-if="editingSlot === slot.id" class="flex gap-1 justify-end">
                      <button @click="saveSlotUsername(slot)" class="text-green-700 dark:text-green-400 text-xs font-medium">Save</button>
                      <button @click="editingSlot = null" class="text-tx3 text-xs">✕</button>
                    </span>
                    <button v-else @click="startEdit(slot)" class="text-niknax-600 hover:text-niknax-500 dark:text-niknax-400 dark:hover:text-niknax-300 text-xs">Edit</button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <button @click="addSlotToDay(day)" class="mt-3 w-full sm:w-auto text-sm text-niknax-600 hover:text-niknax-500 dark:text-niknax-400 dark:hover:text-niknax-300">
            + Add slot
          </button>
        </div>

        <!-- ── Danger zone ── -->
        <div class="card border-red-900 mt-10">
          <h4 class="text-red-600 dark:text-red-400 font-semibold text-sm mb-3">Danger Zone</h4>
          <button @click="confirmDelete" class="btn-danger text-sm w-full sm:w-auto">Delete Train</button>
        </div>
      </template>
    </main>

    <!-- ── Swap / Replace modal ── -->
    <Teleport to="body">
      <div v-if="dndModal" class="fixed inset-0 bg-black/70 flex items-center justify-center z-50 px-4" @click.self="dndModal = null">
        <div
          ref="dndModalRef"
          class="bg-surface border border-bd rounded-2xl p-6 w-full max-w-sm shadow-2xl space-y-4"
          role="dialog"
          aria-modal="true"
          aria-labelledby="move-seller-title"
          tabindex="-1"
        >
          <h3 id="move-seller-title" class="text-lg font-bold text-tx1">Move Seller</h3>

          <div class="space-y-1 text-sm">
            <p class="text-tx3">
              Moving <span class="text-tx1 font-semibold">{{ dndModal.source.username || '(empty)' }}</span>
              from <span class="text-tx2">{{ zones(dndModal.source.start_time)[0].time }} ET</span>
            </p>
            <p class="text-tx3">
              to <span class="text-tx2">{{ zones(dndModal.target.start_time)[0].time }} ET</span>
              currently held by <span class="text-tx1 font-semibold">{{ dndModal.target.username }}</span>
            </p>
          </div>

          <div class="space-y-2 pt-1">
            <button @click="doSwap" class="w-full btn-secondary text-left px-4">
              <span class="font-semibold">↕ Swap</span>
              <span class="block text-xs text-tx3 mt-0.5 font-normal">
                {{ dndModal.source.username }} → {{ zones(dndModal.target.start_time)[0].time }} ET &nbsp;·&nbsp;
                {{ dndModal.target.username }} → {{ zones(dndModal.source.start_time)[0].time }} ET
              </span>
            </button>
            <button @click="doReplace" class="w-full btn-danger text-left px-4">
              <span class="font-semibold">✕ Replace &amp; Remove</span>
              <span class="block text-xs text-red-50 mt-0.5 font-normal">
                {{ dndModal.source.username }} takes the slot · {{ dndModal.target.username }} is removed from the train
              </span>
            </button>
          </div>

          <button @click="dndModal = null" class="w-full text-tx3 hover:text-tx2 text-sm">Cancel</button>
        </div>
      </div>
    </Teleport>

    <!-- Add slot modal -->
    <div v-if="addSlotDay" class="fixed inset-0 bg-black/60 flex items-center justify-center z-50 px-4" @click.self="addSlotDay = null">
      <div
        ref="addSlotModalRef"
        class="bg-surface border border-bd rounded-xl p-6 w-full max-w-sm space-y-4"
        role="dialog"
        aria-modal="true"
        aria-labelledby="add-slot-title"
        tabindex="-1"
      >
        <h4 id="add-slot-title" class="font-semibold text-tx1">Add Slot</h4>
        <div>
          <label class="label" for="add-slot-username">Username (blank = open slot)</label>
          <input id="add-slot-username" v-model="newSlot.username" class="input" placeholder="@username" />
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="label" for="add-slot-start">Start Time (ET)</label>
            <input id="add-slot-start" v-model="newSlot.start_time" type="time" class="input" />
          </div>
          <div>
            <label class="label" for="add-slot-duration">Duration (min)</label>
            <input id="add-slot-duration" v-model.number="newSlot.duration_min" type="number" min="5" max="120" class="input" />
          </div>
        </div>
        <div>
          <label class="label" for="add-slot-label">Label (optional)</label>
          <input id="add-slot-label" v-model="newSlot.label" class="input" placeholder="Kickoff, Boost…" />
        </div>
        <label class="flex items-center gap-2 text-sm text-tx2 cursor-pointer">
          <input v-model="newSlot.is_pre_assigned" type="checkbox" class="rounded" />
          Reserved (cannot be claimed publicly)
        </label>
        <div class="flex flex-col-reverse sm:flex-row gap-3 sm:justify-end">
          <button @click="addSlotDay = null" class="btn-secondary w-full sm:w-auto">Cancel</button>
          <button @click="saveNewSlot" :disabled="savingSlot" class="btn-primary w-full sm:w-auto">
            {{ savingSlot ? '…' : 'Add Slot' }}
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
import ImageUpload from '../../components/ImageUpload.vue'
import { supabase, uploadWithProgress } from '../../lib/supabase.js'
import { allZones, formatDate, trainStatus, STATUS_BADGE_CLASS } from '../../lib/timeUtils.js'
import { useModalA11y } from '../../composables/useModalA11y.js'

const route  = useRoute()
const router = useRouter()

const train      = ref(null)
const days       = ref([])
const slots      = ref([])
const loading    = ref(true)
const publishing = ref(false)
const copied     = ref(false)

// Edit details
const showEdit      = ref(false)
const editForm      = ref({})
const editDayDates  = ref({})
const editDayLabels = ref({})
const savingDetails = ref(false)
const detailsSaved  = ref(false)
const editCoverFile   = ref(null)  // new image file selected in edit mode
const editUploadPct   = ref(0)
const editUploadStatus = ref('')

async function uploadCover(trainId) {
  if (!editCoverFile.value) return null
  const extByType = { 'image/png': 'png', 'image/jpeg': 'jpg', 'image/gif': 'gif', 'image/webp': 'webp' }
  const ext  = extByType[editCoverFile.value.type]
  if (!ext) throw new Error('Unsupported image type.')
  const path = `${trainId}/cover.${ext}`
  editUploadPct.value    = 0
  editUploadStatus.value = 'Uploading graphic…'
  const url = await uploadWithProgress('train-graphics', path, editCoverFile.value, (pct) => {
    editUploadPct.value = pct
  })
  editUploadPct.value    = 100
  editUploadStatus.value = 'Graphic uploaded ✓'
  return url
}

// Slot editing
const editingSlot  = ref(null)
const editUsername = ref('')
const addSlotDay   = ref(null)
const { modalRef: addSlotModalRef } = useModalA11y(
  () => !!addSlotDay.value,
  () => { addSlotDay.value = null }
)
const savingSlot   = ref(false)
const newSlot = ref({ username: '', start_time: '12:00', duration_min: 30, label: '', is_pre_assigned: false })

// Drag-and-drop
const dragSource = ref(null)   // slot object being dragged
const dragOver   = ref(null)   // slot id currently hovered over
const dndModal   = ref(null)   // { source, target } when swap/replace needed
const { modalRef: dndModalRef } = useModalA11y(
  () => !!dndModal.value,
  () => { dndModal.value = null }
)

function onDragStart(slot, event) {
  dragSource.value = slot
  event.dataTransfer.effectAllowed = 'move'
}
function onDragEnd() {
  dragSource.value = null
  dragOver.value   = null
}
function onDragOver(slot) {
  if (dragSource.value && dragSource.value.id !== slot.id) {
    dragOver.value = slot.id
  }
}
function onDragLeave(slot) {
  if (dragOver.value === slot.id) dragOver.value = null
}

async function onDrop(target) {
  dragOver.value = null
  const source = dragSource.value
  dragSource.value = null
  if (!source || source.id === target.id) return

  // If target is empty, just move source there silently
  if (!target.username) {
    await applyMove(source, target.username ?? null, target, source.username)
    return
  }

  // Both slots have users — ask swap or replace
  dndModal.value = { source, target }
}

async function doSwap() {
  const { source, target } = dndModal.value
  dndModal.value = null
  await applyMove(source, target.username, target, source.username)
}

async function doReplace() {
  const { source, target } = dndModal.value
  dndModal.value = null
  await applyMove(source, null, target, source.username)
}

async function applyMove(source, newSourceUsername, target, newTargetUsername) {
  // Update DB
  await Promise.all([
    supabase.from('slots').update({ username: newSourceUsername }).eq('id', source.id),
    supabase.from('slots').update({ username: newTargetUsername }).eq('id', target.id),
  ])
  // Update local state
  const srcSlot = slots.value.find(s => s.id === source.id)
  const tgtSlot = slots.value.find(s => s.id === target.id)
  if (srcSlot) srcSlot.username = newSourceUsername
  if (tgtSlot) tgtSlot.username = newTargetUsername
}

const publicUrl = computed(() => `${location.origin}/train/${train.value?.id}`)

const statusBadge = computed(() => {
  const s = trainStatus(train.value, slots.value.length, slots.value.filter(sl => sl.username).length)
  return { label: s.label, class: `badge-${STATUS_BADGE_CLASS[s.key]}` }
})

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

  const { data: t } = await supabase.from('trains').select('*').eq('id', id).single()
  train.value = t

  if (t) {
    editForm.value = { name: t.name, tagline: t.tagline || '', description: t.description || '', district_link: t.district_link || '', cover_url: t.cover_url || '' }

    const { data: d } = await supabase.from('train_days').select('*').eq('train_id', id).order('day_order')
    days.value = d || []

    // Initialise editable day dates/labels
    for (const day of days.value) {
      editDayDates.value[day.id]  = day.day_date
      editDayLabels.value[day.id] = day.day_label || ''
    }

    if (days.value.length) {
      const dayIds = days.value.map(d => d.id)
      const { data: s } = await supabase.from('slots').select('*').in('train_day_id', dayIds).order('slot_order')
      slots.value = s || []
    }
  }
  loading.value = false
}

async function saveDetails() {
  savingDetails.value = true

  // Upload new graphic if one was selected (non-fatal)
  if (editCoverFile.value) {
    try {
      const url = await uploadCover(train.value.id)
      if (url) editForm.value.cover_url = url
    } catch (uploadErr) {
      // Show inline warning but don't abort the save
      detailsSaved.value = false
      console.error('Image upload failed:', uploadErr.message)
      alert(`Graphic upload failed: ${uploadErr.message}\n\nMake sure the "train-graphics" bucket exists in Supabase Storage and the admin storage policies are installed.`)
    }
    editCoverFile.value = null
  }

  await supabase.from('trains').update({
    name: editForm.value.name,
    tagline: editForm.value.tagline || null,
    description: editForm.value.description || null,
    district_link: editForm.value.district_link || null,
    cover_url: editForm.value.cover_url || null,
  }).eq('id', train.value.id)

  // Update day dates + labels
  for (const day of days.value) {
    await supabase.from('train_days').update({
      day_date: editDayDates.value[day.id],
      day_label: editDayLabels.value[day.id] || null,
    }).eq('id', day.id)
    day.day_date  = editDayDates.value[day.id]
    day.day_label = editDayLabels.value[day.id] || null
  }

  Object.assign(train.value, editForm.value)
  savingDetails.value = false
  detailsSaved.value = true
  setTimeout(() => { detailsSaved.value = false; showEdit.value = false }, 1500)
}

async function toggleUpcoming() {
  const val = !train.value.is_upcoming
  await supabase.from('trains').update({ is_upcoming: val }).eq('id', train.value.id)
  train.value.is_upcoming = val
}

async function publish() {
  publishing.value = true
  await supabase.from('trains').update({ published: true, is_upcoming: false }).eq('id', train.value.id)
  train.value.published   = true
  train.value.is_upcoming = false
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
  const { error } = await supabase.from('slots').update({ username: editUsername.value || null }).eq('id', slot.id)
  if (!error) { slot.username = editUsername.value || null; editingSlot.value = null }
}

async function toggleSlotReserved(slot) {
  const makeReserved = !slot.is_pre_assigned
  const patch = { is_pre_assigned: makeReserved }

  if (!makeReserved && slot.username) {
    const ok = confirm(`Make this slot open and remove "${slot.username}" from it?`)
    if (!ok) return
    patch.username = null
  }

  const { error } = await supabase.from('slots').update(patch).eq('id', slot.id)
  if (!error) {
    slot.is_pre_assigned = makeReserved
    if ('username' in patch) slot.username = null
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
  if (!error) { slots.value.push(data); addSlotDay.value = null }
  savingSlot.value = false
}

async function confirmDelete() {
  if (!confirm(`Delete "${train.value.name}"? This cannot be undone.`)) return
  await supabase.from('trains').delete().eq('id', train.value.id)
  router.push('/admin/dashboard')
}

onMounted(load)
</script>
