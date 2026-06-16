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
// Cab rises 1 row above the boiler. Smokestack moved forward (right) toward
// the front of the boiler, using \ instead of /. Big ( O ) rear drivers on
// the left, small (o) front pilots on the right.
const LOCO_RAW = [
  `                 ________            ____                                  `,  // cab roof (rises above boiler)
  `                   | || |          \\\==//               `,  // cab window + stack top (forward!)
  `                   |_||_|^___^____!_|__|_`,  // boiler roof + stack base
  `  |#############|  |     | ~*NIKNAX*~ ____|]`,  // body + boiler label + coupler
  ` |_______________| |_____|______|    |____|`,  // underframe
  `  (*)(*)--(*)(*)    (-*-)=(-*-)    (0)-(0)||\\\    `,  // big rear drivers + small front pilots
]

// ── Four cargo car types (1 blank row prepended so wheels align with 6-row loco) ──
const CAR_TYPES_RAW = [
  // 0: Oil lamp car
  [
    `               `,
    `  _____________`,
    ` | <3<3<3<3<3  |`,
    ` |   VINTAGE   |`,
    ` |_____________|>`,
    `  -(*)-----(*)-`,
  ],
  // 1: Glassware car — goblets /U\
  [
    `               `,
    `  ____________`,
    ` |$$$$$$$$$$$$|`,
    ` |  ANTIQUES  |`,
    ` |____________|>`,
    `  -(*)-----(*)-`,
  ],
  // 2: Jewelry car
  [
    `               `,
    `  ______________`,
    ` | ************ |`,
    ` | COLLECTIBLES |`,
    ` |______________|>`,
    `  -(*)-----(*)-`,
  ],
  // 3: MCM car
  [
    `               `,
    `  ______________`,
    ` |* * * * * * * |`,
    ` | CONTEMPORARY |`,
    ` |______________|>`,
    `  -(*)-----(*)-`,
  ],
]

const CABOOSE_RAW = [
    `   ________     `,
    `  _| [ ]  |____`,
    ` |             |`,
    ` |  ~*NIKNAX*~ |`,
    ` |_____________|>`,
    `  -(*)-----(*)-`,
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

const totalH = computed(() => 6 * lineH.value + lineH.value + 4)

const locoX = ref(-2000)
const cabX  = ref(-2000)

// Up to 4 cars
const MAX_CARS = 4
const carXs   = Array.from({ length: MAX_CARS }, () => ref(-2000))
const carVis  = Array.from({ length: MAX_CARS }, () => ref(false))
// Which car art to use for each slot
const carTypeIdx = Array.from({ length: MAX_CARS }, (_, i) => i % CAR_ARTS.length)

const cabVis  = ref(false)

const isDark     = ref(false)
const locoColor  = computed(() => isDark.value ? '#FF4D7E' : '#C8002A')
const cabColor   = computed(() => isDark.value ? '#C8002A' : '#9A001E')
const trackColor = computed(() => isDark.value ? 'rgba(74,0,24,0.35)' : 'rgba(240,192,204,0.55)')

// Red / teal alternating shades for cars
const carColors     = ['#9A001E', '#007A70', '#C8002A', '#005C55', '#B80028']
const carColorsDark = ['#FF4D7E', '#2BBFB4', '#FF7090', '#5CD6CC', '#FF3060']

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
// Loco arrival whistle: Freesound #71778 by Bidone (CC0)
// https://freesound.org/people/Bidone/sounds/71778/
const WHISTLE_URL = 'https://cdn.freesound.org/previews/71/71778_706955-lq.mp3'

// Caboose whistle: Freesound #407394 by mike_stranks (CC0)
// https://freesound.org/people/mike_stranks/sounds/407394/
const CABOOSE_WHISTLE_URL = 'https://cdn.freesound.org/previews/407/407394_5385809-lq.mp3'

let whistleEl       = null
let cabooseWhistleEl = null
let audioCtx        = null
let pendingCaboose  = false

function webCtx() {
  if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)()
  return audioCtx
}

async function ensureCtx() {
  const ac = webCtx()
  if (ac.state === 'suspended') { try { await ac.resume() } catch {} }
  return ac
}

