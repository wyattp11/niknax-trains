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
        <ion-icon :name="theme.isDark ? 'sunny-outline' : 'moon-outline'" class="text-xl" aria-hidden="true"></ion-icon>
      </button>

      <!-- Sound toggle -->
      <button
        @click="theme.toggleSound()"
        :title="theme.isSoundMuted ? 'Turn on sounds' : 'Mute sounds'"
        :aria-label="theme.isSoundMuted ? 'Turn on sounds' : 'Mute sounds'"
        :aria-pressed="theme.isSoundMuted"
        class="w-9 h-9 flex items-center justify-center rounded-lg text-tx2 hover:bg-sur2 transition-colors"
      >
        <ion-icon :name="theme.isSoundMuted ? 'volume-mute-outline' : 'volume-high-outline'" class="text-xl" aria-hidden="true"></ion-icon>
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
        <ion-icon name="leaf-outline" class="text-xl" aria-hidden="true"></ion-icon>
      </button>

      <RouterLink to="/create-train" class="text-niknax-600 hover:text-niknax-500 dark:text-niknax-400 dark:hover:text-niknax-300 text-xs font-medium px-2 py-1 rounded transition-colors whitespace-nowrap hidden sm:block">
        Create a Train
      </RouterLink>
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
