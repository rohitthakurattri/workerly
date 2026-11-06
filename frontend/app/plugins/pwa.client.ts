import { captureInstallPrompt, markInstalled } from '~/composables/useInstallPrompt'
import { serviceWorkerUrl } from '~/utils/pwa'

/** Registers the service worker (offline page, cached assets, push) and keeps the install prompt. */
export default defineNuxtPlugin(() => {
  window.addEventListener('beforeinstallprompt', captureInstallPrompt)
  window.addEventListener('appinstalled', markInstalled)
  if (!('serviceWorker' in navigator)) return
  const app = useRuntimeConfig().public.appTarget as string
  // After the page has loaded, so the worker's own downloads never compete with the app's.
  const register = () => navigator.serviceWorker.register(serviceWorkerUrl(app, import.meta.dev), { scope: '/' }).catch(() => {})
  if (document.readyState === 'complete') void register()
  else window.addEventListener('load', () => void register(), { once: true })
})
