import { computed } from 'vue'
import { useAuthStore } from '~/stores/auth'
import type { Role } from '~/targets'

/** What the active staff role may do. Mirrors the Admin:: policies; the API is the real check. */
export function useStaff() {
  const auth = useAuthStore()
  const is = (...roles: Role[]) => computed(() => !!auth.activeRole && roles.includes(auth.activeRole))
  return {
    canViewWorkers: is('admin', 'verifier', 'support'),
    canDecide: is('admin', 'verifier'),
    canSuspend: is('admin', 'support'),
    canViewAudit: is('admin'),
    canViewRequests: is('admin', 'support'),
    canViewPayments: is('admin', 'finance', 'support'),
    canMoveMoney: is('admin', 'finance'),
  }
}
