<template>
  <header class="bg-surface border-b border-bd px-4 py-3 flex flex-wrap items-center justify-center gap-2 sm:justify-start sm:gap-3 overflow-x-hidden">
    <!-- Brand -->
    <RouterLink to="/admin/dashboard" class="order-1 flex items-center gap-2 sm:mr-4 hover:opacity-80 transition-opacity shrink-0">
      <span class="text-xl">✨</span>
      <span class="font-bold text-tx1 font-display hidden sm:block">Niknax Admin</span>
    </RouterLink>

    <!-- Primary nav -->
    <nav class="order-3 sm:order-2 flex items-center gap-1 w-full sm:w-auto sm:flex-1 min-w-0 overflow-x-auto pb-0.5 sm:pb-0">
      <RouterLink
        to="/admin/dashboard"
        class="px-3 py-1.5 rounded-lg text-sm font-medium whitespace-nowrap transition-colors shrink-0"
        :class="isActive('/admin/dashboard') ? 'bg-niknax-600 text-white' : 'text-tx2 hover:bg-sur2 hover:text-tx1'"
      >
        Dashboard
      </RouterLink>
      <RouterLink
        to="/admin/trains/new"
        class="px-3 py-1.5 rounded-lg text-sm font-medium whitespace-nowrap transition-colors shrink-0"
        :class="isActive('/admin/trains/new') ? 'bg-niknax-600 text-white' : 'text-tx2 hover:bg-sur2 hover:text-tx1'"
      >
        + New Train
      </RouterLink>
      <RouterLink
        to="/admin/members"
        class="px-3 py-1.5 rounded-lg text-sm font-medium whitespace-nowrap transition-colors shrink-0"
        :class="isActive('/admin/members') ? 'bg-niknax-600 text-white' : 'text-tx2 hover:bg-sur2 hover:text-tx1'"
      >
        Members
      </RouterLink>
    </nav>

    <!-- Right side controls -->
    <div class="order-2 sm:order-3 flex items-center justify-center gap-1.5 sm:ml-auto sm:justify-end sm:gap-2 shrink-0">
      <a href="/" target="_blank" class="hidden lg:flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-xs font-medium whitespace-nowrap text-tx2 hover:bg-sur2 hover:text-tx1 transition-colors">
        Public ↗
      </a>

      <!-- Theme toggle -->
      <button
        @click="theme.toggle()"
        :title="theme.isDark ? 'Switch to light mode' : 'Switch to dark mode'"
        :aria-label="theme.isDark ? 'Switch to light mode' : 'Switch to dark mode'"
        class="w-9 h-9 flex items-center justify-center rounded-lg text-tx2 hover:bg-sur2 hover:text-tx1 transition-colors shrink-0"
      >
        <ion-icon :name="theme.isDark ? 'sunny-outline' : 'moon-outline'" class="text-xl" aria-hidden="true"></ion-icon>
      </button>

      <!-- Sound toggle -->
      <button
        @click="theme.toggleSound()"
        :title="theme.isSoundMuted ? 'Turn on sounds' : 'Mute sounds'"
        :aria-label="theme.isSoundMuted ? 'Turn on sounds' : 'Mute sounds'"
        :aria-pressed="theme.isSoundMuted"
        class="w-9 h-9 flex items-center justify-center rounded-lg text-tx2 hover:bg-sur2 hover:text-tx1 transition-colors shrink-0"
      >
        <ion-icon :name="theme.isSoundMuted ? 'volume-mute-outline' : 'volume-high-outline'" class="text-xl" aria-hidden="true"></ion-icon>
      </button>

      <!-- Palm Springs theme toggle -->
      <button
        @click="theme.togglePalm()"
        :title="theme.isPalm ? 'Turn off Palm Springs theme' : 'Turn on Palm Springs theme'"
        :aria-label="theme.isPalm ? 'Turn off Palm Springs theme' : 'Turn on Palm Springs theme'"
        :aria-pressed="theme.isPalm"
        class="w-9 h-9 flex items-center justify-center rounded-lg transition-colors shrink-0"
        :class="theme.isPalm ? 'bg-niknax-600 text-white' : 'text-tx2 hover:bg-sur2 hover:text-tx1'"
      >
        <ion-icon name="leaf-outline" class="text-xl" aria-hidden="true"></ion-icon>
      </button>

      <button
        @click="logout"
        class="px-2.5 sm:px-3 py-1.5 rounded-lg text-sm font-medium whitespace-nowrap text-tx3 hover:text-tx1 hover:bg-sur2 transition-colors"
      >
        Sign out
      </button>
    </div>
  </header>
</template>

<script setup>
import { RouterLink, useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '../stores/auth.js'
import { useThemeStore } from '../stores/theme.js'

const auth   = useAuthStore()
const theme  = useThemeStore()
const router = useRouter()
const route  = useRoute()

function isActive(path) {
  return route.path === path || (path !== '/admin/dashboard' && route.path.startsWith(path))
}

async function logout() {
  await auth.logout()
  router.push('/admin')
}
</script>
