import { describe, expect, it } from 'vitest'
import { routesForTarget } from '~/utils/target-routes'

const pages = [
  { path: '/login', name: 'login' },
  { path: '/customer', name: 'customer' },
  { path: '/customer/requests', name: 'customer-requests' },
  { path: '/worker', name: 'worker' },
  { path: '/worker/leads/:id()', name: 'worker-leads-id' },
  { path: '/admin', name: 'admin' },
  { path: '/admin/workers', name: 'admin-workers' },
]

describe('routesForTarget', () => {
  it('keeps only the target pages plus shared ones, without the prefix', () => {
    expect(routesForTarget(pages, 'worker')).toEqual([
      { path: '/login', name: 'login' },
      { path: '/', name: 'index' },
      { path: '/leads/:id()', name: 'leads-id' },
    ])
  })

  it('never ships admin or worker pages in the customer app', () => {
    const paths = routesForTarget(pages, 'customer').map(p => p.path)
    expect(paths).toEqual(['/login', '/', '/requests'])
  })

  it('does not confuse a prefix match like /administrators', () => {
    const out = routesForTarget([{ path: '/administrators', name: 'administrators' }], 'customer')
    expect(out).toHaveLength(1)
  })
})
