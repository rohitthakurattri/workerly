import { TARGETS, type AppTarget } from '../../app/targets'

/** Each app's install manifest (one public/ folder, three apps: built from the running target). */
const DESCRIPTIONS: Record<AppTarget, string> = {
  customer: 'Post a home repair job, compare quotes from verified workers and pay safely.',
  worker: 'Get job requests near you, send quotes and manage your jobs and earnings.',
  admin: 'Workerly operations.',
}

export default defineEventHandler((event) => {
  const target = useRuntimeConfig().public.appTarget as AppTarget
  const t = TARGETS[target]
  setResponseHeader(event, 'Content-Type', 'application/manifest+json; charset=utf-8')
  setResponseHeader(event, 'Cache-Control', 'public, max-age=3600')
  return {
    id: '/',
    name: t.name,
    short_name: t.shortName,
    description: DESCRIPTIONS[target],
    lang: 'en-IN',
    start_url: '/?source=pwa',
    scope: '/',
    display: 'standalone',
    orientation: 'portrait',
    background_color: '#ffffff',
    theme_color: t.themeColor,
    categories: ['business', 'productivity'],
    icons: [
      { src: `/icons/${target}/icon-192.png`, sizes: '192x192', type: 'image/png', purpose: 'any' },
      { src: `/icons/${target}/icon-512.png`, sizes: '512x512', type: 'image/png', purpose: 'any' },
      { src: `/icons/${target}/maskable-512.png`, sizes: '512x512', type: 'image/png', purpose: 'maskable' },
    ],
  }
})
