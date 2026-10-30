import { useAuthStore } from '~/stores/auth'
import type { Role } from '~/targets'

declare module '#app' {
  interface PageMeta {
    public?: boolean
    /** Active roles allowed on this page. */
    roles?: Role[]
  }
}

// definePageMeta({ middleware: ['role'], roles: ['worker'] })
export default defineNuxtRouteMiddleware((to) => {
  const auth = useAuthStore()
  const roles = to.meta.roles
  if (!roles?.length || !auth.activeRole) return
  if (!roles.includes(auth.activeRole)) return navigateTo('/')
})
