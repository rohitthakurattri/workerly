import { useAuthStore, type SessionPayload, type User } from '~/stores/auth'
import { TARGETS, type AppTarget, type Role } from '~/targets'

interface OtpSent { phone: string, expires_in: number, resend_after: number }
interface MfaRequired { mfa_required: true, mfa_token: string, expires_in: number }

export function useAuth() {
  const api = useApi()
  const auth = useAuthStore()
  const config = useRuntimeConfig()
  const targetName = config.public.appTarget as AppTarget
  const target = TARGETS[targetName]

  async function requestOtp(phone: string) {
    return (await api<{ data: OtpSent }>('/auth/otp', { method: 'POST', body: { phone } })).data
  }

  /** Consumer apps get a session; the admin app gets an MFA challenge. */
  async function verifyOtp(phone: string, code: string): Promise<{ mfaToken: string } | null> {
    const res = await api<{ data: SessionPayload | MfaRequired }>('/auth/otp/verify', {
      method: 'POST',
      body: { phone, code, scope: target.scope, role: target.defaultRole ?? undefined },
    })
    if ('mfa_required' in res.data) return { mfaToken: res.data.mfa_token }
    auth.setSession(res.data)
    return null
  }

  async function verifyTotp(mfaToken: string, code: string) {
    const res = await api<{ data: SessionPayload }>('/auth/totp', { method: 'POST', body: { mfa_token: mfaToken, code } })
    auth.setSession(res.data)
  }

  async function switchRole(role: Role) {
    const res = await api<{ data: SessionPayload }>('/auth/switch_role', { method: 'POST', body: { role } })
    auth.setSession(res.data)
  }

  async function updateProfile(attrs: Partial<Pick<User, 'name' | 'email' | 'locale'>>) {
    const res = await api<{ data: { user: User } }>('/me', { method: 'PATCH', body: { user: attrs } })
    auth.user = res.data.user
  }

  async function logout() {
    try {
      // Stop job alerts on this browser before the session (needed to unregister) ends.
      if (import.meta.client) await usePush().disable().catch(() => {})
      await api('/auth/session', { method: 'DELETE' })
    }
    finally {
      closeCable()
      auth.clear()
      // Shared devices: drop anything the service worker may have cached.
      if (import.meta.client && 'caches' in window) {
        for (const key of await caches.keys()) await caches.delete(key)
      }
      await navigateTo('/login')
    }
  }

  /** Where to send a user who wants to act as `role` (may be another app). */
  function appUrlFor(role: Role): string | null {
    const urls = config.public.appUrls as Record<AppTarget, string>
    if (role === 'customer') return urls.customer
    if (role === 'worker') return urls.worker
    return urls.admin
  }

  return { target, targetName, requestOtp, verifyOtp, verifyTotp, switchRole, updateProfile, logout, appUrlFor }
}
