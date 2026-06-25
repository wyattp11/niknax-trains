import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

// Keys
const SEEN_KEY     = 'niknax_onboarding_seen'   // localStorage — "has this browser seen the intro tour"
const CONTINUE_KEY = 'niknax_tour_continue'      // sessionStorage — cross-page handoff (e.g. 'signup')

export const useOnboardingStore = defineStore('onboarding', () => {
  const active       = ref(false)
  const steps        = ref([])
  const currentIndex = ref(0)

  const currentStep = computed(() => steps.value[currentIndex.value] || null)
  const isFirst     = computed(() => currentIndex.value === 0)
  const isLast      = computed(() => currentIndex.value === steps.value.length - 1)

  function hasSeenIntro() {
    return localStorage.getItem(SEEN_KEY) === 'yes'
  }

  function markIntroSeen() {
    localStorage.setItem(SEEN_KEY, 'yes')
  }

  /**
   * Start a tour.
   * @param {Array} newSteps - [{ target?: string, title, body, placement? }]
   */
  function start(newSteps) {
    if (!newSteps?.length) return
    steps.value = newSteps
    currentIndex.value = 0
    active.value = true
  }

  function next() {
    if (isLast.value) {
      finish()
      return
    }
    currentIndex.value += 1
  }

  function prev() {
    if (currentIndex.value > 0) currentIndex.value -= 1
  }

  function skip() {
    finish()
  }

  function finish() {
    active.value = false
    steps.value = []
    currentIndex.value = 0
  }

  // Cross-page handoff — e.g. Home tour's last step sets this, TrainView
  // checks it on mount to auto-continue the signup walkthrough.
  function setContinuation(name) {
    sessionStorage.setItem(CONTINUE_KEY, name)
  }

  function consumeContinuation(name) {
    const val = sessionStorage.getItem(CONTINUE_KEY)
    if (val === name) {
      sessionStorage.removeItem(CONTINUE_KEY)
      return true
    }
    return false
  }

  return {
    active, steps, currentIndex, currentStep, isFirst, isLast,
    hasSeenIntro, markIntroSeen,
    start, next, prev, skip, finish,
    setContinuation, consumeContinuation,
  }
})
