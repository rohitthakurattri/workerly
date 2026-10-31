import { describe, expect, it } from 'vitest'
import type { Quotation } from '~/types/models'
import { blankLine, durationParts, fromMinor, lineAmount, linesToInput, quoteTotals, sortQuotes, taxFor, toMinor } from '~/utils/quotes'

describe('quote maths (mirrors Quotations::Build)', () => {
  it('parses rupees into paise and back', () => {
    expect(toMinor('1999')).toBe(199900)
    expect(toMinor('1,999.5')).toBe(199950)
    expect(toMinor('₹ 0.05')).toBe(5)
    expect(toMinor('-1')).toBeNull()
    expect(toMinor('1.234')).toBeNull()
    expect(toMinor('')).toBeNull()
    expect(fromMinor(199900)).toBe('1999')
    expect(fromMinor(199950)).toBe('1999.50')
  })

  it('rounds line amounts half up like the server', () => {
    expect(lineAmount('2.5', 12345)).toBe(30863)
    expect(lineAmount('0.333', 300)).toBe(100) // 99.9 -> 100
    expect(lineAmount('1', 50000)).toBe(50000)
    expect(lineAmount('0', 100)).toBe(0)
    expect(lineAmount('abc', 100)).toBe(0)
  })

  it('applies tax in basis points, half up', () => {
    expect(taxFor(10003, 1800)).toBe(1801)
    expect(taxFor(10000, 0)).toBe(0)
  })

  it('totals lines', () => {
    const lines = [{ ...blankLine(), price: '500' }, { ...blankLine('material'), quantity: '2.5', price: '123.45' }]
    expect(quoteTotals(lines, 0)).toEqual({ subtotal: 80863, tax: 0, total: 80863 })
  })

  it('builds the API body, keeping condition only for materials', () => {
    const body = linesToInput([
      { ...blankLine(), description: ' Labour ', price: '500', condition: 'used' },
      { ...blankLine('material'), description: 'Tap', brand: 'Jaquar', price: '450', condition: 'new', warrantyDays: '180' },
    ])
    expect(body).toEqual([
      { type: 'labour', description: 'Labour', quantity: 1, unit: 'job', unit_price_minor: 50000 },
      { type: 'material', description: 'Tap', brand: 'Jaquar', quantity: 1, unit: 'item', unit_price_minor: 45000, condition: 'new', warranty_days: 180 },
    ])
  })

  it('splits durations', () => {
    expect(durationParts(90)).toEqual({ days: 0, hours: 1, minutes: 30 })
    expect(durationParts(1500)).toEqual({ days: 1, hours: 1, minutes: 0 })
  })
})

describe('sortQuotes', () => {
  const q = (id: string, total: number, rating: number | null, band: string, status = 'submitted') =>
    ({ id, status, distance_band: band, worker: { rating_avg: rating }, revision: { total: { minor: total }, items: [] } }) as unknown as Quotation
  const quotes = [q('a', 900, 4.9, '3_5km'), q('b', 600, null, 'under_1km'), q('c', 600, 4.1, '1_3km'), q('d', 1200, 3, 'over_10km', 'accepted')]

  it('puts the accepted quote first, then sorts by the key with price as tie-break', () => {
    expect(sortQuotes(quotes, 'price').map(x => x.id)).toEqual(['d', 'b', 'c', 'a'])
    expect(sortQuotes(quotes, 'rating').map(x => x.id)).toEqual(['d', 'a', 'c', 'b'])
    expect(sortQuotes(quotes, 'distance').map(x => x.id)).toEqual(['d', 'b', 'c', 'a'])
  })
})
