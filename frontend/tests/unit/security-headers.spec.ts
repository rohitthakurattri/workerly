import { describe, expect, it } from 'vitest'
import { addNonce, cableOrigin, securityHeaders, tileOrigin } from '~/utils/security-headers'
import { isIos, serviceWorkerUrl } from '~/utils/pwa'

const base = { nonce: 'abc123', apiBase: 'https://api.workerly.in/api/v1', assetOrigins: ['https://wk-files.s3.ap-south-1.amazonaws.com'],
  mapTileUrl: 'https://{s}.tiles.example.com/{z}/{x}/{y}.png', production: true }
const directives = (csp: string) => Object.fromEntries(csp.split('; ').map((d) => {
  const [k, ...v] = d.split(' ')
  return [k, v]
}))

describe('security headers', () => {
  it('lets the customer app load Razorpay, the microphone and files, and nothing else', () => {
    const h = securityHeaders({ ...base, target: 'customer' })
    const csp = directives(h['Content-Security-Policy']!)
    expect(csp['script-src']).toEqual(["'self'", "'nonce-abc123'", 'https://checkout.razorpay.com'])
    expect(csp['frame-src']).toContain('https://api.razorpay.com')
    expect(csp['connect-src']).toEqual(expect.arrayContaining(['https://api.workerly.in', 'wss://api.workerly.in']))
    expect(csp['img-src']).toEqual(expect.arrayContaining(['https://wk-files.s3.ap-south-1.amazonaws.com', 'https://*.tiles.example.com']))
    expect(csp['media-src']).toContain('https://wk-files.s3.ap-south-1.amazonaws.com')
    expect(csp['frame-ancestors']).toEqual(["'none'"])
    expect(csp['object-src']).toEqual(["'none'"])
    expect(csp['upgrade-insecure-requests']).toEqual([])
    expect(h['Permissions-Policy']).toContain('microphone=(self)')
    expect(h['Strict-Transport-Security']).toBe('max-age=31536000; includeSubDomains')
    expect(h['Cross-Origin-Opener-Policy']).toBe('same-origin-allow-popups')
  })

  it('locks the worker and admin apps down further', () => {
    const worker = directives(securityHeaders({ ...base, target: 'worker' })['Content-Security-Policy']!)
    expect(worker['script-src']).toEqual(["'self'", "'nonce-abc123'"])
    expect(worker['frame-src']).toEqual(["'none'"])
    const admin = securityHeaders({ ...base, target: 'admin' })
    expect(directives(admin['Content-Security-Policy']!)['img-src']).not.toContain('https://*.tiles.example.com')
    expect(admin['Permissions-Policy']).toBe('camera=(), microphone=(), geolocation=(), payment=()')
    expect(admin['Cross-Origin-Opener-Policy']).toBe('same-origin')
  })

  it('skips HSTS and upgrade-insecure-requests off production', () => {
    const h = securityHeaders({ ...base, target: 'worker', production: false })
    expect(h['Strict-Transport-Security']).toBeUndefined()
    expect(h['Content-Security-Policy']).not.toContain('upgrade-insecure-requests')
  })

  it('nonces every script tag once', () => {
    expect(addNonce('<script>a</script><script type="module" src="/x.js"></script>', 'n')).toBe('<script nonce="n">a</script><script nonce="n" type="module" src="/x.js"></script>')
    expect(addNonce('<script nonce="old">a</script>', 'n')).toBe('<script nonce="old">a</script>')
  })

  it('derives the tile and websocket origins', () => {
    expect(tileOrigin('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png')).toBe('https://*.tile.openstreetmap.org')
    expect(tileOrigin('')).toBeNull()
    expect(tileOrigin('https://api.maptiler.com/maps/streets-v4/256/{z}/{x}/{y}{r}.png?key=abc')).toBe('https://api.maptiler.com')
    expect(cableOrigin('http://localhost:3000/api/v1')).toBe('ws://localhost:3000')
  })
})

describe('PWA helpers', () => {
  it('builds the service worker URL', () => {
    expect(serviceWorkerUrl('worker', false)).toBe('/sw.js?app=worker')
    expect(serviceWorkerUrl('customer', true)).toBe('/sw.js?app=customer&cache=0')
  })

  it('recognises iPhones and iPads (which report as Macs)', () => {
    expect(isIos('Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)')).toBe(true)
    expect(isIos('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)', 5)).toBe(true)
    expect(isIos('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)', 0)).toBe(false)
    expect(isIos('Mozilla/5.0 (Linux; Android 14)')).toBe(false)
  })
})
