import { ref } from 'vue'
import type { RequestPhoto, ServiceRequest, ServiceRequestSummary, Triage, Urgency, VoiceNote } from '~/types/models'
import { compressImage } from '~/utils/image'
import { voiceFilename } from '~/utils/voice'

export interface RequestChanges {
  description?: string
  category?: string | null
  address?: string | null
  answers?: { question: string, answer: string }[]
  urgency?: Urgency
  preferred_from?: string | null
  preferred_to?: string | null
}

// The request being created or viewed; shared between the wizard's step components.
const request = ref<ServiceRequest | null>(null)
const triage = ref<Triage | null>(null)
// Parallel photo uploads on a new request must share one draft, not create one each.
let creating: Promise<ServiceRequest> | null = null

export function useServiceRequest() {
  const api = useApi()
  const base = '/customer/service_requests'

  function set(r: ServiceRequest) {
    request.value = r
    triage.value = r.triage ?? null
    return r
  }

  async function load(id: string) {
    return set((await api<{ data: ServiceRequest }>(`${base}/${id}`)).data)
  }

  async function list(status?: 'active' | 'draft' | 'past', cursor?: string | null) {
    const query: Record<string, string> = {}
    if (status) query['filter[status]'] = status
    if (cursor) query.cursor = cursor
    return api<{ data: ServiceRequestSummary[], meta: { next_cursor: string | null } }>(base, { query })
  }

  /** The draft is created lazily, on the first save or photo, so opening the form leaves nothing behind. */
  async function ensureDraft(changes: RequestChanges = {}) {
    if (request.value?.status === 'draft') return request.value
    creating ??= api<{ data: ServiceRequest }>(base, { method: 'POST', body: changes })
      .then(res => set(res.data))
      .finally(() => { creating = null })
    return creating
  }

  async function save(changes: RequestChanges) {
    if (!request.value) return ensureDraft(changes)
    return set((await api<{ data: ServiceRequest }>(`${base}/${request.value.id}`, { method: 'PATCH', body: changes })).data)
  }

  async function addPhoto(file: File) {
    const draft = await ensureDraft()
    const body = new FormData()
    body.append('file', await compressImage(file))
    const photo = (await api<{ data: RequestPhoto }>(`${base}/${draft.id}/attachments`, { method: 'POST', body })).data
    // Re-read the current value: other uploads may have finished while this one was in flight.
    if (request.value?.id === draft.id) request.value = { ...request.value, photos: [...request.value.photos, photo] }
    return photo
  }

  async function removePhoto(id: string) {
    if (!request.value) return
    await api(`${base}/${request.value.id}/attachments/${id}`, { method: 'DELETE' })
    request.value = { ...request.value, photos: request.value.photos.filter(p => p.id !== id) }
  }

  /** Uploads (or replaces) the draft's voice note; the server transcribes it in the background. */
  async function addVoiceNote(audio: Blob, durationMs: number) {
    const draft = await ensureDraft()
    const body = new FormData()
    body.append('file', audio, voiceFilename(audio.type))
    body.append('duration_ms', String(Math.round(durationMs)))
    const note = (await api<{ data: VoiceNote }>(`${base}/${draft.id}/voice_note`, { method: 'POST', body })).data
    if (request.value?.id === draft.id) request.value = { ...request.value, voice_note: note }
    return note
  }

  async function removeVoiceNote() {
    const note = request.value?.voice_note
    if (!request.value || !note) return
    await api(`${base}/${request.value.id}/attachments/${note.id}`, { method: 'DELETE' })
    request.value = { ...request.value, voice_note: null }
  }

  /** Re-reads the voice note (while its transcript is pending), keeping the rest of the local draft. */
  async function refreshVoiceNote() {
    if (!request.value) return null
    const fresh = (await api<{ data: ServiceRequest }>(`${base}/${request.value.id}`)).data
    if (request.value?.id === fresh.id) request.value = { ...request.value, voice_note: fresh.voice_note ?? null }
    return fresh.voice_note ?? null
  }

  /** AI suggestion. Throws ApiError (ai_unavailable, 503) when the customer should pick themselves. */
  async function runTriage() {
    if (!request.value) return null
    triage.value = (await api<{ data: Triage }>(`${base}/${request.value.id}/triage`, { method: 'POST' })).data
    return triage.value
  }

  async function submit() {
    return set((await api<{ data: ServiceRequest }>(`${base}/${request.value!.id}/submit`, { method: 'POST' })).data)
  }

  async function cancel(reason?: string) {
    return set((await api<{ data: ServiceRequest }>(`${base}/${request.value!.id}/cancel`, { method: 'POST', body: { reason } })).data)
  }

  async function discard() {
    if (request.value) await api(`${base}/${request.value.id}`, { method: 'DELETE' })
    reset()
  }

  function reset() {
    creating = null
    request.value = null
    triage.value = null
  }

  return { request, triage, load, list, ensureDraft, save, addPhoto, removePhoto, addVoiceNote, removeVoiceNote, refreshVoiceNote, runTriage, submit, cancel, discard, reset }
}
