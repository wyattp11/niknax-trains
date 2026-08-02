<template>
  <div class="border border-bd rounded-xl bg-surface overflow-hidden">

    <!-- ── Collapsed strip ── -->
    <button
      type="button"
      @click="toggle"
      class="w-full flex items-center gap-3 px-4 py-2.5 text-left hover:bg-sur2 transition-colors"
      :aria-expanded="open"
      aria-controls="train-chat-panel"
    >
      <ion-icon name="chatbubbles-outline" class="text-lg text-niknax-600 dark:text-niknax-400 shrink-0" aria-hidden="true"></ion-icon>

      <span class="min-w-0 flex-1">
        <span v-if="latest" class="text-sm text-tx2 truncate block">
          <span class="font-semibold text-tx1">{{ latest.username }}</span>
          <span class="text-tx3"> · </span>{{ latest.body }}
        </span>
        <span v-else class="text-sm text-tx3 block">
          {{ locked ? 'Chat is locked for this event' : 'Train chat — say hi to the crew' }}
        </span>
      </span>

      <span
        v-if="unread > 0 && !open"
        class="shrink-0 text-xs font-bold px-2 py-0.5 rounded-full bg-niknax-600 text-white"
        :aria-label="`${unread} new messages`"
      >{{ unread > 99 ? '99+' : unread }}</span>

      <ion-icon
        :name="open ? 'chevron-up-outline' : 'chevron-down-outline'"
        class="text-base text-tx3 shrink-0"
        aria-hidden="true"
      ></ion-icon>
    </button>

    <!-- ── Expanded panel ── -->
    <div v-show="open" id="train-chat-panel" class="border-t border-bd">

      <!-- Messages -->
      <div
        ref="scrollRef"
        class="max-h-64 overflow-y-auto px-4 py-3 space-y-3"
        role="log"
        aria-live="polite"
        aria-label="Train chat messages"
      >
        <p v-if="loading" class="text-sm text-tx3 text-center py-6">Loading…</p>

        <p v-else-if="messages.length === 0" class="text-sm text-tx3 text-center py-6">
          No messages yet. Be the first to post.
        </p>

        <div v-for="m in messages" :key="m.id" class="group flex gap-2.5">
          <div class="min-w-0 flex-1">
            <p class="flex items-baseline gap-2 flex-wrap">
              <span class="text-sm font-semibold text-tx1">{{ m.username }}</span>
              <span v-if="m.role" class="text-[0.65rem] uppercase tracking-wide px-1.5 py-0.5 rounded bg-niknax-100 dark:bg-niknax-900/50 text-niknax-700 dark:text-niknax-300 font-semibold">
                {{ m.role }}
              </span>
              <span class="text-xs text-tx3">{{ timeAgo(m.created_at) }}</span>
            </p>
            <p class="text-sm text-tx2 break-words whitespace-pre-wrap">{{ m.body }}</p>
          </div>
          <button
            v-if="canModerate"
            type="button"
            @click="removeMessage(m)"
            :disabled="deletingId === m.id"
            class="shrink-0 self-start text-xs text-tx3 hover:text-red-600 dark:hover:text-red-400 opacity-0 group-hover:opacity-100 focus:opacity-100 transition-opacity disabled:opacity-50"
            :aria-label="`Delete message from ${m.username}`"
          >{{ deletingId === m.id ? '…' : '✕' }}</button>
        </div>
      </div>

      <!-- Composer -->
      <div class="border-t border-bd px-4 py-3 space-y-2">
        <p v-if="locked" class="text-sm text-tx3 text-center py-1">
          🔒 Chat is locked for this event.
        </p>

        <template v-else>
          <div class="flex gap-2">
            <div class="relative w-32 shrink-0">
              <span class="absolute left-2.5 top-1/2 -translate-y-1/2 text-tx3 text-sm select-none pointer-events-none">@</span>
              <input
                v-model="username"
                class="input py-1.5 text-sm pl-6"
                placeholder="username"
                maxlength="60"
                aria-label="Your username"
                @keyup.enter="send"
              />
            </div>
            <input
              v-model="draft"
              class="input py-1.5 text-sm flex-1 min-w-0"
              placeholder="Say something…"
              maxlength="500"
              aria-label="Message"
              @keyup.enter="send"
            />
            <button
              type="button"
              @click="send"
              :disabled="sending || !draft.trim() || !username.trim()"
              class="btn-primary text-sm py-1.5 px-3 shrink-0 disabled:opacity-50"
            >{{ sending ? '…' : 'Send' }}</button>
          </div>

          <p v-if="error" class="text-red-600 dark:text-red-400 text-xs" role="alert">{{ error }}</p>
          <p v-else class="text-xs text-tx3">
            Posting is open to authorized Niknax sellers. {{ 500 - draft.length }} characters left.
          </p>
        </template>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, nextTick, watch } from 'vue'
