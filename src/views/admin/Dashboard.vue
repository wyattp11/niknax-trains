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

      <div v-else class="space-y-10">
        <!-- Current / upcoming trains -->
        <section v-if="currentTrains.length">
          <div class="space-y-4">
            <div
              v-for="train in currentTrains"
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
        </section>

        <!-- Train proposals -->
        <section v-if="proposals.length">
          <div class="flex items-center gap-3 mb-4">
            <h3 class="text-lg font-semibold text-tx2">Train Proposals</h3>
            <span v-if="unreviewedCount" class="bg-niknax-600 text-white text-xs font-bold px-2 py-0.5 rounded-full">{{ unreviewedCount }} new</span>
            <div class="flex-1 h-px bg-bd"></div>
          </div>
          <div class="space-y-3">
            <div
              v-for="p in proposals"
              :key="p.id"
              class="card"
              :class="p.reviewed ? 'opacity-60' : ''"
            >
              <div class="flex items-start justify-between gap-4">
                <div class="min-w-0">
                  <div class="flex items-center gap-2 mb-1 flex-wrap">
                    <span v-if="!p.reviewed" class="bg-niknax-100 dark:bg-niknax-900 text-niknax-700 dark:text-niknax-300 text-xs font-semibold px-2 py-0.5 rounded-full">New</span>
                    <span v-else class="text-tx3 text-xs">Reviewed</span>
                    <span class="font-semibold text-tx1 truncate">{{ p.name }}</span>
                  </div>
                  <p v-if="p.tagline" class="text-sm text-tx2 mb-1">{{ p.tagline }}</p>
                  <div class="flex flex-wrap gap-x-4 gap-y-0.5 text-xs text-tx3">
                    <span>@{{ p.contact_username }}</span>
                    <span v-if="p.proposed_date">{{ p.proposed_date }}</span>
                    <span>{{ formatDate(p.created_at) }}</span>
                  </div>
                  <p v-if="p.message" class="text-sm text-tx2 mt-2 whitespace-pre-line">{{ p.message }}</p>
                </div>
                <button
                  v-if="!p.reviewed"
                  @click="markReviewed(p)"
                  class="btn-secondary text-xs py-1 px-3 shrink-0 whitespace-nowrap"
                >
                  Mark reviewed
                </button>
              </div>
            </div>
          </div>
        </section>

        <!-- Past trains -->
        <section v-if="pastTrains.length">
          <div class="flex items-center gap-3 mb-4">
            <h3 class="text-lg font-semibold text-tx2">Past Trains</h3>
            <div class="flex-1 h-px bg-bd"></div>
          </div>
          <div class="space-y-4">
            <div
              v-for="train in pastTrains"
              :key="train.id"
              class="card flex flex-col sm:flex-row sm:items-center gap-4 opacity-75"
            >
              <img
                v-if="train.cover_url"
                :src="train.cover_url"
                class="w-28 h-28 rounded-lg object-cover shrink-0 grayscale"
                alt=""
              />
              <div v-else class="w-28 h-28 rounded-lg bg-niknax-900/40 flex items-center justify-center text-5xl shrink-0" aria-hidden="true">
                🚂
              </div>

              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2 mb-1 flex-wrap">
                  <span class="badge-past">Past Event</span>
                  <h3 class="font-semibold text-tx2 truncate">{{ train.name }}</h3>
                </div>
                <p class="text-sm text-tx3">Created {{ formatDate(train.created_at) }}</p>
              </div>

              <div class="flex flex-col sm:flex-row gap-2 shrink-0 w-full sm:w-auto">
                <RouterLink :to="`/train/${train.id}`" target="_blank" class="btn-secondary text-sm py-1.5 text-center whitespace-nowrap">
                  View
                </RouterLink>
                <button
                  @click="duplicateTrain(train)"
                  :disabled="duplicatingId === train.id"
                  class="btn-secondary text-sm py-1.5 text-center whitespace-nowrap flex items-center justify-center gap-1.5 disabled:opacity-60"
                >
                  <ion-icon name="copy-outline" aria-hidden="true"></ion-icon>
                  {{ duplicatingId === train.id ? 'Duplicating…' : 'Duplicate' }}
                </button>
                <RouterLink :to="`/admin/trains/${train.id}`" class="btn-primary text-sm py-1.5 text-center whitespace-nowrap">
                  Manage
                </RouterLink>
              </div>
            </div>
          </div>
        </section>
      </div>
    </main>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import AdminNav from '../../components/AdminNav.vue'
