import { useAuthStore } from '~/stores/auth'

/**
 * Restores the session from the refresh cookie on first navigation and keeps
 * logged-out users on public pages. UX only: the API enforces every rule itself.
 */
export default defineNuxtRouteMiddleware(async (to) => {
  if (import.meta.server) return

  const auth = useAuthStore()
  if (!auth.restored) {
    await useSessionRefresh()()
    auth.restored = true
  }

  const isPublic = to.meta.public === true
  if (!auth.isLoggedIn && !isPublic) {
    return navigateTo({ path: '/login', query: to.fullPath !== '/' ? { redirect: to.fullPath } : {} })
  }
  if (auth.isLoggedIn && to.path === '/login') return navigateTo('/')
})