import { supabase } from '../lib/supabase.js'

const props = defineProps({
  trainId:     { type: String, required: true },
  locked:      { type: Boolean, default: false },
  canModerate: { type: Boolean, default: false },
  /** Username used when the conductor (not an admin) deletes a message. */
  actor:       { type: String, default: '' },
})

const STORAGE_KEY = 'niknax_chat_username'

const messages   = ref([])
const loading    = ref(true)
const open       = ref(false)
const unread     = ref(0)
const draft      = ref('')
const username   = ref('')
const sending    = ref(false)
const error      = ref('')
const deletingId = ref(null)
const scrollRef  = ref(null)

let channel = null

const latest = computed(() => messages.value[messages.value.length - 1] || null)

function toggle() {
  open.value = !open.value
  if (open.value) {
    unread.value = 0
    nextTick(scrollToBottom)
  }
}

function scrollToBottom() {
  if (scrollRef.value) scrollRef.value.scrollTop = scrollRef.value.scrollHeight
}

function timeAgo(iso) {
  const then = new Date(iso).getTime()
  const secs = Math.max(0, Math.floor((Date.now() - then) / 1000))
  if (secs < 60)    return 'just now'
  if (secs < 3600)  return `${Math.floor(secs / 60)}m ago`
  if (secs < 86400) return `${Math.floor(secs / 3600)}h ago`
  return new Date(iso).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
}

async function load() {
  const { data } = await supabase
    .from('train_chat_messages')
    .select('*')
    .eq('train_id', props.trainId)
    .order('created_at', { ascending: true })
    .limit(200)

  messages.value = data || []
  loading.value  = false
  if (open.value) nextTick(scrollToBottom)
}

async function send() {
  const body = draft.value.trim()
  const who  = username.value.trim()
  if (!body || !who || sending.value) return

  error.value   = ''
  sending.value = true

  const { data, error: err } = await supabase.rpc('post_chat_message', {
    p_train_id: props.trainId,
    p_username: who,
    p_body:     body,
  })

  if (err) {
    error.value = err.message || 'Could not send your message.'
  } else {
    draft.value = ''
    try { localStorage.setItem(STORAGE_KEY, who) } catch { /* private mode */ }
    // Realtime will usually deliver this, but insert optimistically in case
    // the subscription hasn't connected yet. De-duped by id below.
    if (data && !messages.value.some(m => m.id === data.id)) {
      messages.value.push(data)
      nextTick(scrollToBottom)
    }
  }
  sending.value = false
}

async function removeMessage(msg) {
  deletingId.value = msg.id
  const { error: err } = await supabase.rpc('delete_chat_message', {
    p_message_id: msg.id,
    p_actor:      props.actor || null,
  })
  if (!err) {
    messages.value = messages.value.filter(m => m.id !== msg.id)
  } else {
    error.value = err.message || 'Could not remove that message.'
  }
  deletingId.value = null
}

watch(() => messages.value.length, () => {
  if (open.value) nextTick(scrollToBottom)
})

onMounted(async () => {
  try {
    const saved = localStorage.getItem(STORAGE_KEY)
    if (saved) username.value = saved
  } catch { /* private mode */ }

  await load()

  channel = supabase
    .channel(`train-chat-${props.trainId}`)
    .on(
      'postgres_changes',
      {
        event:  'INSERT',
        schema: 'public',
        table:  'train_chat_messages',
        filter: `train_id=eq.${props.trainId}`,
      },
      (payload) => {
        const row = payload.new
        if (!row) return
        if (messages.value.some(m => m.id === row.id)) return
        messages.value.push(row)
        if (!open.value) unread.value++
      },
    )
    .on(
      'postgres_changes',
      {
        // DELETE payloads carry only the primary key, and aren't filterable
        // by column — so this fires for every train and we match on id.
        event:  'DELETE',
        schema: 'public',
        table:  'train_chat_messages',
      },
      (payload) => {
        const goneId = payload.old?.id
        if (goneId) messages.value = messages.value.filter(m => m.id !== goneId)
      },
    )
    .subscribe()
})

onUnmounted(() => {
  if (channel) supabase.removeChannel(channel)
})
</script>
