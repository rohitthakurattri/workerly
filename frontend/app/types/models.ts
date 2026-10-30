// Friendly names for the generated OpenAPI schemas (app/types/api.d.ts, `npm run gen:api`).
import type { components } from './api'

type S = components['schemas']

export type WorkerProfile = S['worker_profile']
export type WorkerDocument = S['worker_document']
export type ServiceArea = S['service_area']
export type Category = S['category']
export type City = S['city']
export type VerificationStatus = S['verification_status']
export type AdminWorkerSummary = S['admin_worker_summary']
export type AdminWorkerDetail = S['admin_worker_detail']
export type FileRef = NonNullable<S['file']>
export type DocKind = WorkerDocument['kind']
