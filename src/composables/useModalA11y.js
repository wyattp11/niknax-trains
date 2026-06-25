import { ref, watch, nextTick, onBeforeUnmount } from 'vue'

/**
 * Accessibility helper for modal dialogs.
 *
 * - Traps Tab/Shift+Tab focus inside the modal panel while open.
 * - Closes on Escape.
 * - Focuses the first focusable element inside the modal on open.
 * - Restores focus to whatever was focused before the modal opened, on close.
 *
 * Some modals contain a scrollable region of rendered/untrusted content
 * (e.g. links inside markdown) that shouldn't grab initial focus — doing so
 * makes the browser auto-scroll that region to reveal the focused link,
 * which looks like the modal "jumped" to the bottom on open. Elements inside
 * any container marked `data-no-autofocus` are skipped for *initial* focus
 * only; they're still reachable (and still trapped) via Tab.
 *
 * Usage:
 *   const { modalRef } = useModalA11y(() => !!showThing.value, () => showThing.value = false)
 *   <div v-if="showThing" ref="modalRef" role="dialog" aria-modal="true">...</div>
 */
export function useModalA11y(isOpen, onClose) {
  const modalRef = ref(null)
  let previouslyFocused = null

  function getFocusable({ forInitialFocus = false } = {}) {
    if (!modalRef.value) return []
    return Array.from(
      modalRef.value.querySelectorAll(
        'a[href], button:not([disabled]), textarea:not([disabled]), input:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])'
      )
    ).filter((el) => {
      if (el.offsetParent === null) return false
      if (forInitialFocus && el.closest('[data-no-autofocus]')) return false
      return true
    })
  }

  function handleKeydown(e) {
    if (e.key === 'Escape') {
      e.stopPropagation()
      onClose()
      return
    }
    if (e.key === 'Tab') {
      const focusable = getFocusable()
      if (!focusable.length) return
      const first = focusable[0]
      const last = focusable[focusable.length - 1]
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault()
        last.focus()
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault()
        first.focus()
      }
    }
  }

  watch(
    isOpen,
    async (open) => {
      if (open) {
        previouslyFocused = document.activeElement
        // Bubble phase (not capture) so elements inside the modal — like a
        // combobox that wants Escape to dismiss its own suggestion list
        // first via e.stopPropagation() — get first crack at the keypress.
        document.addEventListener('keydown', handleKeydown, false)
        await nextTick()
        const focusable = getFocusable({ forInitialFocus: true })
        ;(focusable[0] || modalRef.value)?.focus?.()
      } else {
        document.removeEventListener('keydown', handleKeydown, false)
        if (previouslyFocused && typeof previouslyFocused.focus === 'function') {
          previouslyFocused.focus()
        }
        previouslyFocused = null
      }
    },
    { immediate: true }
  )

  onBeforeUnmount(() => {
    document.removeEventListener('keydown', handleKeydown, false)
  })

  return { modalRef }
}
