import { defineStore } from 'pinia'
import { ref } from 'vue'

export const useAuthStore = defineStore('auth', () => {
  const isAdmin = ref(sessionStorage.getItem('niknax_admin') === '1')

  function login(pin) {
    const correctPin = import.meta.env.VITE_ADMIN_PIN
    if (!correctPin) {
      console.error('VITE_ADMIN_PIN is not set in .env.local')
      return false
    }
    if (pin === correctPin) {
      isAdmin.value = true
      sessionStorage.setItem('niknax_admin', '1')
      return true
    }
    return false
  }

  function logout() {
    isAdmin.value = false
    sessionStorage.removeItem('niknax_admin')
  }

  return { isAdmin, login, logout }
})
