<template>
  <div class="min-h-screen bg-base">
    <AdminNav />

    <main class="max-w-5xl mx-auto px-6 py-10">
      <div class="flex items-center justify-between mb-2 flex-wrap gap-3">
        <h2 class="text-2xl font-bold text-tx1">Members</h2>
        <div class="flex gap-2">
          <button class="btn-secondary text-sm py-1.5" @click="openUpload">Upload CSV</button>
          <button class="btn-primary text-sm py-1.5" @click="openAdd">+ Add Member</button>
        </div>
      </div>
      <p class="text-sm text-tx3 mb-6">
        {{ totalCount.toLocaleString() }} members &middot; {{ canGoLiveCount.toLocaleString() }} can go live
      </p>

      <!-- Search + filter -->
      <div class="flex items-center gap-3 mb-4 flex-wrap">
        <input
          v-model="search"
          type="text"
          placeholder="Search username, name, or email…"
          class="input max-w-sm"
        />
        <label class="flex items-center gap-2 text-sm text-tx2 select-none cursor-pointer">
          <input type="checkbox" v-model="onlyCanGoLive" class="accent-niknax-600" />
          Can go live only
        </label>
        <span v-if="saveError" class="text-sm text-teal-600">{{ saveError }}</span>
      </div>

      <!-- Table -->
      <div class="card overflow-x-auto p-0">
        <table class="w-full text-sm">
          <thead>
            <tr class="border-b border-bd text-left text-tx3">
              <th class="px-4 py-3 font-medium">Username</th>
              <th class="px-4 py-3 font-medium">Full name</th>
              <th class="px-4 py-3 font-medium">Email</th>
              <th class="px-4 py-3 font-medium text-center">Can go live</th>
              <th class="px-4 py-3 font-medium"></th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="loading">
              <td colspan="5" class="px-4 py-10 text-center text-tx3">Loading…</td>
            </tr>
            <tr v-else-if="rows.length === 0">
              <td colspan="5" class="px-4 py-10 text-center text-tx3">No members match.</td>
            </tr>
            <tr
              v-for="row in rows"
              :key="row.id"
              class="border-b border-bd last:border-0"
            >
              <td class="px-4 py-2 font-medium text-tx1 whitespace-nowrap">{{ row.username }}</td>
              <td class="px-4 py-2">
                <input
                  v-model="row.full_name"
                  class="input py-1"
                  @blur="saveField(row, 'full_name')"
                  @keyup.enter="saveField(row, 'full_name')"
                />
              </td>
              <td class="px-4 py-2">
                <input
                  v-model="row.email"
                  type="email"
                  class="input py-1"
                  @blur="saveField(row, 'email')"
                  @keyup.enter="saveField(row, 'email')"
                />
              </td>
              <td class="px-4 py-2 text-center">
                <input
                  type="checkbox"
                  class="accent-niknax-600 w-4 h-4"
                  :checked="row.can_go_live"
                  @change="toggleCanGoLive(row, $event.target.checked)"
                />
              </td>
              <td class="px-4 py-2 text-right whitespace-nowrap">
                <button class="text-teal-600 hover:text-teal-700 text-xs font-medium" @click="confirmDelete(row)">
                  Delete
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Pagination -->
      <div class="flex items-center justify-between mt-4 text-sm text-tx3">
        <span>Page {{ page + 1 }} of {{ totalPages }}</span>
        <div class="flex gap-2">
          <button class="btn-secondary text-sm py-1.5" :disabled="page === 0" @click="page--">Prev</button>
          <button class="btn-secondary text-sm py-1.5" :disabled="page >= totalPages - 1" @click="page++">Next</button>
        </div>
      </div>
    </main>

    <!-- Add member modal -->
    <div v-if="showAdd" class="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50" @click.self="showAdd = false">
      <div class="card max-w-md w-full space-y-4">
        <h3 class="text-lg font-bold text-tx1">Add Member</h3>
        <div>
          <label class="label">Username *</label>
          <input v-model="newMember.username" class="input" placeholder="@username" />
        </div>
        <div>
          <label class="label">Full name</label>
          <input v-model="newMember.full_name" class="input" />
        </div>
        <div>
          <label class="label">Email</label>
          <input v-model="newMember.email" type="email" class="input" />
        </div>
        <label class="flex items-center gap-2 text-sm text-tx2 select-none cursor-pointer">
          <input type="checkbox" v-model="newMember.can_go_live" class="accent-niknax-600" />
          Can go live
        </label>
        <p v-if="addError" class="text-sm text-teal-600">{{ addError }}</p>
        <div class="flex justify-end gap-2 pt-2">
          <button class="btn-secondary" @click="showAdd = false">Cancel</button>
          <button class="btn-primary" :disabled="adding" @click="addMember">
            {{ adding ? 'Adding…' : 'Add Member' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Upload CSV modal -->
    <div v-if="showUpload" class="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50" @click.self="closeUpload">
      <div class="card max-w-lg w-full space-y-4">
        <h3 class="text-lg font-bold text-tx1">Upload Members CSV</h3>
        <p class="text-sm text-tx3">
          Header row required. Recognized columns (any order, case-insensitive): <span class="font-mono text-xs">username</span> (required),
          <span class="font-mono text-xs">full_name</span> / <span class="font-mono text-xs">name</span>,
          <span class="font-mono text-xs">email</span>,
          <span class="font-mono text-xs">phone</span> / <span class="font-mono text-xs">phone number</span>,
          <span class="font-mono text-xs">joined_at</span> / <span class="font-mono text-xs">joined</span>,
          <span class="font-mono text-xs">role</span>,
          <span class="font-mono text-xs">can_go_live</span> / <span class="font-mono text-xs">can go live</span> (Yes/No or true/false),
          <span class="font-mono text-xs">sales</span>, <span class="font-mono text-xs">spend</span>.
          Existing usernames are updated; new usernames are added.
        </p>

        <input
          ref="fileInput"
          type="file"
          accept=".csv,text/csv"
          class="block w-full text-sm text-tx2"
          :disabled="uploading"
          @change="onFileSelected"
        />

        <div v-if="uploading" class="space-y-1">
          <div class="w-full bg-sur2 rounded-full h-2 overflow-hidden">
            <div
              class="bg-niknax-600 h-2 transition-all"
              :style="{ width: uploadTotal ? (100 * uploadDone / uploadTotal) + '%' : '0%' }"
            ></div>
          </div>
          <p class="text-xs text-tx3">Uploading {{ uploadDone.toLocaleString() }} / {{ uploadTotal.toLocaleString() }}…</p>
        </div>

        <p v-if="uploadError" class="text-sm text-teal-600">{{ uploadError }}</p>
        <p v-if="uploadSummary" class="text-sm text-tx2">{{ uploadSummary }}</p>

        <div class="flex justify-end gap-2 pt-2">
          <button class="btn-secondary" :disabled="uploading" @click="closeUpload">
            {{ uploadSummary ? 'Close' : 'Cancel' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, watch, computed, onMounted } from 'vue'
import AdminNav from '../../components/AdminNav.vue'
import { supabase } from '../../lib/supabase.js'

const PAGE_SIZE = 50

const rows           = ref([])
const loading         = ref(true)
const search          = ref('')
const onlyCanGoLive    = ref(false)
const page             = ref(0)
const totalCount       = ref(0)
const canGoLiveCount   = ref(0)
const saveError        = ref('')

const totalPages = computed(() => Math.max(1, Math.ceil(totalCount.value / PAGE_SIZE)))

let searchTimer = null
watch(search, () => {
  clearTimeout(searchTimer)
  searchTimer = setTimeout(() => { page.value = 0; loadMembers() }, 300)
})
watch(onlyCanGoLive, () => { page.value = 0; loadMembers() })
watch(page, loadMembers)

async function loadMembers() {
  loading.value = true
  saveError.value = ''

  let query = supabase
    .from('members')
    .select('id, username, full_name, email, can_go_live', { count: 'exact' })
    .order('username')

  const term = search.value.trim()
  if (term) {
    query = query.or(`username.ilike.%${term}%,full_name.ilike.%${term}%,email.ilike.%${term}%`)
  }
  if (onlyCanGoLive.value) {
    query = query.eq('can_go_live', true)
  }

  const from = page.value * PAGE_SIZE
  query = query.range(from, from + PAGE_SIZE - 1)

  const { data, error, count } = await query
  if (!error) {
    rows.value = data
    totalCount.value = count ?? 0
  } else {
    saveError.value = 'Failed to load members.'
  }
  loading.value = false
}

async function loadCanGoLiveCount() {
  const { count } = await supabase
    .from('members')
    .select('id', { count: 'exact', head: true })
    .eq('can_go_live', true)
  canGoLiveCount.value = count ?? 0
}

async function saveField(row, field) {
  const { error } = await supabase
    .from('members')
    .update({ [field]: row[field], updated_at: new Date().toISOString() })
    .eq('id', row.id)
  if (error) saveError.value = `Failed to save ${field}.`
}

async function toggleCanGoLive(row, value) {
  row.can_go_live = value
  const { error } = await supabase
    .from('members')
    .update({ can_go_live: value, updated_at: new Date().toISOString() })
    .eq('id', row.id)
  if (error) {
    row.can_go_live = !value
    saveError.value = 'Failed to update can go live.'
  } else {
    loadCanGoLiveCount()
  }
}

async function confirmDelete(row) {
  if (!window.confirm(`Delete member "${row.username}"? This cannot be undone.`)) return
  const { error } = await supabase.from('members').delete().eq('id', row.id)
  if (error) {
    saveError.value = 'Failed to delete member.'
  } else {
    rows.value = rows.value.filter(r => r.id !== row.id)
    totalCount.value = Math.max(0, totalCount.value - 1)
    loadCanGoLiveCount()
  }
}

// ── Add member ──────────────────────────────────────────
const showAdd  = ref(false)
const adding   = ref(false)
const addError = ref('')
const newMember = ref({ username: '', full_name: '', email: '', can_go_live: false })

function openAdd() {
  newMember.value = { username: '', full_name: '', email: '', can_go_live: false }
  addError.value = ''
  showAdd.value = true
}

async function addMember() {
  const username = newMember.value.username.trim().replace(/^@/, '')
  if (!username) {
    addError.value = 'Username is required.'
    return
  }
  adding.value = true
  addError.value = ''
  const { error } = await supabase.from('members').insert({
    username,
    full_name: newMember.value.full_name.trim() || null,
    email: newMember.value.email.trim() || null,
    can_go_live: newMember.value.can_go_live,
  })
  adding.value = false
  if (error) {
    addError.value = error.code === '23505' ? 'That username already exists.' : 'Failed to add member.'
    return
  }
  showAdd.value = false
  page.value = 0
  loadMembers()
  loadCanGoLiveCount()
}

onMounted(() => {
  loadMembers()
  loadCanGoLiveCount()
})

// ── Upload CSV ────────────────────────────────────────────
const showUpload    = ref(false)
const uploading      = ref(false)
const uploadError    = ref('')
const uploadSummary  = ref('')
const uploadDone     = ref(0)
const uploadTotal    = ref(0)
const fileInput      = ref(null)
const BATCH_SIZE = 500

function openUpload() {
  uploadError.value = ''
  uploadSummary.value = ''
  uploadDone.value = 0
  uploadTotal.value = 0
  showUpload.value = true
}

function closeUpload() {
  if (uploading.value) return
  showUpload.value = false
  if (fileInput.value) fileInput.value.value = ''
}

// Minimal RFC4180-style CSV parser: handles quoted fields, escaped quotes ("")
// commas/newlines inside quotes, and CRLF/LF line endings.
function parseCsv(text) {
  const rows = []
  let row = []
  let field = ''
  let inQuotes = false
  let i = 0
  const len = text.length

  while (i < len) {
    const c = text[i]
    if (inQuotes) {
      if (c === '"') {
        if (text[i + 1] === '"') { field += '"'; i += 2; continue }
        inQuotes = false; i++; continue
      }
      field += c; i++; continue
    }
    if (c === '"') { inQuotes = true; i++; continue }
    if (c === ',') { row.push(field); field = ''; i++; continue }
    if (c === '\r') { i++; continue }
    if (c === '\n') {
      row.push(field); field = ''
      rows.push(row); row = []
      i++; continue
    }
    field += c; i++
  }
  // final field/row (if file doesn't end with newline)
  if (field.length || row.length) { row.push(field); rows.push(row) }

  return rows.filter(r => !(r.length === 1 && r[0] === ''))
}

function normalizeHeader(h) {
  return h.trim().toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '')
}

const HEADER_ALIASES = {
  username:     ['username'],
  full_name:    ['full_name', 'name'],
  email:        ['email'],
  phone:        ['phone', 'phone_number'],
  joined_at:    ['joined_at', 'joined'],
  role:         ['role'],
  can_go_live:  ['can_go_live', 'cangolive'],
  sales:        ['sales'],
  spend:        ['spend'],
}

function resolveFieldMap(headers) {
  const normalized = headers.map(normalizeHeader)
  const map = {} // field -> column index
  for (const [field, aliases] of Object.entries(HEADER_ALIASES)) {
    const idx = normalized.findIndex(h => aliases.includes(h))
    if (idx !== -1) map[field] = idx
  }
  return map
}

function toBool(v) {
  if (v == null) return false
  const s = String(v).trim().toLowerCase()
  return s === 'yes' || s === 'true' || s === '1'
}

function toNumber(v) {
  if (v == null) return 0
  const n = parseFloat(String(v).replace(/[^0-9.-]/g, ''))
  return Number.isFinite(n) ? n : 0
}

function toTimestamp(v) {
  if (!v) return null
  const s = String(v).trim()
  if (!s) return null
  const d = new Date(s)
  return isNaN(d.getTime()) ? null : d.toISOString()
}

function onFileSelected(e) {
  const file = e.target.files?.[0]
  if (!file) return
  uploadError.value = ''
  uploadSummary.value = ''

  const reader = new FileReader()
  reader.onload = async () => {
    try {
      await processCsvText(String(reader.result || ''))
    } catch (err) {
      uploadError.value = 'Failed to parse or upload CSV: ' + (err?.message || err)
      uploading.value = false
    }
  }
  reader.onerror = () => {
    uploadError.value = 'Failed to read file.'
  }
  reader.readAsText(file)
}

async function processCsvText(text) {
  const table = parseCsv(text)
  if (table.length < 2) {
    uploadError.value = 'CSV appears to be empty.'
    return
  }
  const headers = table[0]
  const fieldMap = resolveFieldMap(headers)
  if (fieldMap.username === undefined) {
    uploadError.value = 'CSV must include a "username" column.'
    return
  }

  const dataRows = table.slice(1)
  const members = []
  for (const r of dataRows) {
    const username = (r[fieldMap.username] || '').trim().replace(/^@/, '')
    if (!username) continue
    const m = { username }
    if (fieldMap.full_name !== undefined)   m.full_name   = r[fieldMap.full_name]?.trim() || null
    if (fieldMap.email !== undefined)       m.email       = r[fieldMap.email]?.trim() || null
    if (fieldMap.phone !== undefined)       m.phone       = r[fieldMap.phone]?.trim() || null
    if (fieldMap.joined_at !== undefined)   m.joined_at   = toTimestamp(r[fieldMap.joined_at])
    if (fieldMap.role !== undefined)        m.role        = r[fieldMap.role]?.trim() || null
    if (fieldMap.can_go_live !== undefined) m.can_go_live = toBool(r[fieldMap.can_go_live])
    if (fieldMap.sales !== undefined)       m.sales       = toNumber(r[fieldMap.sales])
    if (fieldMap.spend !== undefined)       m.spend       = toNumber(r[fieldMap.spend])
    m.updated_at = new Date().toISOString()
    members.push(m)
  }

  if (!members.length) {
    uploadError.value = 'No valid rows with a username were found.'
    return
  }

  uploading.value = true
  uploadDone.value = 0
  uploadTotal.value = members.length

  let failedBatches = 0
  for (let i = 0; i < members.length; i += BATCH_SIZE) {
    const chunk = members.slice(i, i + BATCH_SIZE)
    const { error } = await supabase.from('members').upsert(chunk, { onConflict: 'username' })
    if (error) failedBatches++
    uploadDone.value = Math.min(members.length, i + chunk.length)
  }

  uploading.value = false
  uploadSummary.value = failedBatches
    ? `Uploaded with ${failedBatches} batch error(s) out of ${Math.ceil(members.length / BATCH_SIZE)}. Some rows may not have saved.`
    : `Uploaded ${members.length.toLocaleString()} members successfully.`

  page.value = 0
  loadMembers()
  loadCanGoLiveCount()
}
</script>
