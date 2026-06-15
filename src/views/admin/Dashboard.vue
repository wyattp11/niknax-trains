<template>
  <div class="min-h-screen bg-gray-950">
    <!-- Header -->
    <header class="bg-gray-900 border-b border-gray-800 px-6 py-4 flex items-center justify-between">
      <div class="flex items-center gap-3">
        <span class="text-2xl">✨</span>
        <h1 class="text-lg font-bold text-white font-display">Niknax Train Admin</h1>
      </div>
      <div class="flex items-center gap-4">
        <RouterLink to="/" class="text-gray-400 hover:text-white text-sm">Public site ↗</RouterLink>
        <button @click="logout" class="text-gray-400 hover:text-white text-sm">Sign out</button>
      </div>
    </header>

    <main class="max-w-4xl mx-auto px-6 py-10">
      <div class="flex items-center justify-between mb-8">
        <h2 class="text-2xl font-bold">Raid Trains</h2>
        <RouterLink to="/admin/trains/new" class="btn-primary">
          + New Train
        </RouterLink>
      </div>

      <!-- Loading -->
      <div v-if="loading" class="text-gray-400 text-center py-16">Loading…</div>

      <!-- Empty -->
      <div v-else-if="trains.length === 0" class="card text-center py-16">
        <div class="text-5xl mb-4">🚂</div>
        <p class="text-gray-300 text-lg mb-2">No trains yet</p>
        <p class="text-gray-500 mb-6">Create your first raid train event.</p>
        <RouterLink to="/admin/trains/new" class="btn-primary">Create Train</RouterLink>
      </div>

      <!-- Train list -->
      <div v-else class="space-y-4">
        <div
          v-for="train in trains"
          :key="train.id"
          class="card flex items-center gap-4"
        >
          <!-- Thumbnail -->
          <img
            v-if="train.cover_url"
            :src="train.cover_url"
            class="w-14 h-14 rounded-lg object-cover shrink-0"
            alt=""
          />
          <div v-else class="w-14 h-14 rounded-lg bg-niknax-900/60 flex items-center justify-center text-2xl shrink-0">
            🚂
          </div>

          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 mb-1 flex-wrap">
              <span
                :class="train.published
                  ? 'bg-green-900 text-green-300'
                  : train.is_upcoming
                    ? 'bg-amber-900 text-amber-300'
                    : 'bg-gray-700 text-gray-300'"
                class="text-xs font-semibold px-2 py-0.5 rounded-full shrink-0"
              >
                {{ train.published ? 'LIVE' : train.is_upcoming ? 'UPCOMING' : 'DRAFT' }}
              </span>
              <h3 class="font-semibold text-white truncate">{{ train.name }}</h3>
            </div>
            <p class="text-sm text-gray-400">
              Created {{ formatDate(train.created_at) }}
            </p>
          </div>
          <div class="flex gap-2 shrink-0">
            <RouterLink
              :to="`/train/${train.id}`"
              target="_blank"
              class="btn-secondary text-sm py-1.5"
            >
              View
            </RouterLink>
            <RouterLink :to="`/admin/trains/${train.id}`" class="btn-primary text-sm py-1.5">
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
import { RouterLink, useRouter } from 'vue-router'
import { useAuthStore } from '../../stores/auth.js'
import { supabase } from '../../lib/supabase.js'

const auth   = useAuthStore()
const router = useRouter()
const trains  = ref([])
const loading = ref(true)

async function loadTrains() {
  loading.value = true
  const { data, error } = await supabase
    .from('trains')
    .select('*')
    .order('created_at', { ascending: false })
  if (!error) trains.value = data
  loading.value = false
}

function formatDate(iso) {
  return new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
}

function logout() {
  auth.logout()
  router.push('/admin')
}

onMounted(loadTrains)
</script>
