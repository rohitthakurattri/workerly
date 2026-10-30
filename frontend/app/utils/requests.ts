import type { RequestStatus, ServiceRequest, Urgency } from '~/types/models'

export type RequestStepId = 'describe' | 'category' | 'address' | 'when' | 'review'
export const REQUEST_STEPS: RequestStepId[] = ['describe', 'category', 'address', 'when', 'review']

/** Mirrors ServiceRequest on the server. */
export const DESCRIPTION_MIN = 10
export const MAX_PHOTOS = 6
export const URGENCIES: Urgency[] = ['asap', 'today', 'this_week', 'flexible']

const STEP_FOR_MISSING: Record<string, RequestStepId> = { description: 'describe', category: 'category', address: 'address' }

/** First step a returning customer still has to do for this draft. */
export function firstOpenRequestStep(request: Pick<ServiceRequest, 'missing'> | null): RequestStepId {
  if (!request) return 'describe'
  const open = request.missing.map(m => STEP_FOR_MISSING[m] ?? 'review')
  return REQUEST_STEPS.find(s => open.includes(s)) ?? 'review'
}

export function statusTone(status: RequestStatus): 'neutral' | 'info' | 'success' | 'warning' | 'danger' {
  return ({ draft: 'neutral', open: 'info', quoting: 'info', booked: 'success', fulfilled: 'success', expired: 'warning', cancelled: 'neutral' } as const)[status]
}

export type Slot = 'morning' | 'afternoon' | 'evening'
export const SLOTS: Record<Slot, [number, number]> = { morning: [8, 12], afternoon: [12, 16], evening: [16, 20] }

/** ISO time with the city's UTC offset, e.g. 2026-11-02T08:00:00+05:30. */
export function zonedIso(date: string, hour: number, timeZone: string): string {
  const hh = String(hour).padStart(2, '0')
  const probe = new Date(`${date}T${hh}:00:00Z`)
  const name = new Intl.DateTimeFormat('en-US', { timeZone, timeZoneName: 'longOffset' })
    .formatToParts(probe).find(p => p.type === 'timeZoneName')?.value ?? 'GMT'
  const offset = name === 'GMT' ? '+00:00' : name.replace('GMT', '')
  return `${date}T${hh}:00:00${offset}`
}

export function slotWindow(date: string, slot: Slot, timeZone: string): { preferred_from: string, preferred_to: string } {
  const [from, to] = SLOTS[slot]
  return { preferred_from: zonedIso(date, from, timeZone), preferred_to: zonedIso(date, to, timeZone) }
}

/** yyyy-mm-dd for "today + days" in the given time zone. */
export function localDate(timeZone: string, days = 0, now = new Date()): string {
  const d = new Date(now.getTime() + days * 86_400_000)
  return new Intl.DateTimeFormat('en-CA', { timeZone, year: 'numeric', month: '2-digit', day: '2-digit' }).format(d)
}
