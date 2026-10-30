import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import type { Role, SessionScope } from '~/targets'

export interface User {
  id: string
  phone: string
  name: string | null
  email: string | null
  locale: 'en' | 'hi' | 'pa'
  roles: Role[]
  created_at: string
}

export interface SessionPayload {
  access_token: string
  expires_in: number
  active_role: Role
  session: { scope: SessionScope, expires_at: string }
  user: User
}

/**
 * The access token lives only in memory (never localStorage). The refresh token is
 * an HttpOnly cookie the browser sends to /api/v1/auth; this store never sees it.
 */
export const useAuthStore = defineStore('auth', () => {
  const accessToken = ref<string | null>(null)
  const user = ref<User | null>(null)
  const activeRole = ref<Role | null>(null)
  const scope = ref<SessionScope | null>(null)
  /** True once we've tried to restore the session on this page load. */
  const restored = ref(false)

  const isLoggedIn = computed(() => !!accessToken.value && !!user.value)

  function setSession(p: SessionPayload) {
    accessToken.value = p.access_token
    user.value = p.user
    activeRole.value = p.active_role
    scope.value = p.session.scope
  }

  function clear() {
    accessToken.value = null
    user.value = null
    activeRole.value = null
    scope.value = null
  }

  function hasRole(role: Role) {
    return user.value?.roles.includes(role) ?? false
  }

  return { accessToken, user, activeRole, scope, restored, isLoggedIn, setSession, clear, hasRole }
})
