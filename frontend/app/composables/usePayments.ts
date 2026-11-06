import type { Invoice, Payment, PaymentOrder } from '~/types/models'
import { loadRazorpay, waitForPayment } from '~/utils/payments'

/** What the gateway hands the browser after checkout; the server checks its signature. */
export interface CheckoutResult {
  razorpay_payment_id: string
  razorpay_order_id: string
  razorpay_signature: string
}

interface RazorpayInstance {
  open: () => void
  on: (event: string, cb: (res: unknown) => void) => void
}
type RazorpayCtor = new (options: Record<string, unknown>) => RazorpayInstance

/** Online payments for the customer, and invoices for either side. */
export function usePayments() {
  const api = useApi()

  /** One gateway order for what's owed. The server computes the amount and reuses an open order. */
  const createOrder = async (bookingId: string, key: string) =>
    (await api<{ data: PaymentOrder }>(`/customer/bookings/${bookingId}/payments`, { method: 'POST', headers: { 'Idempotency-Key': key } })).data

  const fetchPayment = async (id: string) => (await api<{ data: Payment }>(`/customer/payments/${id}`)).data

  /** Opens Razorpay's checkout. Rejects with 'cancelled' if the customer closes it. */
  async function razorpayCheckout(order: PaymentOrder): Promise<CheckoutResult> {
    await loadRazorpay()
    const Razorpay = (globalThis as unknown as { Razorpay: RazorpayCtor }).Razorpay
    const c = order.checkout
    return new Promise((resolve, reject) => {
      const rzp = new Razorpay({
        key: c.key_id,
        order_id: c.order_id,
        amount: c.amount,
        currency: c.currency,
        name: c.name,
        description: c.description,
        prefill: c.prefill,
        theme: { color: '#0f766e' },
        handler: (res: CheckoutResult) => resolve(res),
        modal: { ondismiss: () => reject(new Error('cancelled')) },
      })
      // Razorpay lets the customer retry inside the same checkout; the webhook records the failure.
      rzp.on('payment.failed', () => {})
      rzp.open()
    })
  }

  /** Development only: plays the gateway's part (sends the signed webhook) for the fake adapter. */
  const fakeCheckout = async (order: PaymentOrder, fail = false) =>
    (await api<{ data: CheckoutResult }>(`/dev/fake_payments/${order.checkout.order_id}/capture`, { method: 'POST', body: fail ? { fail: true } : {} })).data

  /**
   * Hands the checkout's callback to the server, then waits for the webhook to settle the payment.
   * Returns the payment as last seen; it may still be `created` if the webhook is slow.
   */
  async function confirm(order: PaymentOrder, result: CheckoutResult) {
    const id = order.payment.id
    await api(`/customer/payments/${id}/verify`, { method: 'POST', body: result })
    return waitForPayment(() => fetchPayment(id))
  }

  const invoice = async (role: 'customer' | 'worker', bookingId: string) =>
    (await api<{ data: Invoice }>(`/${role}/bookings/${bookingId}/invoice`)).data

  return { createOrder, fetchPayment, razorpayCheckout, fakeCheckout, confirm, invoice }
}
