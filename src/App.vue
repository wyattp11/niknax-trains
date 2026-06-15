<template>
  <RouterView />
</template>

<script setup>
import { RouterView } from 'vue-router'
import { useThemeStore } from './stores/theme.js'

// Init theme on app mount (applies .dark class to <html>)
useThemeStore()
</script>
