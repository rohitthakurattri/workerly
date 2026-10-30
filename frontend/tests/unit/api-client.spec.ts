import { describe, expect, it, vi } from 'vitest'
import { createApiClient } from '~/utils/api-client'
import { ApiError } from '~/utils/api-error'

const apiErr = (status: number, code: string) => Object.assign(new Error(code), { status, data: { error: { code, message: code, details: {}, request_id: 'r1' } } })

function setup(fetcher: (url: string, opts?: Record<string, unknown>) => Promise<unknown>) {
  let token: string | null = 'old'
  const refresh = vi.fn(async () => {
    await new Promise(r => setTimeout(r, 5))
    token = 'new'
    return token
  })
  const onUnauthenticated = vi.fn()
  const client = createApiClient({ fetcher: fetcher as never, getToken: () => token, refresh, onUnauthenticated })
  return { client, refresh, onUnauthenticated }
}

describe('createApiClient', () => {
  it('sends the bearer token', async () => {
    const fetcher = vi.fn().mockResolvedValue({ ok: true })
    const { client } = setup(fetcher)
    await client.request('/me')
    expect(fetcher).toHaveBeenCalledWith('/me', { headers: { Authorization: 'Bearer old' } })
  })

  it('refreshes once on token_expired and retries with the new token', async () => {
    const fetcher = vi.fn()
      .mockRejectedValueOnce(apiErr(401, 'token_expired'))
      .mockResolvedValueOnce({ ok: true })
    const { client, refresh } = setup(fetcher)

    await expect(client.request('/me')).resolves.toEqual({ ok: true })
    expect(refresh).toHaveBeenCalledTimes(1)
    expect(fetcher).toHaveBeenLastCalledWith('/me', { headers: { Authorization: 'Bearer new' } })
  })

  it('shares one refresh between parallel requests so the refresh token rotates once', async () => {
    const fetcher = vi.fn(async (_url: string, opts?: Record<string, unknown>) => {
      if ((opts?.headers as Record<string, string>).Authorization === 'Bearer old') throw apiErr(401, 'token_expired')
      return 'ok'
    })
    const { client, refresh } = setup(fetcher)

    await Promise.all([client.request('/a'), client.request('/b'), client.request('/c')])
    expect(refresh).toHaveBeenCalledTimes(1)
  })

  it('does not refresh on other 401s and signals logout', async () => {
    const { client, refresh, onUnauthenticated } = setup(vi.fn().mockRejectedValue(apiErr(401, 'session_expired')))
    await expect(client.request('/me')).rejects.toMatchObject({ code: 'session_expired', status: 401 })
    expect(refresh).not.toHaveBeenCalled()
    expect(onUnauthenticated).toHaveBeenCalled()
  })

  it('maps API errors to ApiError with field errors', async () => {
    const err = Object.assign(new Error(), { status: 422, data: { error: { code: 'validation_failed', message: 'Fix it', details: { field_errors: { name: ['too long'] } } } } })
    const { client } = setup(vi.fn().mockRejectedValue(err))
    const caught = await client.request('/me').catch(e => e)
    expect(caught).toBeInstanceOf(ApiError)
    expect(caught.fieldErrors).toEqual({ name: ['too long'] })
  })

  it('reports network failures as network_error', () => {
    expect(ApiError.from(new TypeError('fetch failed')).code).toBe('network_error')
  })
})
