import { afterEach, describe, expect, it, vi } from 'vitest'
import type { Payment } from '~/types/models'
import {
  RAZORPAY_CHECKOUT_SRC, bpsToPercent, isFinalPayment, isSettledPayment, paymentTone, percentToBps, toMinor, waitForPayment,
} from '~/utils/payments'

const payment = (status: Payment['status']): Payment => ({
  id: 'p1', method: 'online', provider: 'fake', status,
  amount: { minor: 50000, currency: 'INR' }, refunded: { minor: 0, currency: 'INR' }, created_at: '2026-11-06T10:00:00Z',
})

describe('payment status', () => {
  it('is final once the webhook has decided', () => {
    expect(isFinalPayment(payment('created'))).toBe(false)
    expect(isFinalPayment(payment('captured'))).toBe(true)
    expect(isFinalPayment(payment('failed'))).toBe(true)
  })

  it('counts refunded payments as settled (money did arrive)', () => {
    expect(isSettledPayment(payment('partially_refunded'))).toBe(true)
    expect(isSettledPayment(payment('failed'))).toBe(false)
    expect(isSettledPayment(payment('amount_mismatch'))).toBe(false)
  })

  it('colours statuses', () => {
    expect(paymentTone('captured')).toBe('success')
    expect(paymentTone('amount_mismatch')).toBe('danger')
    expect(paymentTone('created')).toBe('info')
  })
})

describe('waitForPayment', () => {
  it('polls until the payment is captured', async () => {
    const seq = [payment('created'), payment('created'), payment('captured')]
    const fetch = vi.fn(async () => seq.shift()!)
    const sleep = vi.fn(async () => {})
    const p = await waitForPayment(fetch, { sleep, interval: 10 })
    expect(p.status).toBe('captured')
    expect(fetch).toHaveBeenCalledTimes(3)
    expect(sleep).toHaveBeenCalledTimes(2)
  })

  it('gives up at the deadline and returns the pending payment', async () => {
    let t = 0
    const fetch = vi.fn(async () => payment('created'))
    const p = await waitForPayment(fetch, { timeout: 100, interval: 40, now: () => t, sleep: async (ms) => { t += ms } })
    expect(p.status).toBe('created')
    expect(fetch).toHaveBeenCalledTimes(4) // t = 0, 40, 80, 120
  })
})

describe('amounts typed by staff', () => {
  it('turns rupees into paise', () => {
    expect(toMinor('250')).toBe(25000)
    expect(toMinor('1,250.5')).toBe(125050)
    expect(toMinor('₹ 99.99')).toBe(9999)
  })

  it('rejects anything that is not a positive amount', () => {
    expect(toMinor('0')).toBeNull()
    expect(toMinor('-5')).toBeNull()
    expect(toMinor('1.234')).toBeNull()
    expect(toMinor('abc')).toBeNull()
    expect(toMinor('')).toBeNull()
  })

  it('converts commission percentages and basis points', () => {
    expect(percentToBps('12.5')).toBe(1250)
    expect(percentToBps('10%')).toBe(1000)
    expect(percentToBps('0')).toBe(0)
    expect(percentToBps('50')).toBe(5000)
    expect(percentToBps('50.01')).toBeNull()
    expect(percentToBps('x')).toBeNull()
    expect(bpsToPercent(1250)).toBe('12.5%')
    expect(bpsToPercent(1000)).toBe('10%')
  })
})

describe('loadRazorpay', () => {
  // A stub document: the real one would make happy-dom fetch the script.
  function stubDoc() {
    const scripts: { src?: string, onload?: () => void, onerror?: () => void, remove: () => void }[] = []
    const doc = {
      createElement: () => {
        const s = { remove: () => scripts.splice(scripts.indexOf(s), 1) } as (typeof scripts)[number]
        return s
      },
      head: { appendChild: (s: (typeof scripts)[number]) => scripts.push(s) },
    }
    return { doc: doc as unknown as Document, scripts }
  }
  // The loader caches its promise, so each test gets a fresh copy of the module.
  const fresh = async () => {
    vi.resetModules()
    return (await import('~/utils/payments')).loadRazorpay
  }

  afterEach(() => {
    delete (globalThis as { Razorpay?: unknown }).Razorpay
  })

  it('adds checkout.js once and resolves when it loads', async () => {
    const load = await fresh()
    const { doc, scripts } = stubDoc()
    const first = load(doc)
    const second = load(doc)
    expect(scripts).toHaveLength(1)
    expect(scripts[0]!.src).toBe(RAZORPAY_CHECKOUT_SRC)
    scripts[0]!.onload!()
    await expect(first).resolves.toBeUndefined()
    await expect(second).resolves.toBeUndefined()
  })

  it('skips loading when Razorpay is already there', async () => {
    const load = await fresh()
    ;(globalThis as { Razorpay?: unknown }).Razorpay = function () {}
    const { doc, scripts } = stubDoc()
    await load(doc)
    expect(scripts).toHaveLength(0)
  })

  it('lets a later call retry after a failed load', async () => {
    const load = await fresh()
    const { doc, scripts } = stubDoc()
    const p = load(doc)
    scripts[0]!.onerror!()
    await expect(p).rejects.toThrow('checkout_unavailable')
    expect(scripts).toHaveLength(0)
    void load(doc)
    expect(scripts).toHaveLength(1)
  })
})
