import { defineStore } from 'pinia'
import { ref } from 'vue'

export const useThemeStore = defineStore('theme', () => {
  // Default to dark; only light if user explicitly chose it
  const isDark = ref(localStorage.getItem('niknax_theme') !== 'light')

  function apply() {
    document.documentElement.classList.toggle('dark', isDark.value)
  }

  function toggle() {
    isDark.value = !isDark.value
    localStorage.setItem('niknax_theme', isDark.value ? 'dark' : 'light')
    apply()
  }

  // Apply immediately on store creation
  apply()

  return { isDark, toggle }
})
