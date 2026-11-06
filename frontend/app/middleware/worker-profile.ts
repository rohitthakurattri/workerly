import { useAuthStore } from '~/stores/auth'
import { workerHome } from '~/utils/onboarding'

/**
 * Worker app routing by verification state:
 * draft/changes_requested -> /onboarding, pending/rejected/suspended -> /verification, approved -> leads
 * (the home page, /leads/*, /quotes, /reviews, /earnings and /jobs/*).
 * UX only: the API enforces the same rules (LeadPolicy, WorkerProfilePolicy).
 */
export default defineNuxtRouteMiddleware(async (to) => {
  const auth = useAuthStore()
  if (auth.activeRole !== 'worker') return to.path === '/' ? undefined : navigateTo('/')

  const { profile, load } = useWorkerProfile()
  if (!profile.value) {
    try {
      await load()
    }
    catch {
      return to.path === '/' ? undefined : navigateTo('/')
    }
  }
  const home = workerHome(profile.value)
  if (home === '/' && (to.path.startsWith('/leads/') || to.path.startsWith('/jobs/') || ['/quotes', '/reviews', '/earnings'].includes(to.path))) return
  if (home !== to.path) return navigateTo(home)
})
