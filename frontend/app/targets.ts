// The three apps built from this codebase. APP_TARGET picks one at build time.
export type AppTarget = 'customer' | 'worker' | 'admin'
export type SessionScope = 'consumer' | 'staff'
export type Role = 'customer' | 'worker' | 'admin' | 'finance' | 'support' | 'verifier'

export const STAFF_ROLES: Role[] = ['admin', 'finance', 'support', 'verifier']

export interface TargetConfig {
  name: string
  shortName: string
  themeColor: string
  scope: SessionScope
  /** Role the app asks for when it refreshes the session. */
  defaultRole: Role | null
  /** Roles allowed to use this app once logged in. */
  roles: Role[]
}

export const TARGETS: Record<AppTarget, TargetConfig> = {
  customer: {
    name: 'Workerly',
    shortName: 'Workerly',
    themeColor: '#0f766e',
    scope: 'consumer',
    defaultRole: 'customer',
    roles: ['customer'],
  },
  worker: {
    name: 'Workerly Pro',
    shortName: 'Workerly Pro',
    themeColor: '#1d4ed8',
    scope: 'consumer',
    defaultRole: 'worker',
    // Customers may log in here; they see the "become a worker" screen.
    roles: ['worker', 'customer'],
  },
  admin: {
    name: 'Workerly Admin',
    shortName: 'Admin',
    themeColor: '#111827',
    scope: 'staff',
    defaultRole: null,
    roles: STAFF_ROLES,
  },
}

export function isAppTarget(value: unknown): value is AppTarget {
  return value === 'customer' || value === 'worker' || value === 'admin'
}
