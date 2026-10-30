import { ref } from 'vue'
import type { Address } from '~/types/models'

export interface AddressInput {
  label?: string
  line1: string
  line2?: string
  landmark?: string
  locality: string
  pincode: string
  lat: number
  lng: number
  is_default?: boolean
}

// Shared across pages in the customer app.
const addresses = ref<Address[] | null>(null)

export function useAddresses() {
  const api = useApi()

  async function load() {
    addresses.value = (await api<{ data: Address[] }>('/customer/addresses')).data
    return addresses.value
  }

  async function create(input: AddressInput) {
    const address = (await api<{ data: Address }>('/customer/addresses', { method: 'POST', body: input })).data
    await load()
    return address
  }

  async function update(id: string, input: Partial<AddressInput>) {
    const address = (await api<{ data: Address }>(`/customer/addresses/${id}`, { method: 'PATCH', body: input })).data
    await load()
    return address
  }

  async function remove(id: string) {
    await api(`/customer/addresses/${id}`, { method: 'DELETE' })
    await load()
  }

  return { addresses, load, create, update, remove }
}
