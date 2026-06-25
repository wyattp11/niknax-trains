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

// Wait until the element's viewport-relative position stops changing —
// far more reliable than guessing a fixed delay, since smooth-scroll
// duration depends on distance (short hop vs. scrolling a tall <main>).
function rectOf(el) {
  const r = el.getBoundingClientRect()
  return { top: r.top, left: r.left }
}

async function waitForScrollSettle(el, maxMs = 1200) {
  let last = rectOf(el)
  const start = performance.now()
  // give the smooth-scroll a tick to actually start before sampling
  await new Promise(r => requestAnimationFrame(r))
  while (performance.now() - start < maxMs) {
    await new Promise(r => requestAnimationFrame(r))
    const cur = rectOf(el)
    if (Math.abs(cur.top - last.top) < 0.5 && Math.abs(cur.left - last.left) < 0.5) return
    last = cur
  }
}

async function goToStep() {
  const sel = step.value?.target
  const el = sel ? findVisibleTarget(sel) : null
  if (el) {
    // A target taller than the viewport (e.g. the full schedule <main>)
    // can't be centered — "center" would scroll deep into its middle,
    // landing the popover far down the page. Align its top edge instead.
    const tooTall = el.getBoundingClientRect().height > window.innerHeight * 0.85
    el.scrollIntoView({ behavior: 'smooth', block: tooTall ? 'start' : 'center' })
    await waitForScrollSettle(el)
  }
  updateAll()
  await nextTick()
  // preventScroll is critical here — focusing a position:fixed element can
  // otherwise trigger the browser's own scroll-into-view heuristic, which
  // misreads the fixed viewport coordinates as a document offset and yanks
  // the page (often all the way down), desyncing the spotlight from its
  // target right after we just finished positioning it.
  popoverRef.value?.focus?.({ preventScroll: true })
}

watch(step, () => { if (store.active) goToStep() }, { immediate: true })

function onKeydown(e) {
  if (e.key === 'Escape') onSkip()
}

watch(() => store.active, (isActive) => {
  if (isActive) {
    window.addEventListener('resize', updateAll)
    window.addEventListener('keydown', onKeydown)
  } else {
    window.removeEventListener('resize', updateAll)
    window.removeEventListener('keydown', onKeydown)
  }
})

onUnmounted(() => {
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
    const top  = Math.max(12, vh / 2 - ph / 2)
    const left = Math.max(12, vw / 2 - pw / 2)
    return { top: `${top}px`, left: `${left}px` }
  }

  const r = rect.value
  const placement = step.value?.placement
    || (vh - r.bottom > ph + GAP + 20 ? 'bottom' : r.top > ph + GAP + 20 ? 'top' : 'bottom')

  // Compute the popover's actual rendered top edge directly — no transform —
  // so the clamp below operates on the real on-screen position instead of a
  // pre-transform value that can still end up off-screen after translation.
  let top = placement === 'top' ? (r.top - GAP - ph) : (r.bottom + GAP)
  top = Math.max(12, Math.min(top, vh - ph - 12))

  let left = r.left + r.width / 2 - pw / 2
  left = Math.max(12, Math.min(left, vw - pw - 12))

  return { top: `${top}px`, left: `${left}px` }
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
