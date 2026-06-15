<template>
  <div
    ref="wrap"
    class="relative w-full overflow-hidden select-none"
    :style="{ height: totalH + 'px' }"
    aria-hidden="true"
  >
    <!-- Train pieces — absolutely positioned, animated via translateX -->
    <pre
      v-for="p in pieces"
      :key="p.key"
      v-show="p.visible"
      class="absolute top-0 left-0 m-0 p-0 leading-none whitespace-pre"
      :style="{
        transform: `translateX(${p.x.toFixed(1)}px)`,
        fontSize: fz + 'px',
        lineHeight: lineH + 'px',
        fontFamily: FONT,
        color: p.color,
        willChange: 'transform',
      }"
    >{{ p.art }}</pre>

    <!-- Track line (always visible, spans full width) -->
    <div
      class="absolute bottom-0 left-0 right-0 overflow-hidden whitespace-nowrap"
      :style="{ fontSize: fz + 'px', lineHeight: lineH + 'px', fontFamily: FONT, color: trackColor }"
    >{{ TRACKS }}</div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'

// ── Config ────────────────────────────────────────────────────────────────
const FONT   = "'Courier Prime', 'Courier New', monospace"
const TRACKS = '═'.repeat(300)

// ── ASCII art ─────────────────────────────────────────────────────────────
// 5-row pieces. All rows padded to the same width inside artStr().
// The train travels RIGHT (→). Loco is at the front (rightmost), caboose rear.
// Each piece except LOCO has coupling `>` at its right end on row 2 (middle)
// so pieces visually link when adjacent.

const LOCO_RAW = [
  `        ====                   `,
  `  ______|  |____________________`,
  ` |      |  | [=][=]  [=] [cab]|`,
  ` |______|__|____________________|`,
  `   -(o)(o)-----------(o)(o)-(o)-`,
]

const CAR_RAW = [
  `  _____________`,
  ` |             |`,
  ` |   NIKNAX    |>`,
  ` |_____________|`,
  `  -(o)-----(o)-`,
]

const CABOOSE_RAW = [
  `  __________`,
  ` |  /----\\  |`,
  ` | | *  * | |>`,
  ` |__|____|_|`,
  `  -(o)--(o)-`,
]

function artStr(lines) {
  const w = Math.max(...lines.map(l => l.length))
  return lines.map(l => l.padEnd(w, ' ')).join('\n')
}

const LOCO_ART = artStr(LOCO_RAW)
const CAR_ART  = artStr(CAR_RAW)
const CAB_ART  = artStr(CABOOSE_RAW)

const LOCO_W = Math.max(...LOCO_RAW.map(l => l.length))
const CAR_W  = Math.max(...CAR_RAW.map(l =>  l.length))
const CAB_W  = Math.max(...CABOOSE_RAW.map(l => l.length))

// ── Refs ──────────────────────────────────────────────────────────────────
const wrap  = ref(null)
const fz    = ref(12)
const lineH = ref(17)

const totalH = computed(() => 5 * lineH.value + lineH.value + 4)

// Piece positions (pixels from container left edge)
const locoX  = ref(-2000)
const car1X  = ref(-2000)
const car2X  = ref(-2000)
const car3X  = ref(-2000)
const cabX   = ref(-2000)

const car1Vis = ref(false)
const car2Vis = ref(false)
const car3Vis = ref(false)
const cabVis  = ref(false)

// isDark detection via CSS variable
const isDark = ref(false)
const locoColor   = computed(() => isDark.value ? '#f29893' : '#8B2635')
const carColor    = computed(() => isDark.value ? '#e06b62' : '#7a1f2d')
const cabColor    = computed(() => isDark.value ? '#C9A227' : '#a07d0a')
const trackColor  = computed(() => isDark.value ? 'rgba(139,38,53,0.35)' : 'rgba(90,20,30,0.25)')

