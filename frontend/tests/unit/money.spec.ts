import { describe, expect, it } from 'vitest'
import { formatMoney } from '~/utils/money'

describe('formatMoney', () => {
  it('formats paise as rupees with Indian grouping', () => {
    expect(formatMoney({ minor: 12345600, currency: 'INR' })).toBe('₹1,23,456')
    expect(formatMoney({ minor: 19950, currency: 'INR' })).toBe('₹199.50')
  })

  it('does not assume INR', () => {
    expect(formatMoney({ minor: 1999, currency: 'USD' }, 'en-US')).toBe('$19.99')
  })
})
