import type { AppTarget } from '../targets'

export interface SecurityHeaderOptions {
  target: AppTarget
  /** Per-request nonce for the few inline scripts Nuxt renders (payload/config). */
  nonce: string
  apiBase: string
  /** Where signed file URLs point (S3 bucket / CDN). The API origin is always allowed. */
  assetOrigins?: string[]
  /** Leaflet tile URL template, e.g. https://{s}.tile.example.com/{z}/{x}/{y}.png */
  mapTileUrl?: string
  production: boolean
}

const RAZORPAY = {
  script: ['https://checkout.razorpay.com'],
  frame: ['https://api.razorpay.com', 'https://checkout.razorpay.com'],
  connect: ['https://api.razorpay.com', 'https://lumberjack.razorpay.com'],
  img: ['https://*.razorpay.com'],
}

const origin = (url: string) => {
  try {
    return new URL(url).origin
  }
  catch {
    return null
  }
}

/** The tile server's origin; "{s}" subdomains become a wildcard. */
export function tileOrigin(template?: string): string | null {
  if (!template) return null
  const m = template.match(/^(https?:\/\/)([^/]+)/)
  if (!m) return null
  return `${m[1]}${m[2]!.replace(/\{s\}/g, '*')}`
}

/** wss://api.example.com for https://api.example.com/api/v1 (Action Cable lives on the API host). */
export function cableOrigin(apiBase: string): string | null {
  const o = origin(apiBase)
  return o ? o.replace(/^http/, 'ws') : null
}

const uniq = (list: (string | null | undefined)[]) => [...new Set(list.filter((x): x is string => !!x))]

/**
 * Headers for every HTML page of an app. Scripts: our own bundle plus nonce'd inline scripts only
 * (Razorpay checkout in the customer app). Styles allow inline (Vue/Leaflet set style attributes).
 * Only the customer app may use the microphone (voice notes) or take payments.
 */
export function securityHeaders(o: SecurityHeaderOptions): Record<string, string> {
  const customer = o.target === 'customer'
  const api = origin(o.apiBase)
  const files = uniq([api, ...(o.assetOrigins ?? []).map(origin)])
  const maps = o.target === 'admin' ? [] : uniq([tileOrigin(o.mapTileUrl)])

  const csp: Record<string, string[]> = {
    'default-src': ["'self'"],
    'script-src': ["'self'", `'nonce-${o.nonce}'`, ...(customer ? RAZORPAY.script : [])],
    'style-src': ["'self'", "'unsafe-inline'"],
    'img-src': ["'self'", 'data:', 'blob:', ...files, ...maps, ...(customer ? RAZORPAY.img : [])],
    'media-src': ["'self'", 'blob:', ...files],
    'font-src': ["'self'", 'data:'],
    'connect-src': ["'self'", ...uniq([api, cableOrigin(o.apiBase)]), ...(customer ? RAZORPAY.connect : [])],
    'frame-src': customer ? RAZORPAY.frame : ["'none'"],
    'worker-src': ["'self'"],
    'manifest-src': ["'self'"],
    'object-src': ["'none'"],
    'base-uri': ["'self'"],
    'form-action': ["'self'"],
    'frame-ancestors': ["'none'"],
  }
  const policy = Object.entries(csp).map(([k, v]) => `${k} ${v.join(' ')}`)
  if (o.production) policy.push('upgrade-insecure-requests')

  const permissions = [
    `camera=${customer || o.target === 'worker' ? '(self)' : '()'}`,
    `microphone=${customer ? '(self)' : '()'}`,
    `geolocation=${o.target === 'admin' ? '()' : '(self)'}`,
    `payment=${customer ? '(self "https://checkout.razorpay.com")' : '()'}`,
  ]

  return {
    'Content-Security-Policy': policy.join('; '),
    'Permissions-Policy': permissions.join(', '),
    'Referrer-Policy': 'strict-origin-when-cross-origin',
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    // Razorpay's checkout opens a popup for some payment methods (UPI apps, 3-D Secure).
    'Cross-Origin-Opener-Policy': customer ? 'same-origin-allow-popups' : 'same-origin',
    ...(o.production ? { 'Strict-Transport-Security': 'max-age=31536000; includeSubDomains' } : {}),
  }
}

/** Adds the nonce to every <script> tag Nuxt rendered (ours are the only inline ones). */
export function addNonce(fragment: string, nonce: string): string {
  return fragment.replace(/<script(?![^>]*\snonce=)/g, `<script nonce="${nonce}"`)
}

