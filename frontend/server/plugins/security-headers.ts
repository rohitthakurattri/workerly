import { randomBytes } from 'node:crypto'
import { addNonce, securityHeaders, usesOsmTiles } from '../../app/utils/security-headers'
import type { AppTarget } from '../../app/targets'

/**
 * CSP with a per-request nonce, plus the other security headers, on every HTML page this app
 * renders (SSR and SPA shells alike). Development skips the CSP: Vite's HMR needs inline scripts
 * and websockets that production never does.
 */
export default defineNitroPlugin((nitro) => {
  const config = useRuntimeConfig()
  const production = !import.meta.dev
  if (production && usesOsmTiles(config.public.mapTileUrl)) {
    console.warn('[workerly] NUXT_PUBLIC_MAP_TILE_URL still points at tile.openstreetmap.org; their servers are not for production traffic.')
  }

  nitro.hooks.hook('render:html', (html, { event }) => {
    if (!production) return
    const nonce = randomBytes(16).toString('base64')
    event.context.cspNonce = nonce
    for (const part of ['head', 'bodyPrepend', 'body', 'bodyAppend'] as const) {
      html[part] = html[part].map(fragment => addNonce(fragment, nonce))
    }
  })

  nitro.hooks.hook('render:response', (response, { event }) => {
    const headers = securityHeaders({
      target: config.public.appTarget as AppTarget,
      nonce: (event.context.cspNonce as string | undefined) ?? 'dev',
      apiBase: config.public.apiBase,
      assetOrigins: String(config.public.assetOrigins || '').split(',').map(s => s.trim()).filter(Boolean),
      mapTileUrl: config.public.mapTileUrl,
      // HSTS and upgrade-insecure-requests only when the deployment really is https (not the local stack).
      production: production && config.public.apiBase.startsWith('https://'),
    })
    if (!production) delete headers['Content-Security-Policy']
    response.headers = { ...response.headers, ...headers }
  })
})
