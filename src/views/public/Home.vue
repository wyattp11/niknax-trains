<template>
  <div class="min-h-screen bg-base flex flex-col">

    <!-- ── Top accent stripe ── -->
    <div class="h-3 bg-niknax-600 shrink-0"></div>

    <!-- ── Hero: bold 60s title, no nav ── -->
    <header class="text-center px-6 pt-12 pb-6 relative">
      <!-- Eyebrow -->
      <p class="text-niknax-600 dark:text-niknax-400 text-[0.65rem] font-mono tracking-[0.55em] uppercase mb-6">
        Niknax.net · Live Selling · Events
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

      <!-- Dark mode + Palm Springs toggles — subtle, floating top-right -->
      <div class="absolute top-5 right-5 flex items-center gap-3">
        <button
          @click="theme.toggle()"
          class="text-tx3 hover:text-tx1 transition-colors text-lg"
          :title="theme.isDark ? 'Switch to light mode' : 'Switch to dark mode'"
          :aria-label="theme.isDark ? 'Switch to light mode' : 'Switch to dark mode'"
        ><ion-icon :name="theme.isDark ? 'sunny-outline' : 'moon-outline'" aria-hidden="true"></ion-icon></button>
        <button
          @click="theme.toggleSound()"
          class="text-lg text-tx3 hover:text-tx1 transition-colors"
          :title="theme.isSoundMuted ? 'Turn on sounds' : 'Mute sounds'"
          :aria-label="theme.isSoundMuted ? 'Turn on sounds' : 'Mute sounds'"
          :aria-pressed="theme.isSoundMuted"
        ><ion-icon :name="theme.isSoundMuted ? 'volume-mute-outline' : 'volume-high-outline'" aria-hidden="true"></ion-icon></button>
        <button
          @click="theme.togglePalm()"
          class="text-lg transition-colors"
          :class="theme.isPalm ? 'text-niknax-600 dark:text-niknax-400' : 'text-tx3 hover:text-tx1'"
          :title="theme.isPalm ? 'Turn off Palm Springs theme' : 'Turn on Palm Springs theme'"
          :aria-label="theme.isPalm ? 'Turn off Palm Springs theme' : 'Turn on Palm Springs theme'"
          :aria-pressed="theme.isPalm"
        ><ion-icon name="leaf-outline" aria-hidden="true"></ion-icon></button>
        <button
          @click="startHomeTour"
          class="text-tx3 hover:text-tx1 transition-colors text-lg"
          title="Show me around"
          aria-label="Show me around"
        ><ion-icon name="help-circle-outline" aria-hidden="true"></ion-icon></button>
      </div>
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
      <section data-tour="events-section">
        <div class="flex items-center gap-5 mb-7">
          <h2 class="font-display text-4xl text-tx1 shrink-0">Events</h2>
          <div class="flex-1 h-[3px] bg-niknax-600 rounded-full"></div>
          <RouterLink to="/create-train" class="btn-primary text-sm py-1.5 whitespace-nowrap shrink-0">
            🚂 Conduct your own train!
          </RouterLink>
        </div>

        <div v-if="loading" class="text-tx3 text-sm">Loading…</div>

        <div v-else-if="events.length === 0" class="card text-center py-10">
          <p class="text-tx3">No upcoming events right now. Check back soon!</p>
        </div>

        <div v-else class="space-y-3">
          <!-- Wrapper carries the hover so the popup can sit outside the card
               without the card's own transform clipping it. -->
          <div
            v-for="(ev, idx) in events"
            :key="ev.id"
            class="relative"
            @mouseenter="ev.rules_md && (hoveredRulesId = ev.id)"
            @mouseleave="hoveredRulesId = null"
          >
          <component
            :is="ev.published ? RouterLink : 'div'"
            :to="ev.published ? `/train/${ev.id}` : undefined"
            :data-tour="idx === 0 ? 'first-event-card' : undefined"
            class="flex items-stretch gap-4 card transition-all"
            :class="ev.published
              ? 'group cursor-pointer hover:border-niknax-600 hover:shadow-md hover:-translate-y-0.5'
              : 'opacity-70'"
          >
            <img
              v-if="ev.cover_url"
              :src="ev.cover_url"
              class="w-28 h-full min-h-28 rounded-lg object-cover shrink-0"
              alt=""
            />
            <div
              v-else
              class="w-28 h-full min-h-28 rounded-lg bg-niknax-100 dark:bg-niknax-950 border border-bd
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
          </component>

          <!-- Conductor entry point. Sits outside the card link — nesting a
               link inside a link isn't valid — and is shown on every member
               train so a conductor can get back in from any device. -->
          <div v-if="ev.is_member_train" class="flex justify-end mt-1.5">
            <RouterLink
              :to="`/train/${ev.id}/conductor`"
              class="inline-flex items-center gap-1.5 text-xs font-bold px-3 py-1.5 rounded-lg
                     bg-niknax-600 hover:bg-niknax-500 text-white shadow-sm transition-colors"
            >
              <ion-icon name="settings-outline" aria-hidden="true"></ion-icon>
              Manage your train
              <span v-if="ev.conductor_username" class="font-normal opacity-80">· @{{ ev.conductor_username }}</span>
            </RouterLink>
          </div>

          <!-- Guidelines on hover. Desktop only — hidden below lg, where
               there's no hover and not enough room to place it. -->
          <Transition
            enter-active-class="transition duration-150 ease-out"
            enter-from-class="opacity-0 translate-y-1"
            leave-active-class="transition duration-100 ease-in"
            leave-to-class="opacity-0"
          >
            <!-- Floats below the card rather than beside it: the events list
                 is max-w-5xl, so there's no room to the side even on wide
                 screens. Absolute so it overlays instead of shifting the
                 list, and pointer-events-none so it can't block the card. -->
            <div
              v-if="hoveredRulesId === ev.id"
              class="hidden md:block absolute z-30 left-0 right-0 top-full mt-2 pointer-events-none"
              role="tooltip"
            >
              <div class="bg-surface border-2 border-niknax-600 rounded-xl shadow-2xl overflow-hidden">
                <div class="bg-niknax-600 text-white px-4 py-2 flex items-center gap-2">
                  <ion-icon name="document-text-outline" aria-hidden="true"></ion-icon>
                  <span class="text-sm font-semibold">Sign-Up Rules &amp; Criteria</span>
                </div>
                <div
                  class="rules-content px-4 py-3 max-h-[22rem] overflow-y-auto text-sm"
                  v-html="renderMarkdown(ev.rules_md)"
                ></div>
              </div>
            </div>
          </Transition>
          </div>
        </div>
      </section>

      <!-- Calendar -->
      <section data-tour="calendar-section">
        <div class="flex items-center gap-5 mb-7">
          <h2 class="font-display text-4xl text-tx1 shrink-0">Calendar</h2>
          <div class="flex-1 h-[3px] bg-niknax-600 rounded-full"></div>
        </div>
        <div class="card">
          <EventCalendar :events="calendarEvents" />
        </div>
      </section>

      <!-- Past Trains -->
      <section v-if="pastEvents.length">
        <div class="flex items-center gap-5 mb-7">
          <h2 class="font-display text-4xl text-tx3 shrink-0">Past Trains</h2>
          <div class="flex-1 h-[3px] bg-bd rounded-full"></div>
        </div>

        <div class="space-y-3">
          <RouterLink
            v-for="ev in pastEvents"
            :key="ev.id"
            :to="`/train/${ev.id}`"
            class="flex items-stretch gap-4 card transition-all opacity-60 hover:opacity-90"
          >
            <img
              v-if="ev.cover_url"
              :src="ev.cover_url"
              class="w-28 h-full min-h-28 rounded-lg object-cover shrink-0 grayscale"
              alt=""
            />
            <div
              v-else
              class="w-28 h-full min-h-28 rounded-lg bg-niknax-100 dark:bg-niknax-950 border border-bd
                     flex items-center justify-center font-mono text-5xl shrink-0"
              aria-hidden="true"
            >🚂</div>

            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2 mb-0.5 flex-wrap">
                <span class="badge-past shrink-0">Past Event</span>
                <h3 class="font-semibold text-tx2 truncate">{{ ev.name }}</h3>
              </div>
              <p v-if="ev.tagline" class="text-tx3 text-sm truncate">{{ ev.tagline }}</p>
              <p v-if="ev.dateRange" class="text-tx3 text-xs mt-0.5 font-mono">{{ ev.dateRange }}</p>
            </div>
          </RouterLink>
        </div>
      </section>

    </main>

    <!-- ── Bottom accent stripe ── -->
    <div class="h-3 bg-niknax-600 shrink-0"></div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, nextTick } from 'vue'
