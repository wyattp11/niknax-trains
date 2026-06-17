<template>
  <div class="min-h-screen flex items-center justify-center bg-base px-4">
    <!-- Theme toggle top-right -->
    <button
      @click="theme.toggle()"
      :aria-label="theme.isDark ? 'Switch to light mode' : 'Switch to dark mode'"
      class="fixed top-4 right-4 w-9 h-9 flex items-center justify-center rounded-lg text-tx3 hover:bg-sur2 transition-colors"
    >
      <span v-if="theme.isDark" aria-hidden="true">☀️</span>
      <span v-else aria-hidden="true">🌙</span>
    </button>

    <div class="w-full max-w-sm">
      <div class="text-center mb-8">
        <div class="text-5xl mb-3" aria-hidden="true">✨</div>
        <h1 class="text-2xl font-bold text-tx1 font-display">Niknax Train Admin</h1>
        <p class="text-tx3 mt-1">Enter your admin PIN to continue</p>
      </div>

      <form @submit.prevent="handleLogin" class="card space-y-4">
        <div>
          <label class="label" for="admin-pin">Admin PIN</label>
          <input
            id="admin-pin"
            v-model="pin"
            type="password"
            class="input"
            placeholder="••••••••"
            autocomplete="current-password"
          />
        </div>

        <p class="text-red-600 dark:text-red-400 text-sm min-h-[1.25rem]" aria-live="polite">{{ error }}</p>

        <button type="submit" class="btn-primary w-full">
          Sign In
        </button>
      </form>

      <p class="text-center mt-6">
        <RouterLink to="/" class="text-niknax-600 hover:text-niknax-500 dark:text-niknax-400 dark:hover:text-niknax-300 text-sm">
          ← Back to public site
        </RouterLink>
      </p>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter, RouterLink } from 'vue-router'
import { useAuthStore } from '../../stores/auth.js'
import { useThemeStore } from '../../stores/theme.js'

const auth   = useAuthStore()
const theme  = useThemeStore()
const router = useRouter()
const pin    = ref('')
const error  = ref('')

function handleLogin() {
  error.value = ''
  if (auth.login(pin.value)) {
    router.push('/admin/dashboard')
  } else {
    error.value = 'Incorrect PIN. Please try again.'
    pin.value = ''
  }
}
</script>
