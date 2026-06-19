<template>
  <div class="min-h-screen bg-base">
    <AdminNav />

    <main class="max-w-4xl mx-auto px-6 py-10">
      <div class="flex items-center justify-between mb-8">
        <h2 class="text-2xl font-bold text-tx1">Raid Trains</h2>
      </div>

      <!-- Loading -->
      <div v-if="loading" class="text-tx3 text-center py-16">Loading…</div>

      <!-- Empty -->
      <div v-else-if="trains.length === 0" class="card text-center py-16">
        <div class="text-5xl mb-4">🚂</div>
        <p class="text-tx1 text-lg mb-2">No trains yet</p>
        <p class="text-tx3 mb-6">Create your first raid train event.</p>
        <RouterLink to="/admin/trains/new" class="btn-primary">Create Train</RouterLink>
      </div>

      <!-- Train list -->
      <div v-else class="space-y-4">
        <div
          v-for="train in trains"
          :key="train.id"
          class="card flex flex-col sm:flex-row sm:items-center gap-4"
        >
          <!-- Thumbnail -->
          <img
            v-if="train.cover_url"
            :src="train.cover_url"
            class="w-28 h-28 rounded-lg object-cover shrink-0"
            alt=""
          />
          <div v-else class="w-28 h-28 rounded-lg bg-niknax-900/40 flex items-center justify-center text-5xl shrink-0" aria-hidden="true">
            🚂
          </div>

          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 mb-1 flex-wrap">
              <span :class="`badge-${statusBadgeClass(train)}`">
                {{ status(train).label }}
              </span>
              <h3 class="font-semibold text-tx1 truncate">{{ train.name }}</h3>
            </div>
            <p class="text-sm text-tx3">Created {{ formatDate(train.created_at) }}</p>
          </div>

          <div class="flex flex-col sm:flex-row gap-2 shrink-0 w-full sm:w-auto">
            <RouterLink :to="`/train/${train.id}`" target="_blank" class="btn-secondary text-sm py-1.5 text-center whitespace-nowrap">
              View
            </RouterLink>
            <RouterLink :to="`/admin/trains/${train.id}`" class="btn-primary text-sm py-1.5 text-center whitespace-nowrap">
              Manage
            </RouterLink>
          </div>
        </div>
      </div>
    </main>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import AdminNav from '../../components/AdminNav.vue'
import { supabase } from '../../lib/supabase.js'
import { trainStatus, STATUS_BADGE_CLASS } from '../../lib/timeUtils.js'

const trains  = ref([])
const loading = ref(true)

async function loadTrains() {
  loading.value = true
  const { data, error } = await supabase
    .from('trains')
    .select('*, days:train_days(slots(id, username))')
    .order('created_at', { ascending: false })
  if (!error) trains.value = data
  loading.value = false
}

function slotCounts(train) {
  const slots = (train.days || []).flatMap(d => d.slots || [])
  return { total: slots.length, filled: slots.filter(s => s.username).length }
}

function status(train) {
  const { total, filled } = slotCounts(train)
  return trainStatus(train, total, filled)
}

function statusBadgeClass(train) {
  return STATUS_BADGE_CLASS[status(train).key]
}

function formatDate(iso) {
  return new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
}

onMounted(loadTrains)
</script>
