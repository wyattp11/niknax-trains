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

    <!-- Track line -->
    <div
      class="absolute bottom-0 left-0 right-0 overflow-hidden whitespace-nowrap"
      :style="{ fontSize: fz + 'px', lineHeight: lineH + 'px', fontFamily: FONT, color: trackColor }"
    >{{ TRACKS }}</div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'

// ── Config ────────────────────────────────────────────────────────────────
const FONT   = "'Space Mono', 'Courier New', monospace"
const TRACKS = '═'.repeat(300)

// ── ASCII art ─────────────────────────────────────────────────────────────
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

// Piece positions
const locoX  = ref(-2000)
const car1X  = ref(-2000)
const car2X  = ref(-2000)
const car3X  = ref(-2000)
const car4X  = ref(-2000)
const car5X  = ref(-2000)
const cabX   = ref(-2000)

const car1Vis = ref(false)
const car2Vis = ref(false)
const car3Vis = ref(false)
const car4Vis = ref(false)
const car5Vis = ref(false)
const cabVis  = ref(false)

// Colors — forest green / gold palette
const isDark = ref(false)
const locoColor  = computed(() => isDark.value ? '#7fc4a2' : '#1A5C38')
const carColor   = computed(() => isDark.value ? '#52a882' : '#2E8B57')
const cabColor   = computed(() => isDark.value ? '#D4A017' : '#8a5f0a')
const trackColor = computed(() => isDark.value ? 'rgba(47,140,87,0.30)' : 'rgba(26,92,56,0.22)')

const pieces = computed(() => [
  { key: 'loco', art: LOCO_ART, x: locoX.value, visible: true,          color: locoColor.value },
  { key: 'car1', art: CAR_ART,  x: car1X.value,  visible: car1Vis.value, color: carColor.value },
  { key: 'car2', art: CAR_ART,  x: car2X.value,  visible: car2Vis.value, color: carColor.value },
  { key: 'car3', art: CAR_ART,  x: car3X.value,  visible: car3Vis.value, color: carColor.value },
  { key: 'car4', art: CAR_ART,  x: car4X.value,  visible: car4Vis.value, color: carColor.value },
  { key: 'car5', art: CAR_ART,  x: car5X.value,  visible: car5Vis.value, color: carColor.value },
  { key: 'cab',  art: CAB_ART,  x: cabX.value,   visible: cabVis.value,  color: cabColor.value },
])

// ── Stop positions ────────────────────────────────────────────────────────
let cw     = 7.2
let numCars = 3
let stopLoco = 0
const carStops = []  // [stop1, stop2, ...]
let   stopCab  = 0

function computeStops() {
  const W = wrap.value?.clientWidth || 900

  // Center the entire train:  [CAB][car5..car1][LOCO]
  const totalW = LOCO_W * cw + numCars * CAR_W * cw + CAB_W * cw
  // Left margin to center; never less than 8px
  const leftMargin = Math.max((W - totalW) / 2, 8)

  stopCab = leftMargin
  carStops.length = 0
  for (let i = 0; i < numCars; i++) {
    carStops.push(stopCab + CAB_W * cw + i * CAR_W * cw)
  }
  stopLoco = stopCab + CAB_W * cw + numCars * CAR_W * cw
}

// ── Audio ─────────────────────────────────────────────────────────────────
let audioCtx = null

function ctx() {
  if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)()
  return audioCtx
}

// Always resume before playing — this is the fix for the "no whistle" bug.
async function ensureAudio() {
  const ac = ctx()
  if (ac.state === 'suspended') {
    try { await ac.resume() } catch {}
  }
  return ac
}

async function playWhistle() {
  try {
    const ac = await ensureAudio()
    const t = ac.currentTime
    // Two-tone steam whistle — louder than before
    [[520, 0.35], [780, 0.22], [1040, 0.14]].forEach(([f, v]) => {
      const osc = ac.createOscillator(), g = ac.createGain()
      osc.connect(g); g.connect(ac.destination)
      osc.type = 'sawtooth'
      osc.frequency.setValueAtTime(f * 1.05, t)
      osc.frequency.exponentialRampToValueAtTime(f, t + 0.2)
      g.gain.setValueAtTime(0, t)
      g.gain.linearRampToValueAtTime(v, t + 0.06)
      g.gain.setValueAtTime(v, t + 0.55)
      g.gain.exponentialRampToValueAtTime(0.001, t + 1.2)
      osc.start(t); osc.stop(t + 1.3)
    })
  } catch {}
}

