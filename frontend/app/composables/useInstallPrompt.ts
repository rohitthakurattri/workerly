import { computed, ref } from 'vue'
import { isIos } from '~/utils/pwa'

interface InstallPromptEvent extends Event {
  prompt: () => Promise<void>
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }>
}

// Chrome/Android fire beforeinstallprompt once, early; plugins/pwa.client.ts keeps it here.
const deferred = ref<InstallPromptEvent | null>(null)
const installed = ref(false)

export function captureInstallPrompt(e: Event) {
  e.preventDefault()
  deferred.value = e as InstallPromptEvent
}
export function markInstalled() {
  installed.value = true
  deferred.value = null
}

/** "Install the app": the browser's prompt where there is one, instructions on iPhone. */
export function useInstallPrompt() {
  const standalone = import.meta.client
    && (window.matchMedia?.('(display-mode: standalone)').matches || (navigator as { standalone?: boolean }).standalone === true)
  const ios = import.meta.client && isIos(navigator.userAgent, navigator.maxTouchPoints)

  const canPrompt = computed(() => !!deferred.value)
  const showIosHint = computed(() => ios && !standalone && !installed.value)
  const visible = computed(() => !standalone && !installed.value && (canPrompt.value || showIosHint.value))

  async function install() {
    const e = deferred.value
    if (!e) return false
    await e.prompt()
    const { outcome } = await e.userChoice
    deferred.value = null
    if (outcome === 'accepted') installed.value = true
    return outcome === 'accepted'
  }

  return { visible, canPrompt, showIosHint, install }
}
