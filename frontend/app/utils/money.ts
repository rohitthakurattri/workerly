/** Money travels as integer minor units (paise) plus an ISO currency code. */
export interface Money {
  minor: number
  currency: string
}

const MINOR_DIGITS: Record<string, number> = { INR: 2, JPY: 0 }

export function formatMoney({ minor, currency }: Money, locale = 'en-IN'): string {
  const digits = MINOR_DIGITS[currency] ?? 2
  const major = minor / 10 ** digits
  return new Intl.NumberFormat(locale, {
    style: 'currency',
    currency,
    minimumFractionDigits: Number.isInteger(major) ? 0 : digits,
    maximumFractionDigits: digits,
  }).format(major)
}
