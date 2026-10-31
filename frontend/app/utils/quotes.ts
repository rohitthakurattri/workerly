import type { Quotation, QuotationInput, QuotationStatus, WorkerQuotation } from '~/types/models'

/** Mirrors Quotations::Build and QuotationItem on the server; the server's numbers always win. */
export const ITEM_TYPES = ['labour', 'material', 'transport', 'other'] as const
export const UNITS = ['job', 'item', 'hour', 'visit', 'metre', 'sq_ft', 'kg', 'litre'] as const
export const CONDITIONS = ['new', 'refurbished', 'used'] as const
export const MAX_ITEMS = 30
export const MAX_TOTAL_MINOR = 50_000_000

export type ItemType = typeof ITEM_TYPES[number]

/** One editable line. Prices are typed in rupees; the form converts to paise. */
export interface QuoteLine {
  type: ItemType
  description: string
  brand: string
  quantity: string
  unit: string
  price: string
  condition: string
  warrantyDays: string
}

export const blankLine = (type: ItemType = 'labour'): QuoteLine =>
  ({ type, description: '', brand: '', quantity: '1', unit: type === 'labour' ? 'job' : 'item', price: '', condition: '', warrantyDays: '' })

/** "1,999.5" -> 199950 paise. Returns null for anything that isn't a non-negative amount with ≤ 2 decimals. */
export function toMinor(rupees: string): number | null {
  const clean = rupees.replace(/[,\s₹]/g, '')
  if (!/^\d+(\.\d{1,2})?$/.test(clean)) return null
  const [whole, frac = ''] = clean.split('.')
  return Number(whole) * 100 + Number(frac.padEnd(2, '0'))
}

export const fromMinor = (minor: number): string => (minor % 100 === 0 ? String(minor / 100) : (minor / 100).toFixed(2))

/** quantity × unit price, rounded half up to the paisa (Quotations::Build.line_amount). */
export function lineAmount(quantity: string, unitPriceMinor: number | null): number {
  const q = Number(quantity)
  if (!Number.isFinite(q) || q <= 0 || unitPriceMinor == null) return 0
  // Work in thousandths of a unit so 2.5 × 12345 rounds like BigDecimal on the server.
  const milli = Math.round(q * 1000)
  return Math.floor((milli * unitPriceMinor + 500) / 1000)
}

export const taxFor = (subtotal: number, bps: number): number => Math.floor((subtotal * bps + 5000) / 10_000)

export function quoteTotals(lines: QuoteLine[], taxRateBps: number) {
  const subtotal = lines.reduce((sum, l) => sum + lineAmount(l.quantity, toMinor(l.price)), 0)
  const tax = taxFor(subtotal, taxRateBps)
  return { subtotal, tax, total: subtotal + tax }
}

export function linesToInput(lines: QuoteLine[]): NonNullable<QuotationInput['items']> {
  return lines.map(l => ({
    type: l.type,
    description: l.description.trim(),
    ...(l.brand.trim() ? { brand: l.brand.trim() } : {}),
    quantity: Number(l.quantity),
    unit: l.unit,
    unit_price_minor: toMinor(l.price) ?? -1,
    ...(l.type === 'material' && l.condition ? { condition: l.condition } : {}),
    ...(l.warrantyDays.trim() ? { warranty_days: Number(l.warrantyDays) } : {}),
  }))
}

/** Prefills the form from the worker's current revision when they edit a quote. */
export function linesFromQuote(q: WorkerQuotation): QuoteLine[] {
  return q.revision.items
    .filter(i => i.type !== 'inspection')
    .map(i => ({
      type: i.type as ItemType,
      description: i.description,
      brand: i.brand ?? '',
      quantity: String(i.quantity),
      unit: i.unit,
      price: fromMinor(i.unit_price.minor),
      condition: i.condition ?? '',
      warrantyDays: i.warranty_days == null ? '' : String(i.warranty_days),
    }))
}

export function quoteStatusTone(status: QuotationStatus): 'neutral' | 'info' | 'success' | 'warning' | 'danger' {
  return ({ submitted: 'info', accepted: 'success', declined: 'neutral', withdrawn: 'neutral', expired: 'warning' } as const)[status]
}

/** Longest warranty on any line, in days (0 if none). */
export const bestWarranty = (q: Pick<Quotation, 'revision'>): number =>
  Math.max(0, ...q.revision.items.map(i => i.warranty_days ?? 0))

export type QuoteSort = 'price' | 'rating' | 'distance'
const BAND_ORDER = ['under_1km', '1_3km', '3_5km', '5_10km', 'over_10km']

/** Accepted first, then by the chosen key; ties fall back to price. */
export function sortQuotes(quotes: Quotation[], by: QuoteSort): Quotation[] {
  const price = (q: Quotation) => q.revision.total.minor
  const key = (q: Quotation): number =>
    by === 'rating' ? -(q.worker.rating_avg ?? 0) : by === 'distance' ? BAND_ORDER.indexOf(q.distance_band) : price(q)
  return [...quotes].sort((a, b) =>
    Number(b.status === 'accepted') - Number(a.status === 'accepted') || key(a) - key(b) || price(a) - price(b))
}

/** "1 h 30 min" style estimate from minutes. */
export function durationParts(minutes: number): { hours: number, minutes: number, days: number } {
  const days = Math.floor(minutes / 1440)
  const rest = minutes - days * 1440
  return { days, hours: Math.floor(rest / 60), minutes: rest % 60 }
}
