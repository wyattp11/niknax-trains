<template>
  <div class="min-h-screen bg-base">
    <PublicNav />

    <main class="max-w-3xl mx-auto px-6 py-12">
      <RouterLink to="/" class="text-niknax-600 hover:text-niknax-500 dark:text-niknax-400 dark:hover:text-niknax-300 text-sm mb-8 inline-block">
        ← Back to trains
      </RouterLink>

      <!-- ── Success ─────────────────────────────────────────────────────── -->
      <div v-if="createdTrainId" class="card text-center py-14">
        <div class="text-5xl mb-4">🚂</div>
        <h1 class="text-2xl font-display font-bold text-tx1 mb-2">Train submitted!</h1>
        <p class="text-tx3 mb-2">Your train is pending review by the Niknax team.</p>
        <p class="text-tx3 mb-8 text-sm">
          Once approved, it'll appear on the public schedule and sellers can start signing up.
          You'll get a notification when it's live.
        </p>
        <div class="flex flex-col sm:flex-row gap-3 justify-center">
          <RouterLink :to="`/train/${createdTrainId}/conductor`" class="btn-primary">
            Manage Your Train →
          </RouterLink>
          <RouterLink to="/" class="btn-secondary">Back to home</RouterLink>
        </div>
      </div>

      <template v-else>
        <div class="mb-8">
          <h1 class="text-3xl font-display font-bold text-tx1 mb-2">Create a Train</h1>
          <p class="text-tx3">
            Build your own Niknax Raid Train. The Niknax team will review and publish it once everything looks good.
          </p>
        </div>

        <!-- ── Step 1: Username gate ────────────────────────────────────── -->
        <div v-if="!conductorUsername" class="card space-y-5 max-w-md">
          <h2 class="text-lg font-semibold text-tx1">First, who are you?</h2>
          <p class="text-sm text-tx3">
            Train creation is available to authorized Niknax sellers. Enter your District / Niknax username to continue.
          </p>
          <form @submit.prevent="verifyUsername" class="space-y-4">
            <div>
              <label class="label" for="gate-username">Your username</label>
              <div class="relative">
                <span class="absolute left-3 top-1/2 -translate-y-1/2 text-tx3 select-none">@</span>
                <input
                  id="gate-username"
                  v-model="gateUsername"
                  class="input pl-7"
                  placeholder="yourhandle"
                  required
                  maxlength="60"
                  :disabled="gateLoading"
                />
              </div>
            </div>
            <p v-if="gateError" class="text-red-600 dark:text-red-400 text-sm" role="alert">{{ gateError }}</p>
            <button type="submit" :disabled="gateLoading" class="btn-primary w-full">
              {{ gateLoading ? 'Checking…' : 'Continue →' }}
            </button>
          </form>
        </div>

        <!-- ── Step 2: Train creation form ──────────────────────────────── -->
        <div v-else class="space-y-8">
          <p class="text-sm text-tx3">
            Creating as <strong class="text-tx1">@{{ conductorUsername }}</strong> ·
            <button @click="conductorUsername = ''" class="text-niknax-600 dark:text-niknax-400 hover:underline text-sm">change</button>
          </p>

          <form @submit.prevent="submitTrain" class="space-y-8">

            <!-- Event details -->
            <section class="card space-y-5">
              <h2 class="text-lg font-semibold text-niknax-600 dark:text-niknax-300">Event Details</h2>

              <div>
                <label class="label">Event Name *</label>
                <input v-model="form.name" class="input" placeholder="e.g. Glass Gallery: Summer Shimmer" required maxlength="120" />
              </div>

              <div>
                <label class="label">Tagline</label>
                <input v-model="form.tagline" class="input" placeholder="One-sentence hook for your event" maxlength="200" />
              </div>

              <div>
                <label class="label">Description</label>
                <textarea v-model="form.description" class="input" rows="3" placeholder="What makes this train special?" />
              </div>

              <div>
                <label class="label">District / Niknax Event Link</label>
                <input v-model="form.district_link" class="input" type="url" placeholder="https://districtapp.tv/… or https://niknax.net/…" />
              </div>

              <div class="bg-sur2 rounded-lg p-4 text-sm text-tx3">
                <strong class="text-tx2">Note:</strong> A train graphic can be added by the Niknax team after approval.
              </div>
            </section>

            <!-- Days & slots -->
            <section class="card space-y-5">
              <div class="flex items-center justify-between">
                <h2 class="text-lg font-semibold text-niknax-600 dark:text-niknax-300">Event Days</h2>
                <button type="button" @click="addDay" class="btn-secondary text-sm py-1.5">+ Add Day</button>
              </div>

              <div v-if="form.days.length === 0" class="text-tx3 text-sm italic">
                No days yet — click "+ Add Day" above.
              </div>

              <div
                v-for="(day, di) in form.days"
                :key="di"
                class="border border-bd rounded-lg p-4 space-y-4"
              >
                <div class="flex items-center justify-between">
                  <span class="font-medium text-tx2">Day {{ di + 1 }}</span>
                  <button type="button" @click="removeDay(di)" class="text-red-600 hover:text-red-500 dark:text-red-400 dark:hover:text-red-300 text-sm">Remove</button>
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

                <div class="bg-sur2 rounded-lg p-4 space-y-3">
                  <p class="text-sm text-tx2 font-medium">Slot Schedule</p>
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
                  <p class="text-xs text-tx3">
                    Generates a 10-min Kickoff row at {{ displayTime(day.start_time) }} ET, then
                    {{ day.slot_count }} open seller slots of {{ day.slot_duration }} min each.
                  </p>
                </div>
              </div>
            </section>

            <!-- Rules -->
            <section class="card space-y-3">
              <h2 class="text-lg font-semibold text-niknax-600 dark:text-niknax-300">Sign-Up Rules &amp; Criteria</h2>
              <p class="text-xs text-tx3">Shown to sellers before they can claim a slot. Pre-filled with the standard template.</p>
              <textarea v-model="form.rules_md" class="input font-mono text-xs" rows="12" />
            </section>

            <p v-if="saveError" class="text-red-600 dark:text-red-400 text-sm" role="alert">{{ saveError }}</p>

            <div class="flex flex-col-reverse sm:flex-row gap-3 sm:justify-end">
              <RouterLink to="/" class="btn-secondary text-center w-full sm:w-auto">Cancel</RouterLink>
              <button type="submit" :disabled="saving" class="btn-primary w-full sm:w-auto">
                {{ saving ? 'Submitting…' : 'Submit Train for Review →' }}
              </button>
            </div>
          </form>
        </div>
      </template>
    </main>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { RouterLink } from 'vue-router'
