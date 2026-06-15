import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY

export const isSupabaseConfigured = !!(supabaseUrl && supabaseKey)

// Use placeholder values so createClient doesn't throw — queries will fail
// gracefully with a network error until real env vars are set.
export const supabase = createClient(
  supabaseUrl || 'https://placeholder.supabase.co',
  supabaseKey || 'placeholder-key'
)

/**
 * Upload a file to Supabase Storage using XHR so we get real upload progress.
 * @param {string} bucket  - storage bucket name
 * @param {string} path    - object path within the bucket
 * @param {File}   file    - File object to upload
 * @param {(pct: number) => void} [onProgress] - called with 0‑100 during upload
 * @returns {Promise<string>} public URL of the uploaded object
 */
/**
 * Upload via the Supabase SDK (handles auth internally) with a simulated
 * progress animation, since the new sb_publishable_ key format isn't a raw
 * JWT and can't be used directly in XHR Authorization headers.
 */
export async function uploadWithProgress(bucket, path, file, onProgress) {
  const base = (supabaseUrl || '').replace(/\/$/, '')

  // Animate 0 → 85% while the upload runs, then jump to 100% on success.
  let pct = 0
  const ticker = setInterval(() => {
    pct = Math.min(85, pct + Math.random() * 12)
    onProgress?.(Math.round(pct))
  }, 250)

  try {
    const { error } = await supabase.storage.from(bucket).upload(path, file, { upsert: true })
    if (error) throw error
    return `${base}/storage/v1/object/public/${bucket}/${path}`
  } finally {
    clearInterval(ticker)
    onProgress?.(100)
  }
}
