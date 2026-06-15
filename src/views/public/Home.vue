<template>
  <div class="min-h-screen bg-gray-950">
    <!-- Nav -->
    <header class="border-b border-gray-800 px-6 py-4 flex items-center justify-between">
      <div class="flex items-center gap-2">
        <span class="text-2xl">✨</span>
        <span class="font-bold text-lg font-display">Niknax Raid Trains</span>
      </div>
      <RouterLink to="/admin" class="text-gray-500 hover:text-gray-300 text-xs">Admin</RouterLink>
    </header>

    <main class="max-w-3xl mx-auto px-6 py-16 text-center">
      <div class="text-6xl mb-4">🚂✨</div>
      <h1 class="text-4xl font-bold font-display mb-3 bg-gradient-to-r from-niknax-300 to-gold-400 bg-clip-text text-transparent">
        Niknax Raid Trains
      </h1>
      <p class="text-gray-400 text-lg mb-12">
        Hop on an upcoming live-selling train on District.
      </p>

      <!-- Setup notice -->
    <div v-if="!isSupabaseConfigured" class="max-w-xl mx-auto mb-8 bg-amber-900/40 border border-amber-700 rounded-xl px-5 py-4 text-left">
      <p class="font-semibold text-amber-300 mb-1">⚙️ Supabase not connected yet</p>
      <p class="text-amber-200/80 text-sm">
        Copy <code class="bg-amber-900/60 px-1 rounded">.env.example</code> to
        <code class="bg-amber-900/60 px-1 rounded">.env.local</code> and fill in your
        Supabase URL, anon key, and admin PIN, then restart the dev server.
      </p>
    </div>

    <div v-if="loading" class="text-gray-500">Loading events…</div>

      <div v-else-if="trains.length === 0" class="text-gray-500">
        No upcoming events right now. Check back soon!
      </div>

      <div v-else class="space-y-4 text-left">
        <RouterLink
          v-for="train in trains"
          :key="train.id"
          :to="`/train/${train.id}`"
          class="block card hover:border-niknax-600 transition-colors group"
        >
          <div class="flex items-center gap-4">
            <img
              v-if="train.cover_url"
              :src="train.cover_url"
              class="w-16 h-16 rounded-lg object-cover shrink-0"
              alt=""
            />
            <div v-else class="w-16 h-16 rounded-lg bg-niknax-900 flex items-center justify-center text-2xl shrink-0">
              🚂
            </div>
            <div class="flex-1 min-w-0">
              <h2 class="font-bold text-white group-hover:text-niknax-300 transition-colors truncate">
                {{ train.name }}
              </h2>
              <p v-if="train.tagline" class="text-gray-400 text-sm truncate">{{ train.tagline }}</p>
              <p v-if="train.days?.length" class="text-gray-500 text-xs mt-1">
                {{ formatDays(train.days) }}
              </p>
            </div>
            <span class="text-niknax-400 group-hover:translate-x-1 transition-transform text-lg">→</span>
          </div>
        </RouterLink>
      </div>
    </main>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import { supabase, isSupabaseConfigured } from '../../lib/supabase.js'
import { formatDate } from '../../lib/timeUtils.js'

const trains  = ref([])
const loading = ref(true)

function formatDays(days) {
  if (!days?.length) return ''
  const dates = days.map(d => formatDate(d.day_date))
  if (dates.length === 1) return dates[0]
  return `${dates[0]} – ${dates[dates.length - 1]}`
}

async function load() {
  const { data: trainData } = await supabase
    .from('trains')
    .select('*, days:train_days(day_date)')
    .eq('published', true)
    .order('created_at', { ascending: false })

  trains.value  = trainData || []
  loading.value = false
}

onMounted(load)
</script>
