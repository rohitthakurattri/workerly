import { createApiClient } from '~/utils/api-client'
import { useAuthStore, type SessionPayload } from '~/stores/auth'
import { TARGETS, type AppTarget } from '~/targets'

let client: ReturnType<typeof createApiClient> | null = null

/** Typed API access for the current app. Use `api<T>('/me')`. */
export function useApi() {
  const config = useRuntimeConfig()
  const auth = useAuthStore()

  if (!client || import.meta.server) {
    const target = TARGETS[config.public.appTarget as AppTarget]
    const fetcher = $fetch.create({
      baseURL: config.public.apiBase,
      credentials: 'include', // sends the HttpOnly refresh cookie to /auth/*
      headers: { Accept: 'application/json' },
    })

    client = createApiClient({
      fetcher: (url, opts) => fetcher(url, opts as never),
      getToken: () => auth.accessToken,
      refresh: async () => {
        try {
          const res = await fetcher<{ data: SessionPayload }>('/auth/refresh', {
            method: 'POST',
            body: { scope: target.scope, role: auth.activeRole ?? target.defaultRole ?? undefined },
          })
          auth.setSession(res.data)
          return res.data.access_token
        }
        catch {
          auth.clear()
          return null
        }
      },
      onUnauthenticated: () => auth.clear(),
    })
  }

  return client.request
}

/** Restores or refreshes the session; shared with the API client so it rotates once. */
export function useSessionRefresh() {
  useApi()
  return client!.refreshOnce
}
