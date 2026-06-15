<template>
  <div class="min-h-screen bg-gray-950">
    <!-- Nav -->
    <header class="border-b border-gray-800 px-6 py-4 flex items-center justify-between">
      <div class="flex items-center gap-2">
        <span class="text-2xl">✨</span>
        <span class="font-bold text-lg font-display">Niknax Raid Trains</span>
      </div>
      <RouterLink to="/admin" class="text-gray-600 hover:text-gray-400 text-xs">Admin</RouterLink>
    </header>

    <!-- Hero -->
    <div class="bg-gradient-to-br from-niknax-900/40 via-gray-950 to-gray-950 border-b border-gray-800 px-6 py-10 text-center">
      <div class="text-5xl mb-3">🚂✨</div>
      <h1 class="text-3xl sm:text-4xl font-bold font-display mb-2 bg-gradient-to-r from-niknax-300 to-gold-400 bg-clip-text text-transparent">
        Niknax Raid Trains
      </h1>
      <p class="text-gray-400 max-w-md mx-auto">Back-to-back live selling events on District. Hop on a train and ride the raid!</p>
    </div>

    <main class="max-w-5xl mx-auto px-4 sm:px-6 py-10 space-y-12">

      <!-- Setup notice -->
      <div v-if="!isSupabaseConfigured" class="bg-amber-900/40 border border-amber-700 rounded-xl px-5 py-4">
        <p class="font-semibold text-amber-300 mb-1">⚙️ Supabase not connected yet</p>
        <p class="text-amber-200/80 text-sm">
          Copy <code class="bg-amber-900/60 px-1 rounded">.env.example</code> to
          <code class="bg-amber-900/60 px-1 rounded">.env.local</code>, fill in your Supabase credentials, and restart.
        </p>
      </div>

      <!-- Upcoming / Live events list -->
      <section>
        <h2 class="text-xl font-bold text-white mb-4">Events</h2>

        <div v-if="loading" class="text-gray-500 text-sm">Loading…</div>

        <div v-else-if="events.length === 0" class="card text-center py-10">
          <p class="text-gray-500">No upcoming events right now. Check back soon!</p>
        </div>

        <div v-else class="space-y-3">
          <component
            :is="ev.published ? RouterLink : 'div'"
            v-for="ev in events"
            :key="ev.id"
            :to="ev.published ? `/train/${ev.id}` : undefined"
            class="flex items-center gap-4 card hover:border-gray-600 transition-colors"
            :class="ev.published ? 'group cursor-pointer' : 'opacity-80'"
          >
            <!-- Cover / icon -->
            <img
              v-if="ev.cover_url"
              :src="ev.cover_url"
              class="w-14 h-14 rounded-lg object-cover shrink-0"
              alt=""
            />
            <div v-else class="w-14 h-14 rounded-lg bg-niknax-900/60 flex items-center justify-center text-2xl shrink-0">
              🚂
            </div>

            <!-- Info -->
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2 mb-0.5 flex-wrap">
                <span
                  :class="ev.published
                    ? 'bg-green-900 text-green-300'
                    : 'bg-amber-900 text-amber-300'"
                  class="text-xs font-bold px-2 py-0.5 rounded-full shrink-0"
                >
                  {{ ev.published ? 'LIVE' : 'UPCOMING' }}
                </span>
                <h3 class="font-semibold text-white group-hover:text-niknax-300 transition-colors truncate">
                  {{ ev.name }}
                </h3>
              </div>
              <p v-if="ev.tagline" class="text-gray-400 text-sm truncate">{{ ev.tagline }}</p>
              <p v-if="ev.dateRange" class="text-gray-500 text-xs mt-0.5">{{ ev.dateRange }}</p>
            </div>

            <span v-if="ev.published" class="text-niknax-400 group-hover:translate-x-1 transition-transform text-lg shrink-0">→</span>
            <span v-else class="text-gray-600 text-sm shrink-0">Sign-up coming soon</span>
          </component>
        </div>
      </section>

      <!-- Calendar -->
      <section>
        <h2 class="text-xl font-bold text-white mb-4">Calendar</h2>
        <div class="card">
          <EventCalendar :events="calendarEvents" />
        </div>
      </section>

    </main>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import { supabase, isSupabaseConfigured } from '../../lib/supabase.js'
import { formatDate } from '../../lib/timeUtils.js'
import EventCalendar from '../../components/EventCalendar.vue'

const rawTrains = ref([])
const loading   = ref(true)

async function load() {
  // Fetch published OR upcoming trains, with their days
  const { data } = await supabase
    .from('trains')
    .select('*, days:train_days(id, day_date)')
    .or('published.eq.true,is_upcoming.eq.true')
    .order('created_at', { ascending: false })

  rawTrains.value = data || []
  loading.value   = false
}

// Sorted events for the list (published first, then upcoming, both sorted by soonest date)
const events = computed(() => {
  return [...rawTrains.value]
    .map(t => {
      const dates    = (t.days || []).map(d => d.day_date).sort()
      const dateRange = dates.length
        ? dates.length === 1
          ? formatDate(dates[0])
          : `${formatDate(dates[0])} – ${formatDate(dates[dates.length - 1])}`
        : null
      return { ...t, dates, dateRange }
    })
    .sort((a, b) => {
      // Live before upcoming
      if (a.published !== b.published) return a.published ? -1 : 1
      // Then by soonest date
      const aDate = a.dates[0] || '9999'
      const bDate = b.dates[0] || '9999'
      return aDate.localeCompare(bDate)
    })
})

// Calendar-formatted events
const calendarEvents = computed(() =>
  events.value.map(ev => ({
    id:          ev.id,
    name:        ev.name,
    published:   ev.published,
    is_upcoming: ev.is_upcoming,
    dates:       ev.dates,
  }))
)

onMounted(load)
</script>
