import { describe, expect, it } from 'vitest'
import type { WorkerDocument } from '~/types/models'
import { DOC_TYPES, firstOpenStep, lastRejection, liveDocument, stepStatus, workerHome } from '~/utils/onboarding'

const doc = (kind: WorkerDocument['kind'], status: WorkerDocument['status'], id = `${kind}-${status}`): WorkerDocument =>
  ({ id, kind, status, doc_type: 'pan', number_last4: null, rejection_reason: status === 'rejected' ? 'Blurry' : null, uploaded_at: '' } as WorkerDocument)

describe('onboarding steps', () => {
  it('maps missing items to their step', () => {
    const p = { missing: ['photo', 'document_address'] }
    expect(stepStatus(p, 'about')).toBe('todo')
    expect(stepStatus(p, 'skills')).toBe('done')
    expect(stepStatus(p, 'documents')).toBe('todo')
    expect(stepStatus(p, 'review')).toBe('todo')
  })

  it('opens the earliest incomplete step, or review when nothing is missing', () => {
    expect(firstOpenStep({ missing: ['service_area', 'skills'] })).toBe('skills')
    expect(firstOpenStep({ missing: [] })).toBe('review')
  })
})

describe('documents', () => {
  it('mirrors the server rules: PAN proves identity but not address', () => {
    expect(DOC_TYPES.identity).toContain('pan')
    expect(DOC_TYPES.address).not.toContain('pan')
    expect(DOC_TYPES.address).toContain('aadhaar_masked')
  })

  it('finds the live document and the last rejection for a kind', () => {
    const profile = { documents: [doc('address', 'rejected', 'a1'), doc('address', 'pending', 'a2'), doc('identity', 'superseded')] }
    expect(liveDocument(profile, 'address')?.id).toBe('a2')
    expect(liveDocument(profile, 'identity')).toBeUndefined()
    expect(lastRejection(profile, 'address')?.id).toBe('a1')
  })
})

describe('workerHome', () => {
  it.each([
    ['draft', false, '/onboarding'],
    ['changes_requested', false, '/onboarding'],
    ['pending_review', false, '/verification'],
    ['rejected', false, '/verification'],
    ['approved', true, '/verification'],
    ['approved', false, '/'],
  ] as const)('%s (suspended=%s) -> %s', (status, suspended, path) => {
    expect(workerHome({ verification_status: status, suspended })).toBe(path)
  })
})
