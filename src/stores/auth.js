import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '../lib/supabase.js'

export const useAuthStore = defineStore('auth', () => {
  const initialized = ref(false)
  const loading = ref(false)
  const session = ref(null)
  const user = ref(null)
  const isAdmin = ref(false)

  async function refreshAdminStatus() {
    if (!session.value) {
      isAdmin.value = false
      return false
    }

    const { data, error } = await supabase.rpc('is_admin')
    isAdmin.value = !error && data === true
    return isAdmin.value
  }

  async function initialize() {
    if (initialized.value) return
    loading.value = true

    const { data } = await supabase.auth.getSession()
    session.value = data.session
    user.value = data.session?.user || null
    await refreshAdminStatus()

    supabase.auth.onAuthStateChange((_event, nextSession) => {
      session.value = nextSession
      user.value = nextSession?.user || null
      if (!nextSession) {
        isAdmin.value = false
        return
      }
      setTimeout(() => { refreshAdminStatus() }, 0)
    })

    loading.value = false
    initialized.value = true
  }

  async function login(email, password) {
    loading.value = true
    const { data, error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) {
      loading.value = false
      return { ok: false, message: error.message }
    }

    session.value = data.session
    user.value = data.user
    const admin = await refreshAdminStatus()
    loading.value = false

    if (!admin) {
      await logout()
      return { ok: false, message: 'This account is not authorized for Niknax admin.' }
    }

    return { ok: true }
  }

  async function logout() {
    await supabase.auth.signOut()
    session.value = null
    user.value = null
    isAdmin.value = false
  }

  return { initialized, loading, session, user, isAdmin, initialize, login, logout }
})
