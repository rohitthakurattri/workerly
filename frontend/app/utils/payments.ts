import type { Payment } from '~/types/models'

export const RAZORPAY_CHECKOUT_SRC = 'https://checkout.razorpay.com/v1/checkout.js'

/** A payment is final once the gateway's webhook has landed (captured, failed or refunded). */
export const isFinalPayment = (p: Pick<Payment, 'status'>) => p.status !== 'created'

/** Settled = money actually arrived (the refund statuses keep what wasn't returned). */
export const isSettledPayment = (p: Pick<Payment, 'status'>) =>
  ['captured', 'partially_refunded', 'refunded'].includes(p.status)

export function paymentTone(status: Payment['status']): 'neutral' | 'info' | 'success' | 'warning' | 'danger' {
  if (status === 'captured') return 'success'
  if (status === 'failed' || status === 'amount_mismatch') return 'danger'
  if (status === 'partially_refunded' || status === 'refunded') return 'warning'
  return 'info'
}

export interface WaitOptions {
  /** Delay between polls in ms. */
  interval?: number
  /** Give up after this many ms; the last seen payment is returned (still `created`). */
  timeout?: number
  sleep?: (ms: number) => Promise<void>
  now?: () => number
}

/**
 * After checkout the app polls the payment until the signed webhook marks it captured or failed:
 * the browser callback alone never makes anything paid.
 */
export async function waitForPayment(fetchPayment: () => Promise<Payment>, opts: WaitOptions = {}): Promise<Payment> {
  const { interval = 1500, timeout = 60_000, sleep = ms => new Promise(r => setTimeout(r, ms)), now = Date.now } = opts
  const deadline = now() + timeout
  let p = await fetchPayment()
  while (!isFinalPayment(p) && now() < deadline) {
    await sleep(interval)
    p = await fetchPayment()
  }
  return p
}

/** Rupees typed by staff ("1,250.50") to paise; null when it isn't a positive amount. */
export function toMinor(input: string): number | null {
  const s = input.replace(/[,\s₹]/g, '')
  if (!/^\d+(\.\d{1,2})?$/.test(s)) return null
  const [whole = '0', frac = ''] = s.split('.')
  const minor = Number(whole) * 100 + Number(frac.padEnd(2, '0'))
  return minor > 0 ? minor : null
}

/** Basis points to a percent label: 1250 -> "12.5%". */
export const bpsToPercent = (bps: number) => `${Number((bps / 100).toFixed(2))}%`

/** "12.5" typed as a percent -> 1250 bps; null outside 0–50 (CommissionRule allows at most 5000 bps). */
export function percentToBps(input: string): number | null {
  const s = input.trim().replace(/%$/, '')
  if (!/^\d+(\.\d{1,2})?$/.test(s)) return null
  const bps = Math.round(Number(s) * 100)
  return bps <= MAX_COMMISSION_BPS ? bps : null
}

export const MAX_COMMISSION_BPS = 5000

let scriptPromise: Promise<void> | null = null

/** Loads Razorpay's checkout.js once, on first use (never on pages that don't pay). */
export function loadRazorpay(doc: Document = document): Promise<void> {
  if ((globalThis as { Razorpay?: unknown }).Razorpay) return Promise.resolve()
  scriptPromise ??= new Promise<void>((resolve, reject) => {
    const s = doc.createElement('script')
    s.src = RAZORPAY_CHECKOUT_SRC
    s.async = true
    s.onload = () => resolve()
    s.onerror = () => {
      scriptPromise = null
      s.remove()
      reject(new Error('checkout_unavailable'))
    }
    doc.head.appendChild(s)
  })
  return scriptPromise
}
