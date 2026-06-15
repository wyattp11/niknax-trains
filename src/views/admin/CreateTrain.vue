<template>
  <div class="min-h-screen bg-gray-950">
    <AdminNav />

    <main class="max-w-3xl mx-auto px-6 py-10">
      <RouterLink to="/admin/dashboard" class="text-niknax-400 hover:text-niknax-300 text-sm mb-6 inline-block">
        ← Back to dashboard
      </RouterLink>

      <h2 class="text-2xl font-bold mb-8">Create New Train</h2>

      <form @submit.prevent="saveAndContinue" class="space-y-8">

        <!-- ── Event details ── -->
        <section class="card space-y-5">
          <h3 class="text-lg font-semibold text-niknax-300">Event Details</h3>

          <div>
            <label class="label">Event Name *</label>
            <input v-model="form.name" class="input" placeholder="Glass Gallery: Radiant Reflections" required />
          </div>

          <div>
            <label class="label">Tagline</label>
            <input v-model="form.tagline" class="input" placeholder="A sparkling live-selling event" />
          </div>

          <div>
            <label class="label">Description</label>
            <textarea v-model="form.description" class="input" rows="3" placeholder="Details about the event…" />
          </div>

          <div>
            <label class="label">District Event Link</label>
            <input v-model="form.district_link" class="input" type="url" placeholder="https://districtapp.tv/…" />
          </div>

          <div>
            <label class="label">Train Graphic</label>
            <ImageUpload
              @file-selected="coverFile = $event"
              @cleared="coverFile = null"
            />
          </div>
        </section>

        <!-- ── Days ── -->
        <section class="card space-y-5">
          <div class="flex items-center justify-between">
            <h3 class="text-lg font-semibold text-niknax-300">Event Days</h3>
            <button type="button" @click="addDay" class="btn-secondary text-sm py-1.5">+ Add Day</button>
          </div>

          <div v-if="form.days.length === 0" class="text-gray-500 text-sm italic">
            No days added yet. Click "+ Add Day" above.
          </div>

          <div
            v-for="(day, di) in form.days"
            :key="di"
            class="border border-gray-700 rounded-lg p-4 space-y-4"
          >
            <div class="flex items-center justify-between">
              <span class="font-medium text-gray-200">Day {{ di + 1 }}</span>
              <button type="button" @click="removeDay(di)" class="text-red-400 hover:text-red-300 text-sm">Remove</button>
            </div>

            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="label">Date *</label>
                <input v-model="day.day_date" type="date" class="input" required />
              </div>
              <div>
                <label class="label">Day Label (optional)</label>
                <input v-model="day.day_label" class="input" placeholder="Day 1" />
              </div>
            </div>

            <!-- Slot generation settings -->
            <div class="bg-gray-800 rounded-lg p-4 space-y-4">
              <p class="text-sm text-gray-300 font-medium">Open Slot Generation</p>

              <div class="grid grid-cols-3 gap-4">
                <div>
                  <label class="label">Start Time (ET) *</label>
                  <input v-model="day.start_time" type="time" class="input" step="60" required />
                </div>
                <div>
                  <label class="label">Slot Duration (min)</label>
                  <input v-model.number="day.slot_duration" type="number" min="5" max="120" class="input" />
                </div>
                <div>
                  <label class="label">Number of Slots</label>
                  <input v-model.number="day.slot_count" type="number" min="1" max="100" class="input" />
                </div>
              </div>
              <p class="text-xs text-gray-500">
                This generates {{ day.slot_count }} open slots of {{ day.slot_duration }} min each, starting at {{ formatDisplayTime(day.start_time) }} ET.
                Pre-assigned slots below will overwrite matching times.
              </p>
            </div>

            <!-- Pre-assigned slots -->
            <div class="space-y-3">
              <div class="flex items-center justify-between">
                <p class="text-sm text-gray-300 font-medium">Pre-Assigned Slots</p>
                <button type="button" @click="addPreAssigned(di)" class="text-niknax-400 hover:text-niknax-300 text-xs">
                  + Add
                </button>
              </div>

              <p class="text-xs text-gray-500 -mt-1">
                Reserved spots (moderators, Jocelyn's boosts, kickoff). These cannot be claimed via public signup.
              </p>

              <div
                v-for="(slot, si) in day.pre_assigned"
                :key="si"
                class="grid grid-cols-12 gap-2 items-start"
              >
                <input v-model="slot.username" class="input col-span-3" placeholder="Username" />
                <input v-model="slot.time" type="time" class="input col-span-2" />
                <input v-model.number="slot.duration_min" type="number" min="5" max="120" class="input col-span-2" placeholder="30 min" />
                <input v-model="slot.label" class="input col-span-4" placeholder='Label (e.g. "Kickoff")' />
                <button type="button" @click="removePreAssigned(di, si)" class="text-red-400 hover:text-red-300 col-span-1 pt-2 text-lg leading-none">×</button>
              </div>
            </div>
          </div>
        </section>

        <!-- Error -->
        <p v-if="saveError" class="text-red-400 text-sm">{{ saveError }}</p>

        <div class="flex gap-3 justify-end">
          <RouterLink to="/admin/dashboard" class="btn-secondary">Cancel</RouterLink>
          <button type="submit" :disabled="saving" class="btn-primary">
            {{ saving ? 'Saving…' : 'Save Draft & Review →' }}
          </button>
        </div>
      </form>
    </main>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import AdminNav from '../../components/AdminNav.vue'
import ImageUpload from '../../components/ImageUpload.vue'
import { supabase } from '../../lib/supabase.js'
import { generateSlotTimes, addMinutes } from '../../lib/timeUtils.js'

const router = useRouter()
const saving    = ref(false)
const saveError = ref('')
const coverFile = ref(null)   // File object selected via ImageUpload

const form = ref({
  name: '',
  tagline: '',
  description: '',
  district_link: '',
  days: [],
})

async function uploadCover(trainId) {
  if (!coverFile.value) return null
  const ext  = coverFile.value.name.split('.').pop().toLowerCase()
  const path = `${trainId}/cover.${ext}`
  const { error } = await supabase.storage
    .from('train-graphics')
    .upload(path, coverFile.value, { upsert: true })
  if (error) throw error
  const { data } = supabase.storage.from('train-graphics').getPublicUrl(path)
  return data.publicUrl
}

function addDay() {
  form.value.days.push({
    day_date: '',
    day_label: '',
    start_time: '10:30',
    slot_duration: 30,
    slot_count: 24,
    pre_assigned: [],
  })
}

function removeDay(i) {
  form.value.days.splice(i, 1)
}

function addPreAssigned(di) {
  form.value.days[di].pre_assigned.push({
    username: '',
    time: '10:00',
    duration_min: 30,
    label: '',
  })
}

function removePreAssigned(di, si) {
  form.value.days[di].pre_assigned.splice(si, 1)
}

function formatDisplayTime(t) {
  if (!t) return '—'
  const [h, m] = t.split(':').map(Number)
  const ampm = h < 12 ? 'AM' : 'PM'
  const hh = h === 0 ? 12 : h > 12 ? h - 12 : h
  return `${hh}:${String(m).padStart(2, '0')} ${ampm}`
}

async function saveAndContinue() {
  saveError.value = ''
  saving.value = true

  try {
    // 1. Insert train (cover_url filled in after upload)
    const { data: train, error: trainErr } = await supabase
      .from('trains')
      .insert({
        name: form.value.name,
        tagline: form.value.tagline || null,
        description: form.value.description || null,
        district_link: form.value.district_link || null,
        cover_url: null,
        published: false,
      })
      .select()
      .single()

    if (trainErr) throw trainErr

    // 2. Upload graphic and update cover_url
    if (coverFile.value) {
      const url = await uploadCover(train.id)
      if (url) {
        await supabase.from('trains').update({ cover_url: url }).eq('id', train.id)
        train.cover_url = url
      }
    }

    // 2. Insert days + slots
    for (let di = 0; di < form.value.days.length; di++) {
      const day = form.value.days[di]

      const { data: trainDay, error: dayErr } = await supabase
        .from('train_days')
        .insert({
          train_id: train.id,
          day_date: day.day_date,
          day_label: day.day_label || null,
          day_order: di,
        })
        .select()
        .single()

      if (dayErr) throw dayErr

      // Build pre-assigned lookup by time
      const preMap = {}
      for (const p of day.pre_assigned) {
        if (p.time) preMap[p.time] = p
      }

      // Generate open slot times
      const openTimes = generateSlotTimes(
        day.start_time,
        day.slot_duration,
        day.slot_count
      )

      // Merge: open slots, overwritten by pre-assigned where times match
      const allTimes = new Set([...openTimes, ...day.pre_assigned.map(p => p.time)])
      const sortedTimes = [...allTimes].sort()

      const slotsToInsert = sortedTimes.map((t, idx) => {
        const pre = preMap[t]
        if (pre) {
          return {
            train_day_id: trainDay.id,
            start_time: t,
            duration_min: pre.duration_min || day.slot_duration,
            username: pre.username || null,
            label: pre.label || null,
            is_pre_assigned: true,
            slot_order: idx,
          }
        }
        return {
          train_day_id: trainDay.id,
          start_time: t,
          duration_min: day.slot_duration,
          username: null,
          label: null,
          is_pre_assigned: false,
          slot_order: idx,
        }
      })

      const { error: slotsErr } = await supabase.from('slots').insert(slotsToInsert)
      if (slotsErr) throw slotsErr
    }

    router.push(`/admin/trains/${train.id}`)
  } catch (e) {
    saveError.value = e.message || 'Failed to save. Check Supabase connection.'
  } finally {
    saving.value = false
  }
}
</script>
