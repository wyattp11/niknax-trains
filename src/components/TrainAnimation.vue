<template>
  <div
    ref="wrap"
    class="relative w-full overflow-hidden select-none"
    :style="{ height: totalH + 'px' }"
    aria-hidden="true"
  >
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

// ── 4-4-0 "American" locomotive (facing right: cab=left, cowcatcher=right) ─
// Diamond smokestack, 4 large drivers + 4 small pilots, cowcatcher at front
const LOCO_RAW = [
  `           /=\\                     `,  // diamond smokestack top
  `  _________|_|_____________________`,  // boiler top + smokestack base
  ` | [CAB]   | |  ==BOILER==  (O) |=>`,  // cab + boiler body + headlight + coupler
  ` |_________|_|___________________|  `,  // underframe
  `  -(O)=(O)=(O)=(O)-(o)(o)(o)(o)/= `,  // 4 drivers + 4 pilots + cowcatcher
]

// ── Five cargo car types ───────────────────────────────────────────────────
const CAR_TYPES_RAW = [
  // 0: Oil lamp car
  [
    `  _____________`,
    ` | (*)  (*) (*)|`,
    ` |  OIL  LAMPS |>`,
    ` |_____________|`,
    `  -(o)-----(o)-`,
  ],
  // 1: Glassware car — goblets /U\
  [
    `  _____________`,
    ` |/U\\/U\\/U\\/U\\|`,
    ` | GLASSWARE   |>`,
    ` |_____________|`,
    `  -(o)-----(o)-`,
  ],
  // 2: Barrel car
  [
    `  _____________`,
    ` |(%)(%)(%)(%)|`,
    ` | BARREL  CAR |>`,
    ` |_____________|`,
    `  -(o)-----(o)-`,
  ],
  // 3: Crate/box car
  [
    `  _____________`,
    ` |[#][#][#][#] |`,
    ` | CRATE   CAR |>`,
    ` |_____________|`,
    `  -(o)-----(o)-`,
  ],
  // 4: Niknax signature car
  [
    `  _____________`,
    ` | ~*NIKNAX*~  |`,
    ` |  DISTRICT   |>`,
    ` |_____________|`,
    `  -(o)-----(o)-`,
  ],
]

const CABOOSE_RAW = [
  `  __________`,
  ` |  /----\\  |`,
  ` | | *  * ||>`,
  ` |__|____|_|`,
  `  -(o)--(o)-`,
]

function artStr(lines) {
  const w = Math.max(...lines.map(l => l.length))
  return lines.map(l => l.padEnd(w, ' ')).join('\n')
}

const LOCO_ART     = artStr(LOCO_RAW)
const CAR_ARTS     = CAR_TYPES_RAW.map(r => artStr(r))
const CAB_ART      = artStr(CABOOSE_RAW)

const LOCO_W = Math.max(...LOCO_RAW.map(l => l.length))
const CAR_W  = Math.max(...CAR_TYPES_RAW[0].map(l => l.length))
const CAB_W  = Math.max(...CABOOSE_RAW.map(l => l.length))

// ── Piece state ───────────────────────────────────────────────────────────
const wrap  = ref(null)
const fz    = ref(12)
const lineH = ref(17)

const totalH = computed(() => 5 * lineH.value + lineH.value + 4)

const locoX = ref(-2000)
const cabX  = ref(-2000)

// Up to 5 cars
const MAX_CARS = 5
const carXs   = Array.from({ length: MAX_CARS }, () => ref(-2000))
const carVis  = Array.from({ length: MAX_CARS }, () => ref(false))
// Which car art to use for each slot
const carTypeIdx = Array.from({ length: MAX_CARS }, (_, i) => i % CAR_ARTS.length)

const cabVis  = ref(false)

const isDark     = ref(false)
const locoColor  = computed(() => isDark.value ? '#7fc4a2' : '#1A5C38')
const cabColor   = computed(() => isDark.value ? '#D4A017' : '#8a5f0a')
const trackColor = computed(() => isDark.value ? 'rgba(47,140,87,0.28)' : 'rgba(26,92,56,0.20)')

