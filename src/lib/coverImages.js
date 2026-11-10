// Train graphics: shrink before upload, and serve a small thumbnail on cards.
//
// Why: the free Supabase plan includes 5 GB of image bandwidth a month.
// Graphics were uploaded as-is (often several MB each) and the home page
// loaded every one of them — including every past train — just to show a
// 112-px thumbnail. A few hundred visits used up the month.
//
// Each upload now produces two JPEGs in the train's folder:
//   cover-<timestamp>.jpg        up to 1600 px — train page, social previews,
//                                and "Download Graphic"
//   cover-<timestamp>-thumb.jpg  480 px — cards and lists
// The thumbnail's URL is derived from the cover's, so no database change is
// needed; graphics uploaded before this fall back to the full image until
// the admin runs "Optimize graphics" in Settings.
//
// Files get a unique name and a one-year browser cache, so a returning
// visitor never re-downloads a graphic. Changing it makes a new file.

import { supabase } from './supabase.js'

const BUCKET      = 'train-graphics'
const FULL_MAX    = 1600
const THUMB_MAX   = 480
const FULL_Q      = 0.86
const THUMB_Q     = 0.8
const ONE_YEAR    = '31536000'

async function loadBitmap(blob) {
  if ('createImageBitmap' in window) {
    try { return await createImageBitmap(blob) } catch { /* fall through */ }
  }
  // Older Safari: decode through an <img>
  const url = URL.createObjectURL(blob)
  try {
    const img = new Image()
    img.decoding = 'async'
    img.src = url
    await img.decode()
    return img
  } finally {
    URL.revokeObjectURL(url)
  }
}

function render(source, maxSide, quality) {
  const w = source.width, h = source.height
  const scale = Math.min(1, maxSide / Math.max(w, h))
  const canvas = document.createElement('canvas')
  canvas.width  = Math.max(1, Math.round(w * scale))
  canvas.height = Math.max(1, Math.round(h * scale))
  const ctx = canvas.getContext('2d')
  // JPEG has no transparency — put transparent PNGs on white, not black.
  ctx.fillStyle = '#ffffff'
  ctx.fillRect(0, 0, canvas.width, canvas.height)
  ctx.imageSmoothingQuality = 'high'
  ctx.drawImage(source, 0, 0, canvas.width, canvas.height)
  return new Promise((resolve, reject) =>
    canvas.toBlob(b => (b ? resolve(b) : reject(new Error('Could not process the image.'))),
                  'image/jpeg', quality)
  )
}

/** { full, thumb } JPEG blobs from any image File/Blob. */
export async function prepareCover(fileOrBlob) {
  const bitmap = await loadBitmap(fileOrBlob)
  const [full, thumb] = await Promise.all([
    render(bitmap, FULL_MAX, FULL_Q),
    render(bitmap, THUMB_MAX, THUMB_Q),
  ])
  bitmap.close?.()
  return { full, thumb }
}

function publicUrl(path) {
  return supabase.storage.from(BUCKET).getPublicUrl(path).data.publicUrl
}

/**
 * Shrinks and uploads a train graphic. Returns the cover URL to save on the
 * train. onProgress gets 0–100.
 */
export async function uploadCover(trainId, fileOrBlob, onProgress) {
  onProgress?.(5)
  const { full, thumb } = await prepareCover(fileOrBlob)
  onProgress?.(35)

  const base = `${trainId}/cover-${Date.now()}`
  const opts = { contentType: 'image/jpeg', cacheControl: ONE_YEAR, upsert: false }

  const { error: e1 } = await supabase.storage.from(BUCKET).upload(`${base}-thumb.jpg`, thumb, opts)
  if (e1) throw e1
  onProgress?.(55)

  const { error: e2 } = await supabase.storage.from(BUCKET).upload(`${base}.jpg`, full, opts)
  if (e2) throw e2
  onProgress?.(100)

  return publicUrl(`${base}.jpg`)
}

const NEW_STYLE = /\/cover-\d+\.jpg(\?.*)?$/

/** Small version for cards and lists; the full URL for older graphics. */
export function coverThumb(url) {
  if (!url) return url
  return NEW_STYLE.test(url) ? url.replace(/\.jpg(\?.*)?$/, '-thumb.jpg$1') : url
}

/** True when a cover was uploaded before shrinking existed. */
export function isUnoptimizedCover(url) {
  return !!url && !NEW_STYLE.test(url)
}
