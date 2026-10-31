import { ref } from 'vue'
import type { Lead, QuotationStatus } from '~/types/models'

export interface QuoteStatusMessage { type: 'quote.status', lead_id: string, id: string, status: QuotationStatus, booking_id?: string }

const leads = ref<Lead[] | null>(null)

export function useLeads() {
  const api = useApi()

  async function load() {
    leads.value = (await api<{ data: Lead[] }>('/worker/leads')).data
    return leads.value
  }

  async function find(id: string) {
    const lead = (await api<{ data: Lead }>(`/worker/leads/${id}`)).data
    if (leads.value) leads.value = leads.value.map(l => (l.id === id ? lead : l))
    return lead
  }

  async function decline(id: string, reason?: string) {
    await api(`/worker/leads/${id}/decline`, { method: 'POST', body: { reason } })
    leads.value = leads.value?.filter(l => l.id !== id) ?? null
  }

  /**
   * Live updates: new leads appear at the top, closed ones disappear, and `onQuote` hears when
   * this worker's quote is accepted or declined. Returns an unsubscribe function.
   */
  function live(onNew?: (lead: Lead) => void, onQuote?: (msg: QuoteStatusMessage, lead?: Lead) => void) {
    const cable = useCable()
    if (!cable) return () => {}
    return cable.subscribe('WorkerLeadsChannel', {
      onConfirm: () => void load(), // catch up on anything sent while disconnected
      onMessage: (raw) => {
        const msg = raw as { type: string, lead?: Lead, id?: string } & Partial<Omit<QuoteStatusMessage, 'type'>>
        if (msg.type === 'lead.new' && msg.lead) {
          leads.value = [msg.lead, ...(leads.value ?? []).filter(l => l.id !== msg.lead!.id)]
          onNew?.(msg.lead)
        }
        else if (msg.type === 'lead.closed') {
          leads.value = leads.value?.filter(l => l.id !== msg.id) ?? null
        }
        else if (msg.type === 'quote.status' && msg.lead_id && msg.status) {
          const lead = leads.value?.find(l => l.id === msg.lead_id)
          onQuote?.(msg as QuoteStatusMessage, lead)
          if (lead) void find(lead.id)
        }
      },
    })
  }

  return { leads, load, find, decline, live }
}
