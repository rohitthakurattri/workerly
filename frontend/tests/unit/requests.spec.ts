import { describe, expect, it } from 'vitest'
import { firstOpenRequestStep, localDate, slotWindow, statusTone, zonedIso } from '~/utils/requests'

describe('request wizard steps', () => {
  it('resumes a draft at the earliest missing step', () => {
    expect(firstOpenRequestStep(null)).toBe('describe')
    expect(firstOpenRequestStep({ missing: ['address', 'category'] })).toBe('category')
    expect(firstOpenRequestStep({ missing: ['address'] })).toBe('address')
    expect(firstOpenRequestStep({ missing: [] })).toBe('review')
  })
})

describe('time windows', () => {
  it('builds ISO times with the city offset', () => {
    expect(zonedIso('2026-11-02', 8, 'Asia/Kolkata')).toBe('2026-11-02T08:00:00+05:30')
    expect(zonedIso('2026-11-02', 16, 'UTC')).toBe('2026-11-02T16:00:00+00:00')
  })

  it('turns a day and slot into a preferred window', () => {
    expect(slotWindow('2026-11-02', 'evening', 'Asia/Kolkata')).toEqual({
      preferred_from: '2026-11-02T16:00:00+05:30',
      preferred_to: '2026-11-02T20:00:00+05:30',
    })
  })

  it('uses the city calendar for "today", not the device one', () => {
    const lateUtc = new Date('2026-11-01T20:00:00Z') // already 2 Nov 01:30 in India
    expect(localDate('Asia/Kolkata', 0, lateUtc)).toBe('2026-11-02')
    expect(localDate('Asia/Kolkata', 1, lateUtc)).toBe('2026-11-03')
  })
})

describe('status tone', () => {
  it('maps every status', () => {
    expect(statusTone('open')).toBe('info')
    expect(statusTone('booked')).toBe('success')
    expect(statusTone('expired')).toBe('warning')
    expect(statusTone('cancelled')).toBe('neutral')
  })
})
