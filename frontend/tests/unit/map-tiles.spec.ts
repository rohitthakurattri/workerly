import { describe, expect, it } from 'vitest'
import { resolveMapTiles } from '~/utils/map-tiles'
import { securityHeaders, tileOrigin } from '~/utils/security-headers'

describe('map tiles', () => {
  it('defaults to OpenStreetMap for development', () => {
    const t = resolveMapTiles({})
    expect(t).toMatchObject({ provider: 'osm', url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png' })
    expect(t.problem).toBeUndefined()
  })

  it('builds MapTiler raster tiles with the key, retina tiles and both credits', () => {
    const t = resolveMapTiles({ mapProvider: 'maptiler', maptilerKey: 'k3y+/x' })
    expect(t.url).toBe('https://api.maptiler.com/maps/streets-v4/256/{z}/{x}/{y}{r}.png?key=k3y%2B%2Fx')
    expect(t.attribution).toContain('https://www.maptiler.com/copyright/')
    expect(t.attribution).toContain('OpenStreetMap contributors')
    expect(t.options).toEqual({ maxZoom: 20, minZoom: 1, crossOrigin: true })
  })

  it('takes another MapTiler style but nothing that could break the URL', () => {
    expect(resolveMapTiles({ mapProvider: 'maptiler', maptilerKey: 'k', maptilerStyle: 'basic-v2' }).url).toContain('/maps/basic-v2/256/')
    expect(resolveMapTiles({ mapProvider: 'maptiler', maptilerKey: 'k', maptilerStyle: '../evil?x=' }).url).toContain('/maps/evilx/256/')
  })

  it('falls back to OpenStreetMap and says why when MapTiler has no key', () => {
    const t = resolveMapTiles({ mapProvider: 'maptiler', maptilerKey: ' ' })
    expect(t.provider).toBe('osm')
    expect(t.problem).toMatch(/NUXT_PUBLIC_MAPTILER_KEY/)
  })

  it('passes a custom URL through', () => {
    expect(resolveMapTiles({ mapProvider: 'custom', mapTileUrl: 'https://t.example.com/{z}/{x}/{y}.png', mapAttribution: '© Example' }))
      .toMatchObject({ provider: 'custom', url: 'https://t.example.com/{z}/{x}/{y}.png', attribution: '© Example' })
    expect(resolveMapTiles({ mapProvider: 'custom' }).problem).toMatch(/NUXT_PUBLIC_MAP_TILE_URL/)
  })

  it('lets the CSP allow exactly the MapTiler host, not the key', () => {
    const url = resolveMapTiles({ mapProvider: 'maptiler', maptilerKey: 'secretish' }).url
    expect(tileOrigin(url)).toBe('https://api.maptiler.com')
    const csp = securityHeaders({ target: 'customer', nonce: 'n', apiBase: 'https://api.workerly.in/api/v1', mapTileUrl: url, production: true })['Content-Security-Policy']!
    expect(csp).toContain('img-src \'self\' data: blob: https://api.workerly.in https://api.maptiler.com')
    expect(csp).not.toContain('secretish')
  })
})
