import type { DocKind, WorkerProfile } from '~/types/models'

export type StepId = 'about' | 'skills' | 'area' | 'documents' | 'review'

/** Which onboarding step fixes each `missing` key returned by the API. */
const STEP_FOR_MISSING: Record<string, StepId> = {
  name: 'about',
  photo: 'about',
  experience_years: 'about',
  skills: 'skills',
  service_area: 'area',
  document_identity: 'documents',
  document_address: 'documents',
}

export const STEPS: StepId[] = ['about', 'skills', 'area', 'documents', 'review']

export function stepStatus(profile: Pick<WorkerProfile, 'missing'>, step: StepId): 'done' | 'todo' {
  if (step === 'review') return profile.missing.length ? 'todo' : 'done'
  return profile.missing.some(m => (STEP_FOR_MISSING[m] ?? 'review') === step) ? 'todo' : 'done'
}

/** First step that still needs work, so returning workers land in the right place. */
export function firstOpenStep(profile: Pick<WorkerProfile, 'missing'>): StepId {
  return STEPS.find(s => s !== 'review' && stepStatus(profile, s) === 'todo') ?? 'review'
}

/** Mirrors WorkerDocument::DOC_TYPES on the server. */
export const DOC_TYPES: Record<DocKind, string[]> = {
  identity: ['aadhaar_masked', 'pan', 'voter_id', 'driving_licence', 'passport'],
  address: ['aadhaar_masked', 'voter_id', 'driving_licence', 'passport', 'utility_bill', 'rent_agreement'],
  trade: ['trade_certificate', 'other'],
}

export const REQUIRED_KINDS: DocKind[] = ['identity', 'address']

export const ACCEPTED_DOCUMENT_TYPES = 'image/jpeg,image/png,image/webp,image/heic,image/heif,application/pdf'
export const MAX_DOCUMENT_BYTES = 10 * 1024 * 1024
export const MAX_PHOTO_BYTES = 5 * 1024 * 1024

/** The document currently counting for a kind (pending or approved), if any. */
export function liveDocument(profile: Pick<WorkerProfile, 'documents'>, kind: DocKind) {
  return profile.documents.find(d => d.kind === kind && (d.status === 'pending' || d.status === 'approved'))
}

/** The most recent rejection for a kind, shown so the worker knows what to fix. */
export function lastRejection(profile: Pick<WorkerProfile, 'documents'>, kind: DocKind) {
  return [...profile.documents].reverse().find(d => d.kind === kind && d.status === 'rejected')
}

/** Where a worker should be sent based on their verification state. */
export function workerHome(profile: Pick<WorkerProfile, 'verification_status' | 'suspended'> | null): '/onboarding' | '/verification' | '/' {
  if (!profile) return '/'
  if (profile.verification_status === 'draft' || profile.verification_status === 'changes_requested') return '/onboarding'
  if (profile.verification_status === 'approved' && !profile.suspended) return '/'
  return '/verification'
}
