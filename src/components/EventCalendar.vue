<template>
  <div>
    <!-- Controls -->
    <div class="flex items-center gap-3 mb-6 flex-wrap">
      <div class="flex items-center gap-1">
        <button
          @click="shift(-1)"
          class="w-8 h-8 flex items-center justify-center rounded-lg bg-gray-800 hover:bg-gray-700 text-gray-300 transition-colors"
        >‹</button>
        <span class="text-white font-semibold min-w-[180px] text-center">{{ headerLabel }}</span>
        <button
          @click="shift(1)"
          class="w-8 h-8 flex items-center justify-center rounded-lg bg-gray-800 hover:bg-gray-700 text-gray-300 transition-colors"
        >›</button>
      </div>

      <div class="ml-auto flex rounded-lg overflow-hidden border border-gray-700">
        <button
          @click="view = 'month'"
          :class="view === 'month' ? 'bg-niknax-700 text-white' : 'text-gray-400 hover:text-gray-200 bg-gray-900'"
          class="px-3 py-1.5 text-sm font-medium transition-colors"
        >Month</button>
        <button
          @click="view = '3month'"
          :class="view === '3month' ? 'bg-niknax-700 text-white' : 'text-gray-400 hover:text-gray-200 bg-gray-900'"
          class="px-3 py-1.5 text-sm font-medium transition-colors border-l border-gray-700"
        >3 Month</button>
      </div>
    </div>

    <!-- Legend -->
    <div class="flex items-center gap-4 mb-4 text-xs text-gray-400">
      <span class="flex items-center gap-1.5">
        <span class="w-2.5 h-2.5 rounded-full bg-green-500 inline-block"></span> Live
      </span>
      <span class="flex items-center gap-1.5">
        <span class="w-2.5 h-2.5 rounded-full bg-amber-500 inline-block"></span> Upcoming
      </span>
      <span class="flex items-center gap-1.5">
        <span class="w-2.5 h-2.5 rounded-full bg-gray-500 inline-block"></span> Draft
      </span>
    </div>

    <!-- Calendar grids -->
    <div :class="view === '3month' ? 'grid grid-cols-1 md:grid-cols-3 gap-6' : ''">
      <div v-for="offset in monthOffsets" :key="offset">
        <!-- Month label for 3-month view -->
        <h3 v-if="view === '3month'" class="text-center font-semibold text-gray-300 mb-3 text-sm">
          {{ monthLabel(offset) }}
        </h3>

        <!-- Day-of-week headers -->
        <div class="grid grid-cols-7 mb-1">
          <div
            v-for="d in DOW"
            :key="d"
            class="text-center text-xs text-gray-500 py-1 font-medium"
          >{{ d }}</div>
        </div>

        <!-- Day cells -->
        <div class="grid grid-cols-7 gap-px bg-gray-800 rounded-xl overflow-hidden border border-gray-800">
          <div
            v-for="(cell, i) in monthGrid(offset)"
            :key="i"
            :class="[
              cell ? 'bg-gray-900' : 'bg-gray-950',
              isToday(offset, cell) ? 'ring-1 ring-inset ring-niknax-500' : '',
            ]"
            class="min-h-[72px] p-1.5"
          >
            <span
              v-if="cell"
              :class="isToday(offset, cell) ? 'text-niknax-400 font-bold' : 'text-gray-400'"
              class="text-xs block mb-1"
            >{{ cell }}</span>

            <RouterLink
              v-for="ev in eventsOnDay(offset, cell)"
              :key="ev.id"
              :to="ev.published || ev.is_upcoming ? `/train/${ev.id}` : '#'"
              :class="chipClass(ev)"
              class="block text-xs px-1.5 py-0.5 rounded mb-0.5 truncate leading-tight transition-colors"
            >
              {{ ev.name }}
            </RouterLink>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { RouterLink } from 'vue-router'

const props = defineProps({
  // Array of { id, name, published, is_upcoming, dates: ['YYYY-MM-DD',...] }
  events: { type: Array, default: () => [] },
})

const DOW  = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
const view = ref('month')

// Track base as year + month index (0-based)
const today     = new Date()
const baseYear  = ref(today.getFullYear())
const baseMonth = ref(today.getMonth())

const monthOffsets = computed(() => view.value === '3month' ? [0, 1, 2] : [0])

function targetYM(offset) {
  let m = baseMonth.value + offset
  let y = baseYear.value
  while (m > 11) { m -= 12; y++ }
  while (m < 0)  { m += 12; y-- }
  return { y, m }
}

function shift(dir) {
  const step = view.value === '3month' ? 3 : 1
  let m = baseMonth.value + dir * step
  let y = baseYear.value
  while (m > 11) { m -= 12; y++ }
  while (m < 0)  { m += 12; y-- }
  baseYear.value  = y
  baseMonth.value = m
}

const MONTH_NAMES = ['January','February','March','April','May','June','July','August','September','October','November','December']

function monthLabel(offset) {
  const { y, m } = targetYM(offset)
  return `${MONTH_NAMES[m]} ${y}`
}

const headerLabel = computed(() => {
  if (view.value === 'month') return monthLabel(0)
  return `${monthLabel(0)} – ${monthLabel(2)}`
})

function monthGrid(offset) {
  const { y, m } = targetYM(offset)
  const firstDow  = new Date(y, m, 1).getDay()
  const daysInMonth = new Date(y, m + 1, 0).getDate()
  const cells = []
  for (let i = 0; i < firstDow; i++) cells.push(null)
  for (let d = 1; d <= daysInMonth; d++) cells.push(d)
  // Pad to complete last row
  while (cells.length % 7 !== 0) cells.push(null)
  return cells
}

function dateStr(offset, day) {
  if (!day) return null
  const { y, m } = targetYM(offset)
  return `${y}-${String(m + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`
}

function eventsOnDay(offset, day) {
  if (!day) return []
  const ds = dateStr(offset, day)
  return props.events.filter(ev => ev.dates?.includes(ds))
}

function isToday(offset, day) {
  if (!day) return false
  return dateStr(offset, day) === today.toISOString().slice(0, 10)
}

function chipClass(ev) {
  if (ev.published)   return 'bg-green-900/70 text-green-200 hover:bg-green-800/80'
  if (ev.is_upcoming) return 'bg-amber-900/70 text-amber-200 hover:bg-amber-800/80'
  return 'bg-gray-700/80 text-gray-400 hover:bg-gray-600/80'
}
</script>
