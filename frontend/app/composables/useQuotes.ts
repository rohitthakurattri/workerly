import { ref } from 'vue'
import type { QuotationInput, WorkerBooking, WorkerQuotation } from '~/types/models'

const jobs = ref<WorkerBooking[] | null>(null)

/** Worker side: the worker's own quotes and the jobs they won. */
export function useQuotes() {
  const api = useApi()

  const create = async (leadId: string, body: QuotationInput) =>
    (await api<{ data: WorkerQuotation }>(`/worker/leads/${leadId}/quotations`, { method: 'POST', body })).data

  const revise = async (id: string, body: QuotationInput) =>
    (await api<{ data: WorkerQuotation }>(`/worker/quotations/${id}`, { method: 'PATCH', body })).data

  const withdraw = async (id: string) =>
    (await api<{ data: WorkerQuotation }>(`/worker/quotations/${id}/withdraw`, { method: 'POST' })).data

  const list = async (status?: string) =>
    (await api<{ data: WorkerQuotation[] }>('/worker/quotations', { query: status ? { 'filter[status]': status } : {} })).data

  async function loadJobs() {
    jobs.value = (await api<{ data: WorkerBooking[] }>('/worker/bookings')).data
    return jobs.value
  }

  const findJob = async (id: string) => (await api<{ data: WorkerBooking }>(`/worker/bookings/${id}`)).data

  return { jobs, create, revise, withdraw, list, loadJobs, findJob }
}