import { RouterLink } from 'vue-router'
import { supabase, isSupabaseConfigured } from '../../lib/supabase.js'
import { formatDate, trainStatus, STATUS_BADGE_CLASS, isPastTrain, isTrainLive } from '../../lib/timeUtils.js'
import { useThemeStore } from '../../stores/theme.js'
import { useOnboardingStore } from '../../stores/onboarding.js'
import EventCalendar from '../../components/EventCalendar.vue'
import TrainAnimation from '../../components/TrainAnimation.vue'
import { renderMarkdown } from '../../lib/renderMarkdown.js'

const theme      = useThemeStore()
const onboarding = useOnboardingStore()
const rawTrains = ref([])

// Which train's guidelines are showing on hover. Desktop only — the panel is
// hidden below md, where there's no hover to begin with.
const hoveredRulesId = ref(null)

// Ticking clock so the Live Now badge appears and clears on its own. A badge
// that only updates on reload would be wrong for most of the show.
const nowTick = ref(new Date())
let tickInterval = null
const loading   = ref(true)

async function load() {
  const { data } = await supabase
    .from('trains')
    // start_time / duration_min / slot_order are needed to work out whether a
    // train is airing right now, not just whether sign-ups are open.
    .select('*, days:train_days(id, day_date, slots(id, username, start_time, duration_min, slot_order))')
    .or('published.eq.true,is_upcoming.eq.true')
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
  const isPast = isPastTrain(dates)
  const status = isPast
    ? { key: 'past', label: 'Past Event' }
    : trainStatus(t, allSlots.length, allSlots.filter(s => s.username).length,
                  { isLive: isTrainLive(t.days, nowTick.value) })
  return { ...t, dates, dateRange, isPast, status }
}

