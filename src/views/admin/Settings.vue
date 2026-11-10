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

        <!-- ── Graphics bandwidth ── -->
        <section class="card space-y-4">
          <div>
            <h2 class="font-semibold text-niknax-600 dark:text-niknax-300">Optimize Graphics</h2>
            <p class="text-xs text-tx3 mt-1">
              Train graphics uploaded before November 2026 were stored full-size, and the site
              loaded them in full even for small thumbnails — that's what used up the Supabase
              bandwidth quota. This shrinks each one (up to 1600 px, plus a small thumbnail)
              and points the train at the new copy. Graphics still look the same. Safe to run
              more than once; already-optimized trains are skipped.
            </p>
          </div>

          <p class="text-sm text-tx2">
            <strong>{{ unoptimized.length }}</strong> of {{ coverTrains.length }} train graphics need optimizing.
          </p>

          <div v-if="optimizing || optimizeLog.length" class="bg-sur2 rounded-lg p-3 max-h-48 overflow-y-auto text-xs font-mono space-y-0.5">
            <p v-for="(line, i) in optimizeLog" :key="i" :class="line.startsWith('✗') ? 'text-red-600 dark:text-red-400' : 'text-tx2'">{{ line }}</p>
          </div>

          <div class="flex justify-end">
            <button
              @click="optimizeAll"
              :disabled="optimizing || !unoptimized.length"
              class="btn-primary disabled:opacity-50"
            >{{ optimizing ? `Optimizing… ${optimizeDone}/${optimizeTotal}` : 'Optimize graphics' }}</button>
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
import { uploadCover, isUnoptimizedCover } from '../../lib/coverImages.js'

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

// ── Optimize graphics ─────────────────────────────────────────────────────
const coverTrains   = ref([])
const optimizing    = ref(false)
const optimizeLog   = ref([])
const optimizeDone  = ref(0)
const optimizeTotal = ref(0)

const unoptimized = computed(() => coverTrains.value.filter(t => isUnoptimizedCover(t.cover_url)))

async function loadCoverTrains() {
  const { data } = await supabase.from('trains').select('id, name, cover_url').not('cover_url', 'is', null)
  coverTrains.value = data || []
}

async function optimizeAll() {
  optimizing.value    = true
  optimizeLog.value   = []
  optimizeDone.value  = 0
  const list = [...unoptimized.value]
  optimizeTotal.value = list.length

  // One at a time: gentle on bandwidth, and a failure only affects one train.
  for (const t of list) {
    try {
      const res = await fetch(t.cover_url, { cache: 'no-store' })
      if (!res.ok) throw new Error(`download failed (${res.status})`)
      const original = await res.blob()
      const url = await uploadCover(t.id, original)
      const { error } = await supabase.from('trains').update({ cover_url: url }).eq('id', t.id)
      if (error) throw error
      t.cover_url = url
      optimizeLog.value.push(`✓ ${t.name} — ${(original.size / 1048576).toFixed(1)} MB → optimized`)
    } catch (err) {
      optimizeLog.value.push(`✗ ${t.name} — ${err.message || err}`)
    }
    optimizeDone.value++
  }
  optimizing.value = false
}

onMounted(() => { load(); loadCoverTrains() })
</script>
