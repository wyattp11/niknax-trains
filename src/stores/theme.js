import { defineStore } from 'pinia'
import { ref } from 'vue'

export const useThemeStore = defineStore('theme', () => {
  // Default to dark; only light if user explicitly chose it
  const isDark = ref(localStorage.getItem('niknax_theme') !== 'light')
  // Palm Springs accent theme — off by default
  const isPalm = ref(localStorage.getItem('niknax_palm') === 'on')

  function apply() {
    document.documentElement.classList.toggle('dark', isDark.value)
    document.documentElement.classList.toggle('palm', isPalm.value)
  }

  function toggle() {
    isDark.value = !isDark.value
    localStorage.setItem('niknax_theme', isDark.value ? 'dark' : 'light')
    apply()
  }

  function togglePalm() {
    isPalm.value = !isPalm.value
    localStorage.setItem('niknax_palm', isPalm.value ? 'on' : 'off')
    apply()
  }

  // Apply immediately on store creation
  apply()

  return { isDark, isPalm, toggle, togglePalm }
})
