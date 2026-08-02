<template>
  <div class="min-h-screen bg-base">
    <AdminNav />

    <main class="max-w-3xl mx-auto px-6 py-10 space-y-6">
      <div>
        <h1 class="text-2xl font-display font-bold text-tx1">Settings</h1>
        <p class="text-sm text-tx3 mt-1">Site-wide options for Niknax Raid Trains.</p>
      </div>

      <div v-if="loading" class="text-tx3 text-center py-16">Loading…</div>

      <template v-else>
        <!-- ── Strike / accountability settings ── -->
        <section class="card space-y-5">
          <div>
            <h2 class="font-semibold text-niknax-600 dark:text-niknax-300">Seller Accountability</h2>
            <p class="text-xs text-tx3 mt-1">
              Sellers flagged for a no-show or rule violation sit out the next Niknax-sponsored
              train they try to join. Member-created trains are never affected, and NN
              owners/admins/moderators are exempt.
            </p>
          </div>

          <div>
            <label class="label" for="block-message">Block message</label>
            <textarea
              id="block-message"
              v-model="form.strike_block_message"
              class="input"
              rows="4"
              placeholder="Message shown to a flagged seller when they try to sign up."
            />
            <p class="text-xs text-tx3 mt-1.5">
              Placeholders:
              <code class="font-mono bg-sur2 px-1 py-0.5 rounded">{reason}</code> the reason (e.g. "a no-show"),
              <code class="font-mono bg-sur2 px-1 py-0.5 rounded">{train}</code> the event where it happened,
              <code class="font-mono bg-sur2 px-1 py-0.5 rounded">{username}</code> their handle.
            </p>
          </div>

          <div class="bg-sur2 rounded-lg p-4">
            <p class="text-xs font-medium text-tx2 mb-1.5">Preview</p>
            <p class="text-sm text-red-700 dark:text-red-300">{{ preview }}</p>
          </div>

          <div class="max-w-[16rem]">
            <label class="label" for="block-threshold">Points needed to block</label>
            <input
              id="block-threshold"
              v-model.number="form.strike_block_threshold"
              type="number"
              min="1"
              max="10"
              class="input"
            />
            <p class="text-xs text-tx3 mt-1.5">
              Each strike is worth 1 point by default. Leave at 1 so any single strike blocks.
            </p>
          </div>

          <p v-if="error" class="text-red-600 dark:text-red-400 text-sm" role="alert">{{ error }}</p>

          <div class="flex items-center gap-3 justify-end">
            <span v-if="saved" class="text-sm text-green-700 dark:text-green-400" aria-live="polite">Saved ✓</span>
            <button @click="save" :disabled="saving" class="btn-primary">
              {{ saving ? 'Saving…' : 'Save Settings' }}
            </button>
          </div>
        </section>
      </template>
    </main>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import AdminNav from '../../components/AdminNav.vue'
import { supabase } from '../../lib/supabase.js'

const DEFAULTS = {
  strike_block_message:
    "You're sitting out this event because of {reason} at {train}. You can still sign up for member-created trains. Reach out to the Niknax team if you think this is a mistake.",
  strike_block_threshold: 1,
}

const loading = ref(true)
const saving  = ref(false)
const saved   = ref(false)
const error   = ref('')
const form    = ref({ ...DEFAULTS })

const preview = computed(() =>
  (form.value.strike_block_message || '')
    .replace('{reason}', 'a no-show')
    .replace('{train}', 'Glass Gallery: Radiant Reflections')
    .replace('{username}', 'yourhandle')
)

async function load() {
  const { data } = await supabase.from('app_settings').select('key, value')
  for (const row of data || []) {
    if (row.key === 'strike_block_threshold') {
      form.value.strike_block_threshold = Number(row.value) || 1
    } else if (row.key in form.value) {
      form.value[row.key] = row.value ?? DEFAULTS[row.key]
    }
  }
  loading.value = false
}

async function save() {
  error.value  = ''
  saved.value  = false
  saving.value = true

  const rows = [
    { key: 'strike_block_message',   value: form.value.strike_block_message,          updated_at: new Date().toISOString() },
    { key: 'strike_block_threshold', value: String(form.value.strike_block_threshold), updated_at: new Date().toISOString() },
  ]

  const { error: err } = await supabase.from('app_settings').upsert(rows, { onConflict: 'key' })

  if (err) {
    error.value = err.message || 'Could not save settings.'
  } else {
    saved.value = true
    setTimeout(() => { saved.value = false }, 2500)
  }
  saving.value = false
}

onMounted(load)
</script>
