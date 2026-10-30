import { ApiError } from './api-error'

type Fetcher = <T>(url: string, opts?: Record<string, unknown>) => Promise<T>

export interface ApiClientOptions {
  fetcher: Fetcher
  getToken: () => string | null
  /** Gets a fresh access token, or returns null when the session is gone. */
  refresh: () => Promise<string | null>
  onUnauthenticated: () => void
}

const REFRESHABLE = new Set(['token_expired', 'missing_token'])

/**
 * Wraps fetch with the bearer token. On an expired token it refreshes once and
 * retries; parallel callers share one refresh so the refresh token rotates once.
 */
export function createApiClient(o: ApiClientOptions) {
  let inflight: Promise<string | null> | null = null
  const refreshOnce = () => {
    inflight ??= o.refresh().finally(() => {
      inflight = null
    })
    return inflight
  }

  async function request<T>(url: string, opts: Record<string, unknown> = {}, retried = false): Promise<T> {
    const token = o.getToken()
    const headers = { ...(opts.headers as Record<string, string>), ...(token ? { Authorization: `Bearer ${token}` } : {}) }
    try {
      return await o.fetcher<T>(url, { ...opts, headers })
    }
    catch (raw) {
      const err = ApiError.from(raw)
      if (err.status === 401 && !retried && REFRESHABLE.has(err.code)) {
        const fresh = await refreshOnce()
        if (fresh) return request<T>(url, opts, true)
      }
      if (err.status === 401) o.onUnauthenticated()
      throw err
    }
  }

  return { request, refreshOnce }
}
