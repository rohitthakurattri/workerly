import { createCable, type CableTicket } from '~/utils/cable'

let cable: ReturnType<typeof createCable> | null = null

/** One WebSocket per tab, opened on first use and closed on logout (useAuth().logout). */
export function useCable() {
  const api = useApi()
  if (!cable && import.meta.client) {
    cable = createCable(async () => (await api<{ data: CableTicket }>('/cable_tickets', { method: 'POST' })).data)
  }
  return cable
}

export function closeCable() {
  cable?.close()
  cable = null
}
