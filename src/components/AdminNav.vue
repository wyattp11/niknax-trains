<template>
  <header class="bg-gray-900 border-b border-gray-800 px-6 py-4 flex items-center justify-between">
    <RouterLink to="/admin/dashboard" class="flex items-center gap-2 hover:opacity-80 transition-opacity">
      <span class="text-xl">✨</span>
      <span class="font-bold text-white font-display">Niknax Admin</span>
    </RouterLink>
    <div class="flex items-center gap-4">
      <RouterLink to="/" target="_blank" class="text-gray-400 hover:text-white text-sm">
        Public site ↗
      </RouterLink>
      <button @click="logout" class="text-gray-500 hover:text-white text-sm">Sign out</button>
    </div>
  </header>
</template>

<script setup>
import { RouterLink, useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth.js'

const auth   = useAuthStore()
const router = useRouter()

function logout() {
  auth.logout()
  router.push('/admin')
}
</script>