const events = computed(() =>
  rawTrains.value
    .filter(t => t.published || t.is_upcoming)
    .map(enrich)
    .filter(e => !e.isPast)
    .sort((a, b) => {
      if (a.published !== b.published) return a.published ? -1 : 1
      return (a.dates[0] || '9999').localeCompare(b.dates[0] || '9999')
    })
)

const pastEvents = computed(() =>
  rawTrains.value
    .filter(t => t.published || t.is_upcoming)
    .map(enrich)
    .filter(e => e.isPast)
    .sort((a, b) => (b.dates.at(-1) || '').localeCompare(a.dates.at(-1) || ''))
)

const calendarEvents = computed(() =>
  rawTrains.value.map(t => {
    const e = enrich(t)
    return { id: e.id, name: e.name, published: e.published, is_upcoming: e.is_upcoming, dates: e.dates, isPast: e.isPast }
  })
)

// ── First-visit walkthrough ───────────────────────────────────────────────
function buildHomeSteps() {
  const steps = [
    {
      title: 'Welcome aboard! 🚂',
      body: "Let's take a quick look around the Niknax Train Station.",
      placement: 'center',
    },
    {
      target: '[data-tour="first-event-card"]',
      title: 'Upcoming Trains',
      body: 'Every open and upcoming event lives here. "Now Boarding" means signups are live right now.',
      placement: 'bottom',
    },
    {
      target: '[data-tour="calendar-section"]',
      title: 'Calendar View',
      body: 'Prefer dates over a list? Every train shows up here too, color-coded by status.',
      placement: 'top',
    },
  ]

  if (events.value.length) {
    steps.push({
      target: '[data-tour="first-event-card"]',
      title: 'Pick a Train',
      body: "Tap any train to see its full schedule. We'll show you how to grab an open time slot next.",
      placement: 'bottom',
      onComplete: () => onboarding.setContinuation('signup'),
    })
  } else {
    steps.push({
      title: "That's it for now!",
      body: 'Check back soon — new trains will show up here as they get scheduled.',
      placement: 'center',
    })
  }

  return steps
}

function startHomeTour() {
  onboarding.start(buildHomeSteps())
}

onMounted(async () => {
  await load()
  if (!onboarding.hasSeenIntro()) {
    onboarding.markIntroSeen()
    nextTick(() => startHomeTour())
  }

  // 30s is fine — slots are 10 minutes at the shortest, so the badge is never
  // meaningfully stale, and this costs nothing.
  tickInterval = setInterval(() => { nowTick.value = new Date() }, 30_000)
})

onUnmounted(() => {
  if (tickInterval) clearInterval(tickInterval)
})
</script>
