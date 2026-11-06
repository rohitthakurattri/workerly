import { ref } from 'vue'
import type { BookingMessage, CustomerBooking, QuotationInput, WorkerBooking } from '~/types/models'
import { randomKey } from '~/utils/id'

type Role = 'customer' | 'worker'
type BookingFor<R extends Role> = R extends 'customer' ? CustomerBooking : WorkerBooking

/** One booking, as the customer or the worker sees it, with its chat, kept live over BookingChannel. */
export function useBooking<R extends Role>(role: R) {
  const api = useApi()
  const booking = ref<BookingFor<R> | null>(null)
  const messages = ref<BookingMessage[]>([])
  const base = (id: string) => `/${role}/bookings/${id}`

  async function load(id: string) {
    booking.value = (await api<{ data: BookingFor<R> }>(base(id))).data
    return booking.value
  }

  async function post(path: string, body: object = {}, headers: Record<string, string> = {}) {
    booking.value = (await api<{ data: BookingFor<R> }>(`${base(booking.value!.id)}/${path}`, { method: 'POST', body, headers })).data
    return booking.value
  }

  async function loadMessages() {
    if (!booking.value) return
    messages.value = (await api<{ data: BookingMessage[] }>(`${base(booking.value.id)}/messages`)).data
  }

  async function send(body: string) {
    const m = (await api<{ data: BookingMessage }>(`${base(booking.value!.id)}/messages`, { method: 'POST', body: { body } })).data
    if (!messages.value.some(x => x.id === m.id)) messages.value.push(m)
  }

  /** Refetches on every booking event and appends chat messages as they arrive. */
  function live(onUpdate?: (event: string) => void) {
    const cable = useCable()
    if (!cable || !booking.value) return () => {}
    const id = booking.value.id
    return cable.subscribe('BookingChannel', {
      params: { id },
      onConfirm: () => {
        void load(id)
        void loadMessages()
      },
      onMessage: async (raw) => {
        const msg = raw as { type: string, event?: string, message?: BookingMessage }
        if (msg.type === 'message.new' && msg.message) {
          if (!messages.value.some(x => x.id === msg.message!.id)) messages.value.push(msg.message)
        }
        else if (msg.type === 'booking.updated') {
          await load(id)
          onUpdate?.(msg.event ?? '')
        }
      },
    })
  }

  // Worker events
  const schedule = (scheduledAt: string) => post('schedule', { scheduled_at: scheduledAt })
  const checkIn = () => post('check_in')
  const start = () => post('start')
  const complete = () => post('complete')
  const finalQuotation = (body: QuotationInput) => post('final_quotation', body)
  const changeOrder = (body: QuotationInput) => post('change_orders', body)
  /** The customer paid in cash: the worker confirms the exact amount owed. */
  const cashReceived = (amountMinor: number, key = randomKey()) =>
    post('cash_received', { amount_minor: amountMinor }, { 'Idempotency-Key': key })

  // Customer events. One Idempotency-Key per decision, so a retried tap decides once.
  const decide = (revisionId: string, decision: 'approved' | 'rejected', key = randomKey()) =>
    post('approvals', { revision_id: revisionId, decision }, { 'Idempotency-Key': key })
  const review = (rating: number, body?: string) => post('review', { rating, body })
  const dispute = (category: string, description: string) => post('disputes', { category, description })

  const cancel = (reason?: string) => post('cancel', { reason })

  return { booking, messages, load, loadMessages, send, live, schedule, checkIn, start, complete, finalQuotation, changeOrder, cashReceived, decide, review, dispute, cancel }
}
