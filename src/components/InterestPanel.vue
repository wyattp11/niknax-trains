<template>
  <div class="card">
    <div class="flex flex-wrap items-start justify-between gap-3 mb-1">
      <h3 class="font-semibold text-[#B3123C]">
        Interested Sellers
        <span class="text-tx3 font-normal text-sm">({{ list.length }})</span>
      </h3>
      <button
        type="button"
        @click="load"
        :disabled="loading"
        class="text-xs text-tx3 hover:text-tx1 inline-flex items-center gap-1 disabled:opacity-50"
      >
        <ion-icon name="refresh-outline" aria-hidden="true"></ion-icon>
        {{ loading ? 'Loading…' : 'Refresh' }}
      </button>
    </div>
    <p class="text-xs text-tx3 mb-4">
      Sellers who tapped <strong>I'm interested</strong> while this train was Arriving Soon.
      Names are only visible here. A <span class="text-green-700 dark:text-green-400 font-semibold">✓</span>
      means they've since claimed a slot.
    </p>

    <!-- ── Settings ── -->
    <div class="bg-sur2 rounded-lg p-3 mb-4 space-y-3">
      <div class="flex flex-col sm:flex-row sm:items-end gap-2">
        <div class="flex-1">
          <label class="label" :for="`signups-open-${train.id}`">
            Sign-ups open <span class="font-normal text-tx3">(your local time, optional)</span>
          </label>
          <input
            :id="`signups-open-${train.id}`"
            v-model="openAtInput"
            type="datetime-local"
            class="input"
          />
        </div>
        <button
          v-if="openAtInput"
          type="button"
          @click="openAtInput = ''"
          class="btn-secondary text-sm py-2"
        >Clear</button>
      </div>
      <p class="text-xs text-tx3 -mt-1">
        Shows a countdown and a "Remind me" calendar button to the public. It doesn't open
        sign-ups by itself — switch the train to Now Boarding when it's time.
      </p>

      <label class="flex items-center gap-2 text-sm text-tx1 cursor-pointer">
        <input v-model="showCountInput" type="checkbox" class="w-4 h-4 accent-niknax-600" />
        Show how many sellers are interested on the public page
      </label>

      <div class="flex items-center gap-3">
        <button
          type="button"
          @click="saveSettings"
          :disabled="saving || !settingsDirty"
          class="btn-primary text-sm py-1.5 disabled:opacity-50"
        >{{ saving ? 'Saving…' : 'Save' }}</button>
        <span v-if="settingsSaved" class="text-xs text-green-700 dark:text-green-400" aria-live="polite">Saved</span>
        <span v-if="settingsError" class="text-xs text-red-600 dark:text-red-400" role="alert">{{ settingsError }}</span>
      </div>
    </div>

    <!-- ── List ── -->
    <p v-if="listError" class="text-sm text-red-600 dark:text-red-400 mb-3" role="alert">{{ listError }}</p>

    <template v-if="list.length">
      <p v-if="signedUpCount" class="text-xs text-tx3 mb-2">
        {{ signedUpCount }} signed up · {{ list.length - signedUpCount }} not yet
      </p>
      <ul class="flex flex-wrap gap-2 mb-4">
        <li
          v-for="m in list"
          :key="m.username"
          class="inline-flex items-center gap-1.5 rounded-full pl-3 pr-1.5 py-1"
          :class="m.signed_up ? 'bg-green-100 dark:bg-green-900/40' : 'bg-sur2'"
          :title="`Interested since ${formatWhen(m.created_at)}${m.signed_up ? ' · has a slot' : ''}`"
        >
          <span v-if="m.signed_up" class="text-green-700 dark:text-green-400 font-bold text-sm" aria-label="Signed up">✓</span>
          <span class="text-sm text-tx1">@{{ m.username }}</span>
          <button
            type="button"
            @click="remove(m)"
            :disabled="removing === m.username"
            class="w-5 h-5 rounded-full text-tx3 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-900/30
                   flex items-center justify-center text-xs disabled:opacity-50"
            :aria-label="`Remove @${m.username} from the interested list`"
          >✕</button>
        </li>
      </ul>

      <div class="flex flex-wrap gap-2">
        <button type="button" @click="copy('all')" class="btn-secondary text-xs py-1.5 inline-flex items-center gap-1.5">
          <ion-icon :name="copied === 'all' ? 'checkmark-circle-outline' : 'copy-outline'" aria-hidden="true"></ion-icon>
          {{ copied === 'all' ? 'Copied!' : 'Copy all usernames' }}
        </button>
        <button
          v-if="signedUpCount && signedUpCount < list.length"
          type="button"
          @click="copy('pending')"
          class="btn-secondary text-xs py-1.5 inline-flex items-center gap-1.5"
        >
          <ion-icon :name="copied === 'pending' ? 'checkmark-circle-outline' : 'copy-outline'" aria-hidden="true"></ion-icon>
          {{ copied === 'pending' ? 'Copied!' : "Copy who hasn't signed up" }}
        </button>
      </div>
    </template>
    <p v-else-if="!loading && !listError" class="text-sm text-tx3 italic">
      Nobody yet. Mark the train as Upcoming and share the link — the "I'm interested"
      button shows on the train page and home page card.
    </p>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { supabase } from '../lib/supabase.js'
