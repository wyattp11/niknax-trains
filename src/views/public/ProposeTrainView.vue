<template>
  <div class="min-h-screen bg-base">
    <PublicNav />

    <main class="max-w-2xl mx-auto px-6 py-12">
      <RouterLink to="/" class="text-niknax-600 hover:text-niknax-500 dark:text-niknax-400 dark:hover:text-niknax-300 text-sm mb-8 inline-block">
        ← Back to trains
      </RouterLink>

      <div class="mb-8">
        <h1 class="text-3xl font-display font-bold text-tx1 mb-2">Propose a Train</h1>
        <p class="text-tx3">
          Want to host a Niknax Raid Train? Fill this out and the team will review your idea.
        </p>
      </div>

      <!-- Success -->
      <div v-if="submitted" class="card text-center py-12">
        <div class="text-5xl mb-4">🚂</div>
        <h2 class="text-xl font-semibold text-tx1 mb-2">Proposal submitted!</h2>
        <p class="text-tx3 mb-6">The Niknax team will reach out to you via District or Niknax to follow up.</p>
        <button @click="reset" class="btn-secondary">Submit another</button>
      </div>

      <!-- Form -->
      <form v-else @submit.prevent="submit" class="card space-y-6">
        <div>
          <label class="label" for="prop-name">Event Name *</label>
          <input
            id="prop-name"
            v-model="form.name"
            class="input"
            placeholder="e.g. Glass Gallery: Summer Shimmer"
            required
            maxlength="120"
          />
        </div>

        <div>
          <label class="label" for="prop-tagline">Tagline</label>
          <input
            id="prop-tagline"
            v-model="form.tagline"
            class="input"
            placeholder="One-sentence description of your event"
            maxlength="200"
          />
        </div>

        <div>
          <label class="label" for="prop-date">Proposed Date(s)</label>
          <input
            id="prop-date"
            v-model="form.proposed_date"
            class="input"
            placeholder='e.g. "mid-August" or "August 15–16"'
            maxlength="100"
          />
          <p class="text-xs text-tx3 mt-1">Approximate is fine — the team will confirm.</p>
        </div>

        <div>
          <label class="label" for="prop-username">Your District / Niknax Username *</label>
          <div class="relative">
            <span class="absolute left-3 top-1/2 -translate-y-1/2 text-tx3 select-none">@</span>
            <input
              id="prop-username"
              v-model="form.contact_username"
              class="input pl-7"
              placeholder="yourhandle"
              required
              maxlength="60"
            />
          </div>
          <p class="text-xs text-tx3 mt-1">This is how the team will contact you.</p>
        </div>

        <div>
          <label class="label" for="prop-message">Anything else to share?</label>
          <textarea
            id="prop-message"
            v-model="form.message"
            class="input"
            rows="4"
            placeholder="Theme ideas, special sellers you'd like to include, questions…"
            maxlength="1000"
          />
        </div>

        <p v-if="error" class="text-red-600 dark:text-red-400 text-sm" role="alert">{{ error }}</p>

        <div class="flex justify-end">
          <button type="submit" :disabled="submitting" class="btn-primary">
            {{ submitting ? 'Submitting…' : 'Submit Proposal →' }}
          </button>
        </div>
      </form>
    </main>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { RouterLink } from 'vue-router'
import PublicNav from '../../components/PublicNav.vue'
import { supabase } from '../../lib/supabase.js'

const submitting = ref(false)
const submitted  = ref(false)
const error      = ref('')

const defaultForm = () => ({
  name:             '',
  tagline:          '',
  proposed_date:    '',
  contact_username: '',
  message:          '',
})

const form = ref(defaultForm())

async function submit() {
  error.value = ''
  submitting.value = true

  // Strip leading @ if user typed it in the username field
  const username = form.value.contact_username.trim().replace(/^@+/, '')

  const { error: dbError } = await supabase
    .from('train_proposals')
    .insert({
      name:             form.value.name.trim(),
      tagline:          form.value.tagline.trim() || null,
      proposed_date:    form.value.proposed_date.trim() || null,
      contact_username: username,
      message:          form.value.message.trim() || null,
    })

  if (dbError) {
    error.value = dbError.message || 'Something went wrong. Please try again.'
  } else {
    submitted.value = true
  }

  submitting.value = false
}

function reset() {
  form.value  = defaultForm()
  submitted.value = false
  error.value = ''
}
</script>