const pieces = computed(() => [
  { key: 'loco', art: LOCO_ART, x: locoX.value,  visible: true,         color: locoColor.value },
  { key: 'car1', art: CAR_ART,  x: car1X.value,   visible: car1Vis.value, color: carColor.value },
  { key: 'car2', art: CAR_ART,  x: car2X.value,   visible: car2Vis.value, color: carColor.value },
  { key: 'car3', art: CAR_ART,  x: car3X.value,   visible: car3Vis.value, color: carColor.value },
  { key: 'cab',  art: CAB_ART,  x: cabX.value,    visible: cabVis.value,  color: cabColor.value },
])

// ── Stop positions (computed once at mount) ───────────────────────────────
let cw = 7.2  // char width in pixels (measured at mount)
let stopLoco = 0, stopCar1 = 0, stopCar2 = 0, stopCar3 = 0, stopCab = 0
let numCars = 3

function computeStops() {
  const W = wrap.value?.clientWidth || 900
  stopLoco = W - LOCO_W * cw - 8
  stopCar1 = stopLoco - CAR_W * cw
  stopCar2 = stopCar1  - CAR_W * cw
  stopCar3 = stopCar2  - CAR_W * cw
  stopCab  = (numCars === 3 ? stopCar3 : numCars === 2 ? stopCar2 : stopCar1) - CAB_W * cw
}

// ── Audio ─────────────────────────────────────────────────────────────────
let audioCtx = null

function ctx() {
  if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)()
  return audioCtx
}

function playWhistle() {
  try {
    const ac = ctx(), t = ac.currentTime
    // Classic steam whistle: sawtooth harmonics that dip then sustain
    [[620, 0.18], [930, 0.11], [1240, 0.07]].forEach(([f, v]) => {
      const osc = ac.createOscillator(), g = ac.createGain()
      osc.connect(g); g.connect(ac.destination)
      osc.type = 'sawtooth'
      osc.frequency.setValueAtTime(f * 1.04, t)
      osc.frequency.exponentialRampToValueAtTime(f, t + 0.25)
      g.gain.setValueAtTime(0, t)
      g.gain.linearRampToValueAtTime(v, t + 0.08)
      g.gain.setValueAtTime(v, t + 0.65)
      g.gain.exponentialRampToValueAtTime(0.001, t + 1.4)
      osc.start(t); osc.stop(t + 1.5)
    })
  } catch {}
}

function playClunk() {
  try {
    const ac = ctx(), t = ac.currentTime
    const sr = ac.sampleRate, dur = 0.28
    const buf = ac.createBuffer(1, Math.floor(sr * dur), sr)
    const d = buf.getChannelData(0)
    for (let i = 0; i < d.length; i++) {
      d[i] = (Math.random() * 2 - 1) * Math.exp(-i / (sr * 0.055))
    }
    const src = ac.createBufferSource(), filt = ac.createBiquadFilter(), g = ac.createGain()
    filt.type = 'bandpass'; filt.frequency.value = 280; filt.Q.value = 1.2
    src.buffer = buf
    src.connect(filt); filt.connect(g); g.connect(ac.destination)
    g.gain.value = 0.65
    src.start(t)
  } catch {}
}

function playBell() {
  try {
    const ac = ctx(), t = ac.currentTime
    [[880, 0.30], [1320, 0.18], [1760, 0.12], [2640, 0.07]].forEach(([f, v]) => {
      const osc = ac.createOscillator(), g = ac.createGain()
      osc.connect(g); g.connect(ac.destination)
      osc.type = 'sine'; osc.frequency.value = f
      g.gain.setValueAtTime(v, t)
      g.gain.exponentialRampToValueAtTime(0.001, t + 2.8)
      osc.start(t); osc.stop(t + 3)
    })
  } catch {}
}

// ── Animation state machine ───────────────────────────────────────────────
let phase     = 0
let phaseStart = null
let rafId      = null
let waitTimer  = null

function easeOut(t) {
  return 1 - Math.pow(1 - Math.min(t, 1), 3)
}

// Returns true when piece has reached stopPx
function slide(xRef, fromPx, stopPx, elapsedMs, speedPxPerSec) {
  const dist     = stopPx - fromPx
  const durationMs = Math.abs(dist) / (speedPxPerSec / 1000)
  const t = elapsedMs / durationMs
  xRef.value = fromPx + dist * easeOut(t)
  return t >= 1
}