import { toLocalInputValue, fromLocalInputValue } from '../lib/signupReminder.js'

/**
 * Interested-sellers list plus the two settings that go with it.
 *
 * Used by the admin train page (no token — writes the train row directly)
 * and by the conductor page (token — goes through the conductor RPC).
 */
const props = defineProps({
  train: { type: Object, required: true },
  token: { type: String, default: null },
})
const emit = defineEmits(['updated'])

const list      = ref([])
const loading   = ref(false)
const listError = ref('')
const removing  = ref(null)
const copied    = ref(null)

const openAtInput    = ref('')
const showCountInput = ref(true)
const saving         = ref(false)
const settingsSaved  = ref(false)
const settingsError  = ref('')

function syncFromTrain() {
  openAtInput.value    = toLocalInputValue(props.train.signups_open_at)
  showCountInput.value = props.train.show_interest_count !== false
}
watch(() => [props.train.signups_open_at, props.train.show_interest_count], syncFromTrain, { immediate: true })

const settingsDirty = computed(() =>
  fromLocalInputValue(openAtInput.value) !== normalizeIso(props.train.signups_open_at) ||
  showCountInput.value !== (props.train.show_interest_count !== false)
)

function normalizeIso(value) {
  if (!value) return null
  const d = new Date(value)
  return Number.isNaN(d.getTime()) ? null : d.toISOString()
}

const signedUpCount = computed(() => list.value.filter(m => m.signed_up).length)

async function load() {
  loading.value   = true
  listError.value = ''
  const { data, error } = await supabase.rpc('train_interest_list', {
    p_train_id: props.train.id,
    p_token:    props.token,
  })
  if (error) listError.value = error.message || 'Could not load the list.'
  else list.value = data || []
  loading.value = false
}

async function remove(member) {
  if (!confirm(`Remove @${member.username} from the interested list?`)) return
  removing.value = member.username
  const { error } = await supabase.rpc('remove_train_interest', {
    p_train_id: props.train.id,
    p_username: member.username,
    p_token:    props.token,
  })
  if (error) listError.value = error.message || 'Could not remove them.'
  else list.value = list.value.filter(m => m.username !== member.username)
  removing.value = null
}

async function saveSettings() {
  settingsError.value = ''
  settingsSaved.value = false
  saving.value = true

  const patch = {
    signups_open_at:     fromLocalInputValue(openAtInput.value),
    show_interest_count: showCountInput.value,
  }

  const { error } = props.token
    ? await supabase.rpc('set_member_train_interest_settings', {
        p_train_id:        props.train.id,
        p_token:           props.token,
        p_show_count:      patch.show_interest_count,
        p_signups_open_at: patch.signups_open_at,
      })
    : await supabase.from('trains').update(patch).eq('id', props.train.id)

  if (error) {
    settingsError.value = error.message || 'Could not save.'
  } else {
    emit('updated', patch)
    settingsSaved.value = true
    setTimeout(() => { settingsSaved.value = false }, 2000)
  }
  saving.value = false
}

async function copy(which) {
  const names = (which === 'pending' ? list.value.filter(m => !m.signed_up) : list.value)
    .map(m => `@${m.username}`)
    .join(' ')
  try {
    await navigator.clipboard.writeText(names)
    copied.value = which
    setTimeout(() => { copied.value = null }, 2000)
  } catch {
    listError.value = 'Copy failed — your browser blocked clipboard access.'
  }
}

function formatWhen(iso) {
  return new Date(iso).toLocaleString('en-US', {
    month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit',
  })
}

onMounted(load)
defineExpose({ load })
</script>
