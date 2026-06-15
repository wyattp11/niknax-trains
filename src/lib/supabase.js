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
export async function uploadWithProgress(bucket, path, file, onProgress) {
  const base = (supabaseUrl || '').replace(/\/$/, '')

  // The sb_publishable_ key isn't a raw JWT — get the real token from the SDK session.
  const { data: { session } } = await supabase.auth.getSession()
  const token = session?.access_token ?? supabaseKey

  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest()
    xhr.upload.onprogress = (e) => {
      if (e.lengthComputable && onProgress) {
        onProgress(Math.round((e.loaded / e.total) * 100))
      }
    }
    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        resolve(`${base}/storage/v1/object/public/${bucket}/${path}`)
      } else {
        let msg = `Upload failed (${xhr.status})`
        try { msg = JSON.parse(xhr.responseText).message || msg } catch {}
        reject(new Error(msg))
      }
    }
    xhr.onerror = () => reject(new Error('Network error during upload'))
    xhr.open('POST', `${base}/storage/v1/object/${bucket}/${path}`)
    xhr.setRequestHeader('Authorization', `Bearer ${token}`)
    xhr.setRequestHeader('Content-Type', file.type || 'application/octet-stream')
    xhr.setRequestHeader('x-upsert', 'true')
    xhr.send(file)
  })
}
