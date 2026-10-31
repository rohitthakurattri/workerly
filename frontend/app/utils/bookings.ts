import type { BookingStatus, QuotationKind } from '~/types/models'
import { zonedIso } from './requests'

/** Mirrors Bookings::Transitions: the main path a booking takes, for the progress steps. */
export function bookingSteps(kind: QuotationKind): BookingStatus[] {
  return kind === 'inspection'
    ? ['confirmed', 'inspection_scheduled', 'inspecting', 'awaiting_final_approval', 'scheduled', 'in_progress', 'completed']
    : ['confirmed', 'scheduled', 'in_progress', 'completed']
}

/** Where the booking is on its main path (awaiting extra charges counts as in progress). -1 if off the path. */
export function stepIndex(kind: QuotationKind, status: BookingStatus): number {
  const s = status === 'awaiting_change_approval' ? 'in_progress' : (status === 'paid' || status === 'disputed' ? 'completed' : status)
  return bookingSteps(kind).indexOf(s)
}

export function bookingTone(status: BookingStatus): 'neutral' | 'info' | 'success' | 'warning' | 'danger' {
  if (['completed', 'paid'].includes(status)) return 'success'
  if (['cancelled', 'rejected', 'closed_after_inspection', 'refunded'].includes(status)) return 'neutral'
  if (['awaiting_final_approval', 'awaiting_change_approval', 'disputed'].includes(status)) return 'warning'
  return 'info'
}

/** The value for <input type="datetime-local"> in the city's zone, and back to ISO with the zone's offset. */
export function toLocalInput(iso: string | null | undefined, timeZone: string): string {
  if (!iso) return ''
  const parts = new Intl.DateTimeFormat('en-CA', { timeZone, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' })
    .formatToParts(new Date(iso))
  const get = (t: string) => parts.find(p => p.type === t)?.value ?? '00'
  return `${get('year')}-${get('month')}-${get('day')}T${get('hour')}:${get('minute')}`
}

/** "2026-11-02T10:15" typed in the city's zone -> "2026-11-02T10:15:00+05:30". */
export function fromLocalInput(value: string, timeZone: string): string {
  const [date, time = '00:00'] = value.split('T') as [string, string?]
  const [hh = '00', mm = '00'] = time.split(':')
  return zonedIso(date, Number(hh), timeZone).replace(`T${hh}:00:00`, `T${hh}:${mm}:00`)
}
