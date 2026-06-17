<template>
  <div>
    <!-- Current / preview image -->
    <div v-if="preview || currentUrl" class="relative mb-3 group">
      <img
        :src="preview || currentUrl"
        class="w-full max-h-56 object-cover rounded-xl border border-bd"
        alt="Train graphic preview"
      />
      <button
        type="button"
        @click="clear"
        aria-label="Remove image"
        class="absolute top-2 right-2 bg-surface/90 hover:bg-sur2 text-tx1 rounded-full w-7 h-7 flex items-center justify-center text-sm transition-colors shadow"
      >×</button>
    </div>

    <!-- Drop / click zone -->
    <label
      :class="[
        'block border-2 border-dashed rounded-xl p-6 text-center cursor-pointer transition-colors',
        dragging
          ? 'border-niknax-400 bg-niknax-900/20'
          : 'border-bd2 hover:border-niknax-500 hover:bg-sur2/40',
      ]"
      @dragover.prevent="dragging = true"
      @dragleave="dragging = false"
      @drop.prevent="onDrop"
    >
      <input
        ref="fileInput"
        type="file"
        accept="image/*"
        class="hidden"
        @change="onSelect"
      />
      <div class="text-3xl mb-2" aria-hidden="true">🖼️</div>
      <p class="text-tx2 text-sm font-medium">
        {{ preview || currentUrl ? 'Replace image' : 'Upload train graphic' }}
      </p>
      <p class="text-tx3 text-xs mt-1">Click or drag & drop · PNG, JPG, GIF · max 10 MB</p>
    </label>

    <p v-if="sizeError" class="text-red-600 dark:text-red-400 text-xs mt-2">{{ sizeError }}</p>
  </div>
</template>

<script setup>
import { ref } from 'vue'

const props = defineProps({
  currentUrl: { type: String, default: null },
})
const emit = defineEmits(['file-selected', 'cleared'])

const fileInput  = ref(null)
const preview    = ref(null)
const dragging   = ref(false)
const sizeError  = ref('')

const MAX_MB = 10

function onSelect(e) {
  handleFile(e.target.files[0])
}

function onDrop(e) {
  dragging.value = false
  handleFile(e.dataTransfer.files[0])
}

function handleFile(file) {
  if (!file) return
  sizeError.value = ''
  if (file.size > MAX_MB * 1024 * 1024) {
    sizeError.value = `File is too large (max ${MAX_MB} MB).`
    return
  }
  if (preview.value) URL.revokeObjectURL(preview.value)
  preview.value = URL.createObjectURL(file)
  emit('file-selected', file)
}

function clear() {
  if (preview.value) URL.revokeObjectURL(preview.value)
  preview.value = null
  sizeError.value = ''
  if (fileInput.value) fileInput.value.value = ''
  emit('cleared')
}
</script>