import { supabase } from '../../lib/supabase.js'
import { trainStatus, STATUS_BADGE_CLASS, isPastTrain } from '../../lib/timeUtils.js'

const router = useRouter()

const trains     = ref([])
const loading    = ref(true)
const duplicatingId = ref(null)
const proposals  = ref([])
let proposalsSub = null

async function loadTrains() {
  loading.value = true
  const { data, error } = await supabase
    .from('trains')
    .select('*, days:train_days(day_date, slots(id, username))')
    .order('created_at', { ascending: false })
  if (!error) trains.value = data
  loading.value = false
}

function trainDates(train) {
  return (train.days || []).map(d => d.day_date).filter(Boolean)
}

function isPast(train) {
  return isPastTrain(trainDates(train))
}

const currentTrains = computed(() => trains.value.filter(t => !isPast(t)))
const pastTrains = computed(() =>
  [...trains.value.filter(isPast)].sort((a, b) => {
    const aLast = [...trainDates(a)].sort().at(-1) || ''
    const bLast = [...trainDates(b)].sort().at(-1) || ''
    return bLast.localeCompare(aLast)
  })
)

function slotCounts(train) {
  const slots = (train.days || []).flatMap(d => d.slots || [])
  return { total: slots.length, filled: slots.filter(s => s.username).length }
}

function status(train) {
  if (isPast(train)) return { key: 'past', label: 'Past Event' }
  const { total, filled } = slotCounts(train)
  return trainStatus(train, total, filled)
}

function statusBadgeClass(train) {
  return STATUS_BADGE_CLASS[status(train).key]
}

function formatDate(iso) {
  return new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
}

async function duplicateTrain(train) {
  duplicatingId.value = train.id
  try {
    const { data: newTrain, error: trainErr } = await supabase
      .from('trains')
      .insert({
        name: `${train.name} (Copy)`,
        tagline: train.tagline || null,
        description: train.description || null,
        district_link: train.district_link || null,
        rules_md: train.rules_md || null,
        cover_url: train.cover_url || null,
        published: false,
        is_upcoming: false,
      })
      .select()
      .single()
    if (trainErr) throw trainErr

    const { data: oldDays, error: daysErr } = await supabase
      .from('train_days')
      .select('*, slots(*)')
      .eq('train_id', train.id)
      .order('day_order')
    if (daysErr) throw daysErr

    for (const oldDay of oldDays || []) {
      const { data: newDay, error: dayErr } = await supabase
        .from('train_days')
        .insert({
          train_id: newTrain.id,
          day_date: oldDay.day_date,
          day_label: oldDay.day_label,
          day_order: oldDay.day_order,
        })
        .select()
        .single()
      if (dayErr) throw dayErr

      const slotsToInsert = (oldDay.slots || []).map(s => ({
        train_day_id: newDay.id,
        start_time: s.start_time,
        duration_min: s.duration_min,
        username: s.is_pre_assigned ? s.username : null,
        seller_link: null,
        label: s.label,
        is_pre_assigned: s.is_pre_assigned,
        slot_order: s.slot_order,
      }))
      if (slotsToInsert.length) {
        const { error: slotsErr } = await supabase.from('slots').insert(slotsToInsert)
        if (slotsErr) throw slotsErr
      }
    }

    router.push(`/admin/trains/${newTrain.id}`)
  } catch (err) {
    alert(`Could not duplicate train: ${err.message || err}`)
  } finally {
    duplicatingId.value = null
  }
}

const unreviewedCount = computed(() => proposals.value.filter(p => !p.reviewed).length)

async function loadProposals() {
  const { data } = await supabase
    .from('train_proposals')
    .select('*')
    .order('created_at', { ascending: false })
  proposals.value = data || []

  // Subscribe to new proposals in real-time
  proposalsSub = supabase
    .channel('train-proposals-admin')
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'train_proposals' }, payload => {
      proposals.value.unshift(payload.new)
    })
    .subscribe()
}

async function markReviewed(proposal) {
  const { error } = await supabase
    .from('train_proposals')
    .update({ reviewed: true })
    .eq('id', proposal.id)
  if (!error) proposal.reviewed = true
}

onMounted(() => { loadTrains(); loadProposals() })
onUnmounted(() => { proposalsSub?.unsubscribe() })
</script>
