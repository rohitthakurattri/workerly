import type { CustomerBooking, Quotation } from '~/types/models'

/** Customer side: compare, accept and decline the quotes on a request. */
export function useQuotations() {
  const api = useApi()

  const list = async (requestId: string) =>
    (await api<{ data: Quotation[] }>(`/customer/service_requests/${requestId}/quotations`)).data

  const find = async (id: string) => (await api<{ data: Quotation }>(`/customer/quotations/${id}`)).data

  /**
   * Books the exact version the customer is looking at. `key` stays the same across retries of one
   * decision (a double tap or a dropped connection), so the server books at most once.
   */
  const accept = async (q: Pick<Quotation, 'id' | 'current_version'>, key: string) =>
    (await api<{ data: CustomerBooking }>(`/customer/quotations/${q.id}/accept`, {
      method: 'POST', body: { version: q.current_version }, headers: { 'Idempotency-Key': key },
    })).data

  const decline = async (id: string, reason?: string) =>
    (await api<{ data: Quotation }>(`/customer/quotations/${id}/decline`, { method: 'POST', body: { reason } })).data

  const findBooking = async (id: string) => (await api<{ data: CustomerBooking }>(`/customer/bookings/${id}`)).data

  /** Calls `onChange` for every quote event on this request (new, updated, withdrawn, booked). */
  function live(requestId: string, onChange: (msg: { type: string, id?: string, booking_id?: string }) => void, onConnect?: () => void) {
    const cable = useCable()
    if (!cable) return () => {}
    return cable.subscribe('RequestChannel', {
      params: { id: requestId },
      onConfirm: () => onConnect?.(),
      onMessage: raw => onChange(raw as { type: string, id?: string, booking_id?: string }),
    })
  }

  return { list, find, accept, decline, findBooking, live }
}