// Alternating green shades for cars
const carColors = ['#2E8B57', '#3a9e68', '#247a4a', '#3d9660', '#2a8050']
const carColorsDark = ['#52a882', '#7fc4a2', '#4a9e78', '#6abd96', '#5ab58a']

const pieces = computed(() => [
  { key: 'loco', art: LOCO_ART, x: locoX.value, visible: true, color: locoColor.value },
  ...Array.from({ length: MAX_CARS }, (_, i) => ({
    key: `car${i}`,
    art: CAR_ARTS[carTypeIdx[i]],
    x: carXs[i].value,
    visible: carVis[i].value,
    color: isDark.value ? carColorsDark[i % carColorsDark.length] : carColors[i % carColors.length],
  })),
  { key: 'cab', art: CAB_ART, x: cabX.value, visible: cabVis.value, color: cabColor.value },
])

// ── Stop positions ────────────────────────────────────────────────────────
// BUG FIX: cars stop in order right-to-left (first arriving stops next to loco)
let cw      = 7.2
let numCars = 3
let stopLoco   = 0
const carStops = []   // carStops[0] = first arriving car = adjacent to loco
let   stopCab  = 0

function computeStops() {
  const W = wrap.value?.clientWidth || 900
  // Center the whole train (caboose → loco) in the container
  const totalW = LOCO_W * cw + numCars * CAR_W * cw + CAB_W * cw
  const leftMargin = Math.max((W - totalW) / 2, 8)

  // Loco stops at the rightmost position of the centered train
  stopLoco = leftMargin + CAB_W * cw + numCars * CAR_W * cw

  // Each arriving car stops to the left of the previous piece
  // carPhase 0 → adjacent to loco, carPhase 1 → adjacent to car0, etc.
  carStops.length = 0
  for (let i = 0; i < numCars; i++) {
    carStops.push(stopLoco - (i + 1) * CAR_W * cw)
  }

  // Caboose stops to the left of the last car
  stopCab = carStops[numCars - 1] - CAB_W * cw
}

// ── Audio ─────────────────────────────────────────────────────────────────
// Real steam whistle: Freesound #71778 by Bidone (CC0, public domain)
// https://freesound.org/people/Bidone/sounds/71778/
const WHISTLE_URL = 'https://cdn.freesound.org/previews/71/71778_706955-lq.mp3'

let whistleEl   = null
let audioCtx    = null
let pendingBell = false

function webCtx() {
  if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)()
  return audioCtx
}

async function ensureCtx() {
  const ac = webCtx()
  if (ac.state === 'suspended') { try { await ac.resume() } catch {} }
  return ac
}

