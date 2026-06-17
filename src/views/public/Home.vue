<template>
  <div class="min-h-screen bg-base flex flex-col">

    <!-- ── Top accent stripe ── -->
    <div class="h-3 bg-niknax-600 shrink-0"></div>

    <!-- ── Hero: bold 60s title, no nav ── -->
    <header class="text-center px-6 pt-12 pb-6 relative">
      <!-- Eyebrow -->
      <p class="text-niknax-600 dark:text-niknax-400 text-[0.65rem] font-mono tracking-[0.55em] uppercase mb-6">
        District · Live Selling · Raid Trains
      </p>

      <!-- Main title — huge Righteous display -->
      <h1 class="font-display leading-none text-tx1 select-none">
        <span class="block text-[3.5rem] sm:text-[5.5rem] md:text-[7rem] lg:text-[9rem] xl:text-[11rem] leading-[0.9]">
          Niknax
        </span>
        <span class="block text-xl sm:text-2xl md:text-3xl lg:text-4xl text-niknax-600 dark:text-niknax-400 tracking-[0.3em] mt-2 uppercase">
          Train Station
        </span>
      </h1>

      <!-- Admin link — subtle, floating top-left -->
      <RouterLink
        to="/admin"
        class="absolute top-5 left-5 text-tx3 hover:text-tx1 transition-colors text-xs font-mono uppercase tracking-widest"
      >Admin</RouterLink>

      <!-- Dark mode toggle — subtle, floating top-right -->
      <button
        @click="theme.toggle()"
        class="absolute top-5 right-5 text-tx3 hover:text-tx1 transition-colors text-lg"
        :title="theme.isDark ? 'Switch to light mode' : 'Switch to dark mode'"
        :aria-label="theme.isDark ? 'Switch to light mode' : 'Switch to dark mode'"
      ><span aria-hidden="true">{{ theme.isDark ? '☀' : '◑' }}</span></button>
    </header>

    <!-- ── ASCII locomotive animation ── -->
    <TrainAnimation class="px-1 sm:px-4" />

    <!-- ── Divider under animation ── -->
    <div class="h-px bg-bd mx-4 sm:mx-8 mt-2 mb-10"></div>

    <!-- ── Content ── -->
    <main class="max-w-5xl mx-auto w-full px-4 sm:px-6 flex-1 space-y-14 pb-16">

      <!-- Setup notice (dev only) -->
      <div v-if="!isSupabaseConfigured" class="bg-[var(--badge-upcoming-bg)] border border-[var(--badge-upcoming-dot)] rounded-xl px-5 py-4">
        <p class="font-semibold text-[var(--badge-upcoming-text)] mb-1">⚙️ Supabase not connected yet</p>
        <p class="text-[var(--badge-upcoming-text)] text-sm opacity-80">
          Fill in your Supabase credentials in <code>.env.local</code> and restart the dev server.
        </p>
      </div>

      <!-- Events list -->
      <section>
        <div class="flex items-center gap-5 mb-7">
          <h2 class="font-display text-4xl text-tx1 shrink-0">Events</h2>
          <div class="flex-1 h-[3px] bg-niknax-600 rounded-full"></div>
        </div>

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
            class="flex items-center gap-4 card transition-all"
            :class="ev.published
              ? 'group cursor-pointer hover:border-niknax-600 hover:shadow-md hover:-translate-y-0.5'
              : 'opacity-70'"
          >
            <img
              v-if="ev.cover_url"
              :src="ev.cover_url"
              class="w-28 h-28 rounded-lg object-cover shrink-0"
              alt=""
            />
            <div
              v-else
              class="w-28 h-28 rounded-lg bg-niknax-100 dark:bg-niknax-950 border border-bd
                     flex items-center justify-center font-mono text-5xl shrink-0"
              aria-hidden="true"
            >🚂</div>

            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2 mb-0.5 flex-wrap">
                <span :class="`badge-${STATUS_BADGE_CLASS[ev.status.key]}`" class="shrink-0">
                  {{ ev.status.label }}
                </span>
                <h3 class="font-semibold text-tx1 group-hover:text-niknax-600 dark:group-hover:text-niknax-400 transition-colors truncate">
                  {{ ev.name }}
                </h3>
              </div>
              <p v-if="ev.tagline" class="text-tx3 text-sm truncate">{{ ev.tagline }}</p>
              <p v-if="ev.dateRange" class="text-tx3 text-xs mt-0.5 font-mono">{{ ev.dateRange }}</p>
            </div>

            <span v-if="ev.published" class="text-niknax-600 dark:text-niknax-400 group-hover:translate-x-1 transition-transform text-xl shrink-0 font-bold">→</span>
            <span v-else class="text-tx3 text-sm shrink-0 font-mono">coming soon</span>
          </component>
        </div>
      </section>

      <!-- Calendar -->
      <section>
        <div class="flex items-center gap-5 mb-7">
          <h2 class="font-display text-4xl text-tx1 shrink-0">Calendar</h2>
          <div class="flex-1 h-[3px] bg-niknax-600 rounded-full"></div>
        </div>
        <div class="card">
          <EventCalendar :events="calendarEvents" />
        </div>
      </section>

    </main>

    <!-- ── Bottom accent stripe ── -->
    <div class="h-3 bg-niknax-600 shrink-0"></div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import { supabase, isSupabaseConfigured } from '../../lib/supabase.js'
import { formatDate, trainStatus, STATUS_BADGE_CLASS } from '../../lib/timeUtils.js'
import { useThemeStore } from '../../stores/theme.js'
import EventCalendar from '../../components/EventCalendar.vue'
import TrainAnimation from '../../components/TrainAnimation.vue'

const theme     = useThemeStore()
const rawTrains = ref([])
const loading   = ref(true)

async function load() {
  const { data } = await supabase
    .from('trains')
    .select('*, days:train_days(id, day_date, slots(id, username))')
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
  const allSlots = (t.days || []).flatMap(d => d.slots || [])
  const status = trainStatus(t, allSlots.length, allSlots.filter(s => s.username).length)
  return { ...t, dates, dateRange, status }
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
