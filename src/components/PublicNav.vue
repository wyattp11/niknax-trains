<template>
  <header class="bg-surface border-b border-bd px-6 py-4 flex items-center justify-between">
    <RouterLink to="/" class="flex items-center gap-2 hover:opacity-80 transition-opacity">
      <span class="text-xl">🚂</span>
      <span class="font-bold font-display text-tx1 hidden sm:block">Niknax Raid Trains</span>
    </RouterLink>

    <div class="flex items-center gap-2">
      <slot />

      <!-- Theme toggle -->
      <button
        @click="theme.toggle()"
        :title="theme.isDark ? 'Switch to light mode' : 'Switch to dark mode'"
        :aria-label="theme.isDark ? 'Switch to light mode' : 'Switch to dark mode'"
        class="w-9 h-9 flex items-center justify-center rounded-lg text-tx2 hover:bg-sur2 transition-colors"
      >
        <span v-if="theme.isDark" class="text-lg" aria-hidden="true">☀️</span>
        <span v-else class="text-lg" aria-hidden="true">🌙</span>
      </button>

      <!-- Sound toggle -->
      <button
        @click="theme.toggleSound()"
        :title="theme.isSoundMuted ? 'Turn on sounds' : 'Mute sounds'"
        :aria-label="theme.isSoundMuted ? 'Turn on sounds' : 'Mute sounds'"
        :aria-pressed="theme.isSoundMuted"
        class="w-9 h-9 flex items-center justify-center rounded-lg text-tx2 hover:bg-sur2 transition-colors"
      >
        <span class="text-lg" aria-hidden="true">{{ theme.isSoundMuted ? '🔇' : '🔊' }}</span>
      </button>

      <!-- Palm Springs theme toggle -->
      <button
        @click="theme.togglePalm()"
        :title="theme.isPalm ? 'Turn off Palm Springs theme' : 'Turn on Palm Springs theme'"
        :aria-label="theme.isPalm ? 'Turn off Palm Springs theme' : 'Turn on Palm Springs theme'"
        :aria-pressed="theme.isPalm"
        class="w-9 h-9 flex items-center justify-center rounded-lg transition-colors"
        :class="theme.isPalm ? 'bg-niknax-600 text-white' : 'text-tx2 hover:bg-sur2'"
      >
        <span class="text-lg" aria-hidden="true">🌴</span>
      </button>

      <RouterLink to="/admin" class="text-tx3 hover:text-tx2 text-xs px-2 py-1 rounded transition-colors">
        Admin
      </RouterLink>
    </div>
  </header>
</template>

<script setup>
import { RouterLink } from 'vue-router'
import { useThemeStore } from '../stores/theme.js'
const theme = useThemeStore()
</script>
