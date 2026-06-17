<template>
  <div class="min-h-screen bg-base">
    <AdminNav />

    <main class="max-w-5xl mx-auto px-6 py-10">
      <div class="flex items-center justify-between mb-2 flex-wrap gap-3">
        <h2 class="text-2xl font-bold text-tx1">Members</h2>
        <button class="btn-primary text-sm py-1.5" @click="openAdd">+ Add Member</button>
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
</script>
