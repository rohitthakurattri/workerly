import { ref } from 'vue'
import { serviceWorkerUrl } from '~/utils/pwa'

export type PushState = 'unsupported' | 'unavailable' | 'denied' | 'off' | 'on'

const state = ref<PushState>('off')

function keyBytes(base64url: string): Uint8Array<ArrayBuffer> {
  const pad = '='.repeat((4 - (base64url.length % 4)) % 4)
  const raw = atob((base64url + pad).replace(/-/g, '+').replace(/_/g, '/'))
  return Uint8Array.from(raw, c => c.charCodeAt(0))
}

/** Job alerts by web push. iPhones only get them once the app is installed (Phase 9: PWA). */
export function usePush() {
  const api = useApi()
  const app = useRuntimeConfig().public.appTarget as string
  const supported = import.meta.client && 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window

  async function subscription() {
    const reg = await navigator.serviceWorker.getRegistration('/')
    return reg ? reg.pushManager.getSubscription() : null
  }

  async function refresh() {
    if (!supported) return (state.value = 'unsupported')
    const config = (await api<{ data: { enabled: boolean, public_key: string | null } }>('/devices/push_config')).data
    if (!config.enabled) return (state.value = 'unavailable')
    if (Notification.permission === 'denied') return (state.value = 'denied')
    const sub = await subscription()
    // Re-register an existing subscription so the server knows who is signed in on this browser now.
    if (sub) await api('/devices', { method: 'POST', body: sub.toJSON() })
    return (state.value = sub ? 'on' : 'off')
  }

  async function enable() {
    const config = (await api<{ data: { enabled: boolean, public_key: string | null } }>('/devices/push_config')).data
    if (!config.enabled || !config.public_key) return (state.value = 'unavailable')
    if ((await Notification.requestPermission()) !== 'granted') return (state.value = 'denied')
    await navigator.serviceWorker.register(serviceWorkerUrl(app, import.meta.dev), { scope: '/' })
    const reg = await navigator.serviceWorker.ready
    const sub = await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: keyBytes(config.public_key) })
    await api('/devices', { method: 'POST', body: sub.toJSON() })
    return (state.value = 'on')
  }

  /** Turns alerts off for this browser; also called on logout so a shared phone stops getting them. */
  async function disable() {
    if (!supported) return
    const sub = await subscription()
    if (!sub) return
    try {
      await api('/devices', { method: 'DELETE', body: { endpoint: sub.endpoint } })
    }
    finally {
      await sub.unsubscribe()
      state.value = 'off'
    }
  }

  return { state, refresh, enable, disable }
}
