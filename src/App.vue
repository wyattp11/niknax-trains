<template>
  <RouterView />
  <OnboardingTour />
</template>

<script setup>
import { RouterView } from 'vue-router'
import { useThemeStore } from './stores/theme.js'
import OnboardingTour from './components/OnboardingTour.vue'

// Init theme on app mount (applies .dark class to <html>)
useThemeStore()
</script>