// Try to play real audio. Browsers block audio-with-sound autoplay until
// there's been a user gesture on the page (click/touchstart) — the
// `unlock()` listener below warms these elements up the moment that
// happens, so the next call here plays normally. No mute tricks: some
// browsers silently re-pause audio the instant you unmute it, which made
// playback look "successful" while producing no sound at all.
async function tryPlay(el) {
  try {
    el.currentTime = 0
    await el.play()
    return true
  } catch {
    return false
  }
}

async function playWhistle() {
  if (!whistleEl) return
  const ok = await tryPlay(whistleEl)
  if (ok) {
    // Chain: caboose whistle plays immediately when the arrival whistle ends
    whistleEl.addEventListener('ended', () => playCabooseWhistle(), { once: true })
    return
  }
  // Fully blocked — fall back to a synthesized whistle, then chain caboose after
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
  setTimeout(() => playCabooseWhistle(), 1400)
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

// Caboose whistle: real audio element (mike_stranks, CC0)
// Fires when last car clunk ends — announces the caboose rolling in
async function playCabooseWhistle() {
  if (!cabooseWhistleEl) return
  const ok = await tryPlay(cabooseWhistleEl)
  if (!ok) pendingCaboose = true
}

// "All aboard!" conductor call — fires when the whole train has stopped.
// Download from: https://pixabay.com/sound-effects/people-quotall-aboardquot-train-conductor-177678/
// Save as: niknax-trains/public/sounds/all-aboard.mp3
let allAboardEl = null

async function playAllAboard() {
  if (!allAboardEl) return
  await tryPlay(allAboardEl)
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
    // Clunk buffer is ~280ms. Start caboose rolling immediately after.
    // (Caboose whistle already fired right after the arrival whistle ended.)
    waitTimer = setTimeout(() => {
      startCabPhase()
    }, 290)
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
      // Train fully stopped — conductor calls "All aboard!"
      playAllAboard()
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

  numCars = W < 480 ? 1 : W < 700 ? 2 : W < 1000 ? 3 : 4

  await document.fonts.ready
  const span = document.createElement('span')
  span.style.cssText = `position:absolute;visibility:hidden;font-family:${FONT};font-size:${fz.value}px;white-space:pre`
  span.textContent = 'X'.repeat(30)
  el.appendChild(span)
  cw = span.getBoundingClientRect().width / 30
  el.removeChild(span)

  computeStops()
  locoX.value = -LOCO_W * cw

  // Best-effort: some browsers allow the AudioContext to start unsuspended
  // (e.g. high media-engagement sites). Fire-and-forget — resume() can hang
  // indefinitely without a user gesture on strict browsers, so we must NOT
  // await it here or it can stall the rest of mount (and the train's
  // arrival animation) forever.
  webCtx().resume().catch(() => {})

  // Preload both real audio elements
  whistleEl = new Audio(WHISTLE_URL)
  whistleEl.preload = 'auto'
  whistleEl.volume  = 0.8
  whistleEl.load()

  cabooseWhistleEl = new Audio(CABOOSE_WHISTLE_URL)
  cabooseWhistleEl.preload = 'auto'
  cabooseWhistleEl.volume  = 0.85
  cabooseWhistleEl.load()

  // "All aboard!" — loaded from local file; silently skipped if not present
  allAboardEl = new Audio('/sounds/all-aboard.mp3')
  allAboardEl.preload = 'auto'
  allAboardEl.volume  = 0.9
  allAboardEl.load()

  // Helper: warm up an Audio element silently to unlock playback
  async function warmUp(el) {
    try {
      el.muted = true
      await el.play()
      el.pause()
      el.currentTime = 0
      el.muted = false
    } catch {}
  }

  // Unlock audio on first user interaction
  const unlock = async () => {
    try { await webCtx().resume() } catch {}
    await warmUp(whistleEl)
    await warmUp(cabooseWhistleEl)
    if (allAboardEl) await warmUp(allAboardEl)
    // Play caboose whistle if it was blocked earlier
    if (pendingCaboose) {
      pendingCaboose = false
      try { cabooseWhistleEl.currentTime = 0; cabooseWhistleEl.play() } catch {}
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
  if (audioCtx)        { try { audioCtx.close() } catch {} }
  if (whistleEl)       { whistleEl.pause(); whistleEl.src = '' }
  if (cabooseWhistleEl){ cabooseWhistleEl.pause(); cabooseWhistleEl.src = '' }
  if (allAboardEl)     { allAboardEl.pause();      allAboardEl.src = '' }
})
</script>
