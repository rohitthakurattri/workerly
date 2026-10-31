// Push-only service worker (Phase 4). The full PWA worker in Phase 9 takes these handlers over.
const app = new URL(self.location.href).searchParams.get('app') || 'customer'

self.addEventListener('push', (event) => {
  const data = event.data ? event.data.json() : {}
  event.waitUntil(self.registration.showNotification(data.title || 'Workerly', {
    body: data.body || '',
    tag: data.id,
    icon: `/icons/${app}/favicon.svg`,
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
