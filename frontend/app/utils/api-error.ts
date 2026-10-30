/** The API's error shape: { error: { code, message, details, request_id } } */
export class ApiError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
    public details: Record<string, unknown> = {},
    public requestId?: string,
  ) {
    super(message)
    this.name = 'ApiError'
  }

  get fieldErrors(): Record<string, string[]> {
    return (this.details.field_errors as Record<string, string[]>) ?? {}
  }

  static from(error: unknown): ApiError {
    if (error instanceof ApiError) return error
    const e = error as { status?: number, statusCode?: number, data?: { error?: { code?: string, message?: string, details?: Record<string, unknown>, request_id?: string } } }
    const body = e?.data?.error
    const status = e?.status ?? e?.statusCode ?? 0
    if (body?.code) return new ApiError(status, body.code, body.message ?? body.code, body.details ?? {}, body.request_id)
    if (status === 0) return new ApiError(0, 'network_error', 'Could not reach Workerly. Check your connection.')
    return new ApiError(status, 'unexpected_error', 'Something went wrong. Please try again.')
  }
}