import PublicNav from '../../components/PublicNav.vue'
import { supabase } from '../../lib/supabase.js'
import { setConductorSession } from '../../lib/conductorAuth.js'
import { DEFAULT_RULES_TEMPLATE } from '../../lib/defaultRulesTemplate.js'

// ── Gate ──────────────────────────────────────────────────────────────────
const gateUsername = ref('')
const gateLoading  = ref(false)
const gateError    = ref('')
const conductorUsername = ref('')

async function verifyUsername() {
  gateError.value   = ''
  gateLoading.value = true
  const handle = gateUsername.value.trim().replace(/^@+/, '').toLowerCase()

  const { data } = await supabase
    .from('members_signup_search')
    .select('username')
    .eq('username_key', handle)
    .maybeSingle()

  if (!data) {
    gateError.value = 'Sorry — that username isn\'t on the authorized sellers list. Contact the Niknax team if you think this is a mistake.'
  } else {
    conductorUsername.value = data.username
  }
  gateLoading.value = false
}

// ── Form ──────────────────────────────────────────────────────────────────
const saving         = ref(false)
const saveError      = ref('')
const createdTrainId = ref(null)

const defaultDay = () => ({
  day_date:      '',
  day_label:     '',
  start_time:    '10:30',
  slot_duration: 30,
  slot_count:    24,
})

const form = ref({
  name:         '',
  tagline:      '',
  description:  '',
  district_link: '',
  rules_md:     DEFAULT_RULES_TEMPLATE,
  days:         [],
})

function addDay()       { form.value.days.push(defaultDay()) }
function removeDay(i)   { form.value.days.splice(i, 1) }

function displayTime(t) {
  if (!t) return '—'
  const [h, m] = t.split(':').map(Number)
  const ampm = h < 12 ? 'AM' : 'PM'
  const hh = h === 0 ? 12 : h > 12 ? h - 12 : h
  return `${hh}:${String(m).padStart(2, '0')} ${ampm}`
}

async function submitTrain() {
  saveError.value = ''
  saving.value    = true

  const { data, error } = await supabase.rpc('create_member_train', {
    p_username:      conductorUsername.value,
    p_name:          form.value.name.trim(),
    p_tagline:       form.value.tagline.trim() || null,
    p_description:   form.value.description.trim() || null,
    p_district_link: form.value.district_link.trim() || null,
    p_rules_md:      form.value.rules_md.trim() || null,
    p_days:          form.value.days,
  })

  if (error) {
    saveError.value = error.message || 'Could not create train. Please try again.'
  } else {
    // Store conductor session so they land on the management view immediately
    setConductorSession(data.id, conductorUsername.value)
    createdTrainId.value = data.id
  }

  saving.value = false
}
</script>
