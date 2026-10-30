import { ref } from 'vue'
import type { Category, City, DocKind, ServiceArea, WorkerDocument, WorkerProfile } from '~/types/models'
import { useAuthStore } from '~/stores/auth'

// Shared across pages in the worker app.
const profile = ref<WorkerProfile | null>(null)
const categories = ref<Category[]>([])
const cities = ref<City[]>([])

export function useWorkerProfile() {
  const api = useApi()
  const auth = useAuthStore()

  async function load() {
    profile.value = (await api<{ data: WorkerProfile }>('/worker/profile')).data
    return profile.value
  }

  async function loadCatalog() {
    if (!categories.value.length) categories.value = (await api<{ data: Category[] }>('/categories')).data
    if (!cities.value.length) cities.value = (await api<{ data: City[] }>('/cities')).data
  }

  /** Customer -> worker. The response carries an access token already acting as worker. */
  async function register(name: string) {
    const res = await api<{ data: { profile: WorkerProfile, access_token: string } }>('/worker/registration', { method: 'POST', body: { name } })
    auth.accessToken = res.data.access_token
    auth.activeRole = 'worker'
    if (auth.user) auth.user = { ...auth.user, name, roles: [...new Set([...auth.user.roles, 'worker' as const])] }
    profile.value = res.data.profile
    return profile.value
  }

  async function updateAbout(attrs: { bio?: string, experience_years?: number | null, photo?: File }) {
    const body = new FormData()
    if (attrs.bio !== undefined) body.append('profile[bio]', attrs.bio)
    if (attrs.experience_years !== undefined) body.append('profile[experience_years]', attrs.experience_years == null ? '' : String(attrs.experience_years))
    if (attrs.photo) body.append('profile[photo]', attrs.photo)
    profile.value = (await api<{ data: WorkerProfile }>('/worker/profile', { method: 'PATCH', body })).data
  }

  async function saveSkills(skills: { category: string, experience_years?: number | null }[]) {
    profile.value = (await api<{ data: WorkerProfile }>('/worker/skills', { method: 'PUT', body: { skills } })).data
  }

  async function addArea(area: { city: string, lat: number, lng: number, radius_m: number, label?: string }) {
    await api<{ data: ServiceArea }>('/worker/service_areas', { method: 'POST', body: area })
    return load()
  }

  async function removeArea(id: string) {
    await api(`/worker/service_areas/${id}`, { method: 'DELETE' })
    return load()
  }

  async function uploadDocument(doc: { kind: DocKind, doc_type: string, number_last4?: string, file: File }) {
    const body = new FormData()
    body.append('kind', doc.kind)
    body.append('doc_type', doc.doc_type)
    if (doc.number_last4) body.append('number_last4', doc.number_last4)
    body.append('file', doc.file)
    await api<{ data: WorkerDocument }>('/worker/documents', { method: 'POST', body })
    return load()
  }

  async function removeDocument(id: string) {
    await api(`/worker/documents/${id}`, { method: 'DELETE' })
    return load()
  }

  async function submit() {
    profile.value = (await api<{ data: WorkerProfile }>('/worker/profile/submit_for_review', { method: 'POST' })).data
  }

  async function setAvailable(available: boolean) {
    profile.value = (await api<{ data: WorkerProfile }>('/worker/availability', { method: 'PATCH', body: { available } })).data
  }

  return { profile, categories, cities, load, loadCatalog, register, updateAbout, saveSkills, addArea, removeArea, uploadDocument, removeDocument, submit, setAvailable }
}
