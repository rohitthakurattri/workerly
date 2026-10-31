import { describe, expect, it } from 'vitest'
import { bookingSteps, bookingTone, fromLocalInput, stepIndex, toLocalInput } from '~/utils/bookings'

describe('booking steps', () => {
  it('has a longer path for inspection jobs', () => {
    expect(bookingSteps('fixed')).toEqual(['confirmed', 'scheduled', 'in_progress', 'completed'])
    expect(bookingSteps('inspection')).toContain('awaiting_final_approval')
  })

  it('places side statuses on the main path', () => {
    expect(stepIndex('fixed', 'awaiting_change_approval')).toBe(2)
    expect(stepIndex('fixed', 'disputed')).toBe(3)
    expect(stepIndex('inspection', 'inspecting')).toBe(2)
    expect(stepIndex('fixed', 'cancelled')).toBe(-1)
  })

  it('colours statuses', () => {
    expect(bookingTone('awaiting_final_approval')).toBe('warning')
    expect(bookingTone('completed')).toBe('success')
    expect(bookingTone('cancelled')).toBe('neutral')
  })
})

describe('datetime-local round trip in the city zone', () => {
  it('shows IST wall time and converts back with the +05:30 offset', () => {
    expect(toLocalInput('2026-11-02T04:30:00Z', 'Asia/Kolkata')).toBe('2026-11-02T10:00')
    expect(fromLocalInput('2026-11-02T10:15', 'Asia/Kolkata')).toBe('2026-11-02T10:15:00+05:30')
    expect(new Date(fromLocalInput(toLocalInput('2026-11-02T04:45:00Z', 'Asia/Kolkata'), 'Asia/Kolkata')).toISOString()).toBe('2026-11-02T04:45:00.000Z')
  })
})
