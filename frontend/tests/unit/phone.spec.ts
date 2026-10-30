import { describe, expect, it } from 'vitest'
import { formatIndianMobile, normalizeIndianMobile } from '~/utils/phone'

describe('normalizeIndianMobile (mirrors Identity::PhoneNumber)', () => {
  it.each([
    ['9876543210', '+919876543210'],
    ['98765 43210', '+919876543210'],
    ['098765-43210', '+919876543210'],
    ['+91 98765 43210', '+919876543210'],
    ['919876543210', '+919876543210'],
  ])('normalises %s', (input, expected) => {
    expect(normalizeIndianMobile(input)).toBe(expected)
  })

  it.each(['', '12345', '5876543210', '+1 415 555 0100', '98765432101'])('rejects %s', (input) => {
    expect(normalizeIndianMobile(input)).toBeNull()
  })

  it('formats for display', () => {
    expect(formatIndianMobile('+919876543210')).toBe('+91 98765 43210')
  })
})
