<template>
  <div class="min-h-screen flex items-center justify-center bg-gray-950 px-4">
    <div class="w-full max-w-sm">
      <div class="text-center mb-8">
        <div class="text-5xl mb-3">✨</div>
        <h1 class="text-2xl font-bold text-white font-display">Niknax Train Admin</h1>
        <p class="text-gray-400 mt-1">Enter your admin PIN to continue</p>
      </div>

      <form @submit.prevent="handleLogin" class="card space-y-4">
        <div>
          <label class="label">Admin PIN</label>
          <input
            v-model="pin"
            type="password"
            class="input"
            placeholder="••••••••"
            autocomplete="current-password"
          />
        </div>

        <p v-if="error" class="text-red-400 text-sm">{{ error }}</p>

        <button type="submit" class="btn-primary w-full">
          Sign In
        </button>
      </form>

      <p class="text-center mt-6">
        <RouterLink to="/" class="text-niknax-400 hover:text-niknax-300 text-sm">
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

const auth   = useAuthStore()
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
