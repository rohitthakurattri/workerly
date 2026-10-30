import { beforeEach, describe, expect, it } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import { useAuthStore } from '~/stores/auth'

const payload = {
  access_token: 'tok',
  expires_in: 900,
  active_role: 'worker' as const,
  session: { scope: 'consumer' as const, expires_at: '2027-01-01T00:00:00Z' },
  user: { id: 'u1', phone: '+919876543210', name: null, email: null, locale: 'en' as const, roles: ['customer', 'worker'] as ('customer' | 'worker')[], created_at: '' },
}

describe('auth store', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('holds the session in memory and clears it on logout', () => {
    const auth = useAuthStore()
    auth.setSession(payload)
    expect(auth.isLoggedIn).toBe(true)
    expect(auth.hasRole('worker')).toBe(true)
    expect(auth.hasRole('admin')).toBe(false)

    auth.clear()
    expect(auth.isLoggedIn).toBe(false)
    expect(auth.accessToken).toBeNull()
  })

  it('never writes tokens to web storage', () => {
    useAuthStore().setSession(payload)
    expect(JSON.stringify({ ...localStorage })).not.toContain('tok')
    expect(JSON.stringify({ ...sessionStorage })).not.toContain('tok')
  })
})