async function playClunk() {
  try {
    const ac = await ensureAudio()
    const t = ac.currentTime
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

// Caboose: two-ding station bell, much more prominent
async function playStationBell() {
  try {
    const ac = await ensureAudio()

    function ding(when) {
      // Fundamental + harmonics for a real bell timbre
      [[440, 0.45], [880, 0.25], [1318, 0.15], [1760, 0.10], [2637, 0.06]].forEach(([f, v]) => {
        const osc = ac.createOscillator(), g = ac.createGain()
        osc.connect(g); g.connect(ac.destination)
        osc.type = 'sine'
        osc.frequency.value = f
        g.gain.setValueAtTime(0, when)
        g.gain.linearRampToValueAtTime(v, when + 0.01)
        g.gain.exponentialRampToValueAtTime(0.001, when + 2.2)
        osc.start(when); osc.stop(when + 2.3)
      })
      // Add a metallic "clang" transient
      const osc2 = ac.createOscillator(), g2 = ac.createGain()
      osc2.connect(g2); g2.connect(ac.destination)
      osc2.type = 'triangle'
      osc2.frequency.value = 2200
      g2.gain.setValueAtTime(0.18, when)
      g2.gain.exponentialRampToValueAtTime(0.001, when + 0.12)
      osc2.start(when); osc2.stop(when + 0.15)
    }

    const t = ac.currentTime
    ding(t)           // first ding
    ding(t + 0.55)    // second ding
  } catch {}
}

// ── Animation state machine ───────────────────────────────────────────────
// Speeds ~50% faster than previous (260/290/220 → 390/435/330)
const SPEED_LOCO = 390
const SPEED_CAR  = 435
const SPEED_CAB  = 330

let phase      = 0
let phaseStart = null
let rafId      = null
let waitTimer  = null
let carPhase   = 0  // which car is currently moving (0-indexed)

function easeOut(t) {
  return 1 - Math.pow(1 - Math.min(t, 1), 3)
}

function slide(xRef, fromPx, stopPx, elapsedMs, speedPxPerSec) {
  const dist       = stopPx - fromPx
  const durationMs = Math.abs(dist) / (speedPxPerSec / 1000)
  const t = elapsedMs / durationMs
  xRef.value = fromPx + dist * easeOut(t)
  return t >= 1
}

const carXRefs = [car1X, car2X, car3X, car4X, car5X]
const carVis   = [car1Vis, car2Vis, car3Vis, car4Vis, car5Vis]

function startNextCar() {
  if (carPhase >= numCars) {
    // All cars done — bring in caboose
    waitTimer = setTimeout(startCabPhase, 400)
    return
  }
  phase = 1  // "moving a car"
  phaseStart = null
  carVis[carPhase].value = true
  carXRefs[carPhase].value = -CAR_W * cw
  rafId = requestAnimationFrame(tick)
}

function startCabPhase() {
  phase = 4; phaseStart = null
  cabVis.value = true; cabX.value = -CAB_W * cw
  rafId = requestAnimationFrame(tick)
}

function tick(now) {
  if (phaseStart === null) phaseStart = now
  const el = now - phaseStart

  if (phase === 0) {
    // Locomotive
    const from = -LOCO_W * cw
    if (slide(locoX, from, stopLoco, el, SPEED_LOCO)) {
      locoX.value = stopLoco
      phase = -1
      playWhistle()
      waitTimer = setTimeout(() => { carPhase = 0; startNextCar() }, 700)
      return
    }
  } else if (phase === 1) {
    // Current car
    const stop = carStops[carPhase]
    const from = -CAR_W * cw
    if (slide(carXRefs[carPhase], from, stop, el, SPEED_CAR)) {
      carXRefs[carPhase].value = stop
      phase = -1
      playClunk()
      carPhase++
      waitTimer = setTimeout(startNextCar, 320)
      return
    }
  } else if (phase === 4) {
    const from = -CAB_W * cw
    if (slide(cabX, from, stopCab, el, SPEED_CAB)) {
      cabX.value = stopCab
      phase = 99
      playStationBell()
      return
    }
  } else {
    return
  }

  rafId = requestAnimationFrame(tick)
}

// ── Lifecycle ─────────────────────────────────────────────────────────────
onMounted(async () => {
  const el = wrap.value
  if (!el) return

  isDark.value = document.documentElement.classList.contains('dark')

  const W = el.clientWidth
  if (W < 480)       { fz.value = 8;  lineH.value = 11 }
  else if (W < 640)  { fz.value = 10; lineH.value = 14 }
  else if (W < 900)  { fz.value = 11; lineH.value = 16 }
  else               { fz.value = 13; lineH.value = 18 }

  // More cars on wider screens
  numCars = W < 480 ? 2 : W < 700 ? 3 : W < 1000 ? 4 : 5

  await document.fonts.ready
  const span = document.createElement('span')
  span.style.cssText = `position:absolute;visibility:hidden;font-family:${FONT};font-size:${fz.value}px;white-space:pre`
  span.textContent = 'X'.repeat(30)
  el.appendChild(span)
  cw = span.getBoundingClientRect().width / 30
  el.removeChild(span)

  computeStops()
  locoX.value = -LOCO_W * cw

  // Pre-create AudioContext so resume() works on first sound
  // (some browsers need a user gesture; resume() on unlock handles that)
  try { ctx() } catch {}

  // Unlock audio on the first user interaction anywhere on the page
  const unlock = () => { try { ctx().resume() } catch {} }
  document.addEventListener('click', unlock, { once: true })
  document.addEventListener('touchstart', unlock, { once: true })

  waitTimer = setTimeout(() => {
    phase = 0; phaseStart = null
    rafId = requestAnimationFrame(tick)
  }, 400)
})

onUnmounted(() => {
  if (rafId)     cancelAnimationFrame(rafId)
  if (waitTimer) clearTimeout(waitTimer)
  if (audioCtx)  { try { audioCtx.close() } catch {} }
})
</script>
