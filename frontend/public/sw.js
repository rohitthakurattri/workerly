// Workerly service worker (Phase 9): offline page, cached app assets and push notifications.
// One file for the three apps: ?app= picks the icon, ?cache=0 (development) turns caching off so
// Vite's unhashed dev modules are never served stale. API calls are never cached (other origin,
// and they carry personal data).
const params = new URL(self.location.href).searchParams
const app = params.get('app') || 'customer'
const caching = params.get('cache') !== '0'
const VERSION = 'v1'
const SHELL = `workerly-shell-${VERSION}`
const ASSETS = 'workerly-assets'
const OFFLINE = '/offline.html'

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    if (caching) {
      const cache = await caches.open(SHELL)
      await cache.addAll([OFFLINE, `/icons/${app}/icon-192.png`, `/icons/${app}/favicon.svg`])
    }
    await self.skipWaiting()
  })())
})

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keep = caching ? [SHELL, ASSETS] : []
    for (const key of await caches.keys()) {
      if (key.startsWith('workerly-') && !keep.includes(key)) await caches.delete(key)
    }
    await self.clients.claim()
  })())
})

self.addEventListener('fetch', (event) => {
  const request = event.request
  if (!caching || request.method !== 'GET') return
  const url = new URL(request.url)
  if (url.origin !== self.location.origin) return

  // Pages: always the network (they show live data); the offline page when there is none.
  if (request.mode === 'navigate') {
    event.respondWith(fetch(request).catch(async () => (await caches.match(OFFLINE)) || Response.error()))
    return
  }
  // Built assets have content hashes in their names: cache forever, fetch once.
  if (url.pathname.startsWith('/_nuxt/')) {
    event.respondWith((async () => {
      const cache = await caches.open(ASSETS)
      const hit = await cache.match(request)
      if (hit) return hit
      const response = await fetch(request)
      if (response.ok) cache.put(request, response.clone())
      return response
    })())
    return
  }
  // Icons: serve the cached copy, refresh it in the background.
  if (url.pathname.startsWith('/icons/')) {
    event.respondWith((async () => {
      const cache = await caches.open(SHELL)
      const hit = await cache.match(request)
      const refresh = fetch(request).then((response) => {
        if (response.ok) cache.put(request, response.clone())
        return response
      }).catch(() => hit)
      return hit || refresh
    })())
  }
})

self.addEventListener('push', (event) => {
  const data = event.data ? event.data.json() : {}
  event.waitUntil(self.registration.showNotification(data.title || 'Workerly', {
    body: data.body || '',
    tag: data.id,
    icon: `/icons/${app}/icon-192.png`,
    badge: `/icons/${app}/icon-192.png`,
    data: { url: data.url || '/' },
  }))
})

self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  const url = new URL(event.notification.data.url, self.location.origin).href
  event.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
    const open = windows.find(w => new URL(w.url).origin === self.location.origin)
    if (open) return open.navigate(url).then(w => (w || open).focus())
    return self.clients.openWindow(url)
  }))
})