function tick(now) {
  if (phaseStart === null) phaseStart = now
  const el = now - phaseStart

  if (phase === 0) {
    // Locomotive rolls in
    const from = -LOCO_W * cw
    if (slide(locoX, from, stopLoco, el, 260)) {
      locoX.value = stopLoco
      phase = -1
      playWhistle()
      waitTimer = setTimeout(startPhase1, 1300)
      return
    }
  } else if (phase === 1) {
    const from = -CAR_W * cw
    if (slide(car1X, from, stopCar1, el, 290)) {
      car1X.value = stopCar1; phase = -1; playClunk()
      if (numCars >= 2) waitTimer = setTimeout(startPhase2, 480)
      else waitTimer = setTimeout(startCabPhase, 550)
      return
    }
  } else if (phase === 2) {
    const from = -CAR_W * cw
    if (slide(car2X, from, stopCar2, el, 290)) {
      car2X.value = stopCar2; phase = -1; playClunk()
      if (numCars >= 3) waitTimer = setTimeout(startPhase3, 480)
      else waitTimer = setTimeout(startCabPhase, 550)
      return
    }
  } else if (phase === 3) {
    const from = -CAR_W * cw
    if (slide(car3X, from, stopCar3, el, 290)) {
      car3X.value = stopCar3; phase = -1; playClunk()
      waitTimer = setTimeout(startCabPhase, 600)
      return
    }
  } else if (phase === 4) {
    const from = -CAB_W * cw
    if (slide(cabX, from, stopCab, el, 220)) {
      cabX.value = stopCab; phase = 99
      playBell()
      return
    }
  } else {
    return // done or waiting
  }

  rafId = requestAnimationFrame(tick)
}

function startPhase1() { phase = 1; phaseStart = null; car1Vis.value = true; car1X.value = -CAR_W * cw; rafId = requestAnimationFrame(tick) }
function startPhase2() { phase = 2; phaseStart = null; car2Vis.value = true; car2X.value = -CAR_W * cw; rafId = requestAnimationFrame(tick) }
function startPhase3() { phase = 3; phaseStart = null; car3Vis.value = true; car3X.value = -CAR_W * cw; rafId = requestAnimationFrame(tick) }
function startCabPhase() { phase = 4; phaseStart = null; cabVis.value = true; cabX.value = -CAB_W * cw; rafId = requestAnimationFrame(tick) }

// ── Lifecycle ─────────────────────────────────────────────────────────────
onMounted(async () => {
  const el = wrap.value
  if (!el) return

  // Detect dark mode
  isDark.value = document.documentElement.classList.contains('dark')

  // Responsive font + line height
  const W = el.clientWidth
  if (W < 480)      { fz.value = 8;  lineH.value = 11 }
  else if (W < 640) { fz.value = 10; lineH.value = 14 }
  else if (W < 900) { fz.value = 11; lineH.value = 16 }
  else              { fz.value = 13; lineH.value = 18 }

  // Decide how many cars fit
  numCars = W < 500 ? 1 : W < 700 ? 2 : 3

  // Wait for fonts then measure char width
  await document.fonts.ready
  const span = document.createElement('span')
  span.style.cssText = `position:absolute;visibility:hidden;font-family:${FONT};font-size:${fz.value}px;white-space:pre`
  span.textContent = 'X'.repeat(30)
  el.appendChild(span)
  cw = span.getBoundingClientRect().width / 30
  el.removeChild(span)

  computeStops()

  // Place loco off-screen left to begin
  locoX.value = -LOCO_W * cw

  // Short delay before starting so the page has settled
  waitTimer = setTimeout(() => {
    rafId = requestAnimationFrame(tick)
  }, 400)
})

onUnmounted(() => {
  if (rafId)     cancelAnimationFrame(rafId)
  if (waitTimer) clearTimeout(waitTimer)
  if (audioCtx)  { try { audioCtx.close() } catch {} }
})
</script>
