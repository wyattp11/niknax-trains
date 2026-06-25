<template>
  <Teleport to="body">
    <div v-if="store.active" class="tour-root">
      <!-- Full-screen click blocker + dim layer -->
      <div class="tour-blocker"></div>

      <!-- Spotlight cutout — transparent box whose giant box-shadow dims everything else -->
      <div
        v-if="rect"
        class="tour-spotlight"
        :style="spotlightStyle"
      ></div>

      <!-- Popover -->
      <div
        ref="popoverRef"
        class="tour-popover card"
        :style="popoverStyle"
        role="dialog"
        aria-modal="true"
        :aria-label="step?.title"
        tabindex="-1"
      >
        <div class="flex items-start justify-between gap-3 mb-2">
          <p class="text-xs font-mono uppercase tracking-widest text-niknax-600 dark:text-niknax-400">
            Step {{ store.currentIndex + 1 }} of {{ store.steps.length }}
          </p>
          <button @click="onSkip" class="text-tx3 hover:text-tx1 text-lg leading-none -mt-1" aria-label="Close walkthrough">
            <ion-icon name="close-outline" aria-hidden="true"></ion-icon>
          </button>
        </div>

        <h3 class="text-lg font-bold text-tx1 mb-1.5">{{ step?.title }}</h3>
        <p class="text-tx2 text-sm leading-relaxed mb-5">{{ step?.body }}</p>

        <div class="flex items-center justify-between gap-3">
          <button @click="onSkip" class="text-tx3 hover:text-tx1 text-sm font-medium">
            Skip tour
          </button>
          <div class="flex items-center gap-2">
            <button
              v-if="!store.isFirst"
              @click="store.prev()"
              class="btn-secondary text-sm px-3 py-1.5 flex items-center gap-1"
            >
              <ion-icon name="chevron-back-outline" aria-hidden="true"></ion-icon>
              Back
            </button>
            <button
              @click="onNext"
              class="btn-primary text-sm px-3 py-1.5 flex items-center gap-1"
            >
              {{ store.isLast ? 'Got it!' : 'Next' }}
              <ion-icon v-if="!store.isLast" name="chevron-forward-outline" aria-hidden="true"></ion-icon>
            </button>
          </div>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, computed, watch, onUnmounted, nextTick } from 'vue'
import { useOnboardingStore } from '../stores/onboarding.js'

const store = useOnboardingStore()
const step  = computed(() => store.currentStep)

const rect        = ref(null)   // { top, left, width, height } of target, viewport-relative
const popoverRef  = ref(null)
const popoverSize = ref({ width: 320, height: 180 })

const GAP = 14

// A selector can match a hidden duplicate (e.g. the mobile-only vs.
// desktop-only render of the same row) — pick the first one actually visible.
function findVisibleTarget(sel) {
  const els = document.querySelectorAll(sel)
  for (const el of els) {
    const r = el.getBoundingClientRect()
    if (r.width > 0 && r.height > 0) return el
  }
  return null
}

function measureTarget() {
  const sel = step.value?.target
  if (!sel) { rect.value = null; return }
  const el = findVisibleTarget(sel)
  if (!el) { rect.value = null; return }
  const r = el.getBoundingClientRect()
  rect.value = { top: r.top, left: r.left, width: r.width, height: r.height }
}

function updateAll() {
  measureTarget()
  nextTick(() => {
    if (popoverRef.value) {
      const r = popoverRef.value.getBoundingClientRect()
      popoverSize.value = { width: r.width || 320, height: r.height || 180 }
    }
  })
}

async function goToStep() {
  const sel = step.value?.target
  if (sel) {
    const el = findVisibleTarget(sel)
    if (el) {
      el.scrollIntoView({ behavior: 'smooth', block: 'center' })
      await new Promise(resolve => setTimeout(resolve, 320))
    }
  }
  updateAll()
  await nextTick()
  popoverRef.value?.focus?.()
}

watch(step, () => { if (store.active) goToStep() }, { immediate: true })

function onKeydown(e) {
  if (e.key === 'Escape') onSkip()
}

watch(() => store.active, (isActive) => {
  if (isActive) {
    document.body.style.overflow = 'hidden'
    window.addEventListener('resize', updateAll)
    window.addEventListener('keydown', onKeydown)
    goToStep()
  } else {
    document.body.style.overflow = ''
    window.removeEventListener('resize', updateAll)
    window.removeEventListener('keydown', onKeydown)
  }
})

onUnmounted(() => {
  document.body.style.overflow = ''
  window.removeEventListener('resize', updateAll)
  window.removeEventListener('keydown', onKeydown)
})

function onNext() {
  if (store.isLast) step.value?.onComplete?.()
  store.next()
}

function onSkip() {
  store.skip()
}

const spotlightStyle = computed(() => {
  if (!rect.value) return {}
  const pad = 6
  return {
    top:    `${rect.value.top - pad}px`,
    left:   `${rect.value.left - pad}px`,
    width:  `${rect.value.width + pad * 2}px`,
    height: `${rect.value.height + pad * 2}px`,
  }
})

const popoverStyle = computed(() => {
  const vw = window.innerWidth
  const vh = window.innerHeight
  const { width: pw, height: ph } = popoverSize.value

  if (!rect.value) {
    return { top: `${vh / 2}px`, left: `${vw / 2}px`, transform: 'translate(-50%, -50%)' }
  }

  const r = rect.value
  const placement = step.value?.placement
    || (vh - r.bottom > ph + GAP + 20 ? 'bottom' : r.top > ph + GAP + 20 ? 'top' : 'bottom')

  let top
  if (placement === 'top') {
    top = r.top - GAP
  } else {
    top = r.bottom + GAP
  }
  // Clamp vertically so it never runs off-screen
  top = Math.max(12, Math.min(top, vh - ph - 12))

  let left = r.left + r.width / 2 - pw / 2
  left = Math.max(12, Math.min(left, vw - pw - 12))

  const transform = placement === 'top' ? 'translateY(-100%)' : 'none'

  return { top: `${top}px`, left: `${left}px`, transform }
})
</script>

<style scoped>
.tour-root {
  position: fixed;
  inset: 0;
  z-index: 9999;
}

.tour-blocker {
  position: fixed;
  inset: 0;
  background: rgba(20, 16, 10, 0.55);
}

.tour-spotlight {
  position: fixed;
  border-radius: 10px;
  box-shadow: 0 0 0 9999px rgba(20, 16, 10, 0.55);
  border: 2px solid var(--brand-500);
  pointer-events: none;
  transition: top 0.25s ease, left 0.25s ease, width 0.25s ease, height 0.25s ease;
}

.tour-popover {
  position: fixed;
  width: 320px;
  max-width: calc(100vw - 24px);
  box-shadow: 0 12px 32px rgba(0, 0, 0, 0.35);
  z-index: 10000;
  transition: top 0.25s ease, left 0.25s ease;
}
</style>
