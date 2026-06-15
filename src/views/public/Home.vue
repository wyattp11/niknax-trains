<template>
  <div class="min-h-screen bg-base">
    <PublicNav />

    <!-- Hero: title + ASCII animation, no banner -->
    <div class="pt-10 pb-4 text-center px-6">
      <p class="text-gold-500 dark:text-gold-400 text-xs font-mono tracking-[0.35em] uppercase mb-3">
        ✦ &nbsp; All Aboard &nbsp; ✦
      </p>
      <h1 class="font-display leading-none mb-2 text-4xl sm:text-5xl lg:text-7xl text-tx1">
        Niknax Train Station
      </h1>
      <p class="text-tx3 text-xs font-mono tracking-widest mt-2">
        DISTRICT LIVE SELLING · BACK-TO-BACK SHOWS
      </p>
    </div>

    <!-- ASCII locomotive animation -->
    <TrainAnimation class="px-1 sm:px-4" />

    <main class="max-w-5xl mx-auto px-4 sm:px-6 py-10 space-y-12">

      <!-- Setup notice -->
      <div v-if="!isSupabaseConfigured" class="bg-[var(--badge-upcoming-bg)] border border-[var(--badge-upcoming-dot)] rounded-xl px-5 py-4">
        <p class="font-semibold text-[var(--badge-upcoming-text)] mb-1">⚙️ Supabase not connected yet</p>
        <p class="text-[var(--badge-upcoming-text)] text-sm opacity-80">
          Fill in your Supabase credentials in <code>.env.local</code> and restart the dev server.
        </p>
      </div>

      <!-- Events list -->
      <section>
        <h2 class="font-display text-2xl font-bold text-tx1 mb-4">Events</h2>

        <div v-if="loading" class="text-tx3 text-sm">Loading…</div>

        <div v-else-if="events.length === 0" class="card text-center py-10">
          <p class="text-tx3">No upcoming events right now. Check back soon!</p>
        </div>

        <div v-else class="space-y-3">
          <component
            :is="ev.published ? RouterLink : 'div'"
            v-for="ev in events"
            :key="ev.id"
            :to="ev.published ? `/train/${ev.id}` : undefined"
            class="flex items-center gap-4 card transition-colors"
            :class="ev.published ? 'group cursor-pointer hover:border-niknax-400' : 'opacity-80'"
          >
            <img v-if="ev.cover_url" :src="ev.cover_url" class="w-14 h-14 rounded-lg object-cover shrink-0" alt="" />
            <div v-else class="w-14 h-14 rounded-lg bg-niknax-900/30 border border-bd flex items-center justify-center font-mono text-xl text-niknax-600 shrink-0">🚂</div>

            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2 mb-0.5 flex-wrap">
                <span :class="ev.published ? 'badge-live' : 'badge-upcoming'" class="shrink-0">
                  {{ ev.published ? 'LIVE' : 'UPCOMING' }}
                </span>
                <h3 class="font-semibold text-tx1 group-hover:text-niknax-500 transition-colors truncate">{{ ev.name }}</h3>
              </div>
              <p v-if="ev.tagline" class="text-tx3 text-sm truncate">{{ ev.tagline }}</p>
              <p v-if="ev.dateRange" class="text-tx3 text-xs mt-0.5 font-mono">{{ ev.dateRange }}</p>
            </div>

            <span v-if="ev.published" class="text-niknax-500 group-hover:translate-x-1 transition-transform text-lg shrink-0">→</span>
            <span v-else class="text-tx3 text-sm shrink-0">Sign-up coming soon</span>
          </component>
        </div>
      </section>

      <!-- Calendar -->
      <section>
        <h2 class="font-display text-2xl font-bold text-tx1 mb-4">Calendar</h2>
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
import PublicNav from '../../components/PublicNav.vue'
import TrainAnimation from '../../components/TrainAnimation.vue'

const rawTrains = ref([])
const loading   = ref(true)

async function load() {
  const { data } = await supabase
    .from('trains')
    .select('*, days:train_days(id, day_date)')
    .order('created_at', { ascending: false })
  rawTrains.value = data || []
  loading.value   = false
}

function enrich(t) {
  const dates = (t.days || []).map(d => d.day_date).sort()
  const dateRange = dates.length
    ? dates.length === 1
      ? formatDate(dates[0])
      : `${formatDate(dates[0])} – ${formatDate(dates[dates.length - 1])}`
    : null
  return { ...t, dates, dateRange }
}

const events = computed(() =>
  rawTrains.value
    .filter(t => t.published || t.is_upcoming)
    .map(enrich)
    .sort((a, b) => {
      if (a.published !== b.published) return a.published ? -1 : 1
      return (a.dates[0] || '9999').localeCompare(b.dates[0] || '9999')
    })
)

const calendarEvents = computed(() =>
  rawTrains.value.map(t => {
    const e = enrich(t)
    return { id: e.id, name: e.name, published: e.published, is_upcoming: e.is_upcoming, dates: e.dates }
  })
)

onMounted(load)
</script>