async function playWhistle() {
  if (!whistleEl) return
  try {
    whistleEl.currentTime = 0
    await whistleEl.play()
  } catch {
    // Fallback: synthesized whistle if audio is blocked
    try {
      const ac = await ensureCtx()
      const t  = ac.currentTime
      [[520, 0.38], [780, 0.22], [1040, 0.14]].forEach(([f, v]) => {
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
}

async function playClunk() {
  try {
    const ac = await ensureCtx()
    const t  = ac.currentTime
    const sr = ac.sampleRate, dur = 0.28
    const buf = ac.createBuffer(1, Math.floor(sr * dur), sr)
    const d   = buf.getChannelData(0)
    for (let i = 0; i < d.length; i++) d[i] = (Math.random() * 2 - 1) * Math.exp(-i / (sr * 0.055))
    const src = ac.createBufferSource(), filt = ac.createBiquadFilter(), g = ac.createGain()
    filt.type = 'bandpass'; filt.frequency.value = 280; filt.Q.value = 1.2
    src.buffer = buf
    src.connect(filt); filt.connect(g); g.connect(ac.destination)
    g.gain.value = 0.65
    src.start(t)
  } catch {}
}

// Station bell — two dings with realistic bell harmonics (1 : 2 : 2.756 : 3.5 : 5.4)
function doStationBell(ac) {
  const t = ac.currentTime
  function ding(when, fund = 440) {
    [1, 2, 2.756, 3.5, 5.4].forEach((ratio, i) => {
      const amp = [0.5, 0.25, 0.15, 0.09, 0.05][i]
      const osc = ac.createOscillator(), g = ac.createGain()
      osc.connect(g); g.connect(ac.destination)
      osc.type = 'sine'; osc.frequency.value = fund * ratio
      g.gain.setValueAtTime(0, when)
      g.gain.linearRampToValueAtTime(amp, when + 0.01)
      g.gain.exponentialRampToValueAtTime(0.001, when + 2.2)
      osc.start(when); osc.stop(when + 2.3)
    })
    // Metallic attack transient
    const osc2 = ac.createOscillator(), g2 = ac.createGain()
    osc2.connect(g2); g2.connect(ac.destination)
    osc2.type = 'triangle'; osc2.frequency.value = 2400
    g2.gain.setValueAtTime(0.2, when); g2.gain.exponentialRampToValueAtTime(0.001, when + 0.1)
    osc2.start(when); osc2.stop(when + 0.12)
  }
  ding(t)
  ding(t + 0.58)
}

async function playStationBell() {
  try {
    const ac = await ensureCtx()
    if (ac.state !== 'running') {
      pendingBell = true
      return
    }
    doStationBell(ac)
  } catch {}
}

// ── Animation state machine ───────────────────────────────────────────────
const SPEED_LOCO = 400  // px/sec
const SPEED_CAR  = 450
const SPEED_CAB  = 340

let phase      = 0
let phaseStart = null
let rafId      = null
let waitTimer  = null
let carPhase   = 0   // 0-indexed: which car is currently animating

function easeOut(t) { return 1 - Math.pow(1 - Math.min(t, 1), 3) }

function slide(xRef, fromPx, stopPx, elapsedMs, speedPxPerSec) {
  const dist  = stopPx - fromPx
  const durMs = Math.abs(dist) / (speedPxPerSec / 1000)
  xRef.value  = fromPx + dist * easeOut(elapsedMs / durMs)
  return elapsedMs / durMs >= 1
}

function startNextCar() {
  if (carPhase >= numCars) {
    waitTimer = setTimeout(startCabPhase, 350)
    return
  }
  phase = 1
  phaseStart = null
  carVis[carPhase].value = true
  carXs[carPhase].value  = -CAR_W * cw
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
    if (slide(locoX, -LOCO_W * cw, stopLoco, el, SPEED_LOCO)) {
      locoX.value = stopLoco
      phase = -1
      playWhistle()
      waitTimer = setTimeout(() => { carPhase = 0; startNextCar() }, 600)
      return
    }
  } else if (phase === 1) {
    const stop = carStops[carPhase]
    if (slide(carXs[carPhase], -CAR_W * cw, stop, el, SPEED_CAR)) {
      carXs[carPhase].value = stop
      phase = -1
      playClunk()
      carPhase++
      // Rapid chaining — next car starts almost immediately after clunk
      waitTimer = setTimeout(startNextCar, 80)
      return
    }
  } else if (phase === 4) {
    if (slide(cabX, -CAB_W * cw, stopCab, el, SPEED_CAB)) {
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

  // Preload the real whistle audio
  whistleEl = new Audio(WHISTLE_URL)
  whistleEl.preload = 'auto'
  whistleEl.volume  = 0.8
  whistleEl.load()

  // Unlock audio (both WebAudio and HTMLAudio) on first user interaction
  const unlock = async () => {
    try { await webCtx().resume() } catch {}
    // Warm up HTMLAudio element so it's allowed to play
    try {
      whistleEl.muted = true
      await whistleEl.play()
      whistleEl.pause()
      whistleEl.currentTime = 0
      whistleEl.muted = false
    } catch {}
    // Play pending bell if it was blocked
    if (pendingBell) {
      pendingBell = false
      try { doStationBell(webCtx()) } catch {}
    }
  }
  document.addEventListener('click',      unlock, { once: true })
  document.addEventListener('touchstart', unlock, { once: true })

  // Short delay then start animation
  waitTimer = setTimeout(() => {
    phase = 0; phaseStart = null
    rafId = requestAnimationFrame(tick)
  }, 400)
})

onUnmounted(() => {
  if (rafId)     cancelAnimationFrame(rafId)
  if (waitTimer) clearTimeout(waitTimer)
  if (audioCtx)  { try { audioCtx.close() } catch {} }
  if (whistleEl) { whistleEl.pause(); whistleEl.src = '' }
})
</script>
