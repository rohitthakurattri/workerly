import tailwindcss from '@tailwindcss/vite'
import { TARGETS, isAppTarget, type AppTarget } from './app/targets'
import { routesForTarget } from './app/utils/target-routes'

const rawTarget = process.env.APP_TARGET ?? 'customer'
if (!isAppTarget(rawTarget)) throw new Error(`APP_TARGET must be customer, worker or admin (got "${rawTarget}")`)
const target: AppTarget = rawTarget
const t = TARGETS[target]

export default defineNuxtConfig({
  modules: ['@pinia/nuxt', '@nuxtjs/i18n', '@nuxt/eslint'],
  devtools: { enabled: false },

  app: {
    head: {
      htmlAttrs: { lang: 'en' },
      title: t.name,
      meta: [
        { name: 'viewport', content: 'width=device-width, initial-scale=1, viewport-fit=cover' },
        { name: 'theme-color', content: t.themeColor },
        { name: 'apple-mobile-web-app-capable', content: 'yes' },
        { name: 'apple-mobile-web-app-title', content: t.shortName },
        // Admin must never be indexed.
        ...(target === 'admin' ? [{ name: 'robots', content: 'noindex, nofollow' }] : []),
      ],
      link: [
        { rel: 'icon', href: `/icons/${target}/favicon.svg`, type: 'image/svg+xml' },
        { rel: 'manifest', href: '/manifest.webmanifest' },
        { rel: 'apple-touch-icon', href: `/icons/${target}/apple-touch-icon.png` },
      ],
    },
  },
  css: ['~/assets/css/main.css'],

  runtimeConfig: {
    public: {
      appTarget: target,
      apiBase: 'http://localhost:3000/api/v1', // NUXT_PUBLIC_API_BASE
      appUrls: {
        customer: 'http://localhost:3001', // NUXT_PUBLIC_APP_URLS_CUSTOMER
        worker: 'http://localhost:3002',
        admin: 'http://localhost:3003',
      },
      // OpenStreetMap's own tiles are fine for development only (usage policy); production
      // sets a tile provider via NUXT_PUBLIC_MAP_TILE_URL / NUXT_PUBLIC_MAP_ATTRIBUTION.
      // Origins that signed file URLs point at (S3 bucket / CDN), comma-separated, for the CSP.
      assetOrigins: '', // NUXT_PUBLIC_ASSET_ORIGINS
      mapTileUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      mapAttribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    },
  },

  // Separate output per target so the three builds never overwrite each other.
  buildDir: `.nuxt/${target}`,

  // Public pages render on the server; everything behind login is a client-side SPA.
  routeRules: target === 'admin'
    ? { '/**': { ssr: false } }
    : { '/**': { ssr: false }, '/': { ssr: true }, '/login': { ssr: true } },
  compatibilityDate: '2026-10-01',
  nitro: { output: { dir: `.output/${target}` } },
  vite: { plugins: [tailwindcss()] },
  typescript: { strict: true },

  hooks: {
    'pages:extend'(pages) {
      pages.splice(0, pages.length, ...routesForTarget(pages, target))
    },
  },

  i18n: {
    strategy: 'no_prefix',
    defaultLocale: 'en',
    detectBrowserLanguage: { useCookie: true, cookieKey: 'wk_locale', redirectOn: 'root' },
    locales: [
      { code: 'en', language: 'en-IN', name: 'English', file: 'en.json' },
      { code: 'hi', language: 'hi-IN', name: 'हिन्दी', file: 'hi.json' },
      { code: 'pa', language: 'pa-IN', name: 'ਪੰਜਾਬੀ', file: 'pa.json' },
    ],
  },
})
