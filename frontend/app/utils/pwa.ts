/** One service worker for every app; development turns its caching off (Vite modules aren't hashed). */
export const serviceWorkerUrl = (app: string, dev: boolean) => `/sw.js?app=${encodeURIComponent(app)}${dev ? '&cache=0' : ''}`

/** iPhone/iPad Safari: no install prompt event, install is "Share → Add to Home Screen". */
export function isIos(userAgent: string, maxTouchPoints = 0): boolean {
  return /iPad|iPhone|iPod/.test(userAgent) || (/Macintosh/.test(userAgent) && maxTouchPoints > 1)
}
