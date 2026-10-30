# ADR 0004 — Worker verification

**Status:** accepted 2026-10-30 (Phase 2). The open questions from the plan were answered with defaults, all changeable later.

## Defaults
- **Required:** one ID proof (masked Aadhaar, PAN, voter ID, driving licence or passport) and one address proof (masked Aadhaar, voter ID, driving licence, passport, utility bill or rent agreement). A trade certificate is optional.
- **No police verification and no in-person step** for the pilot. To add one later, add a document kind or a checklist item to `WorkerDocument::REQUIRED_KINDS` / `Workers::Requirements`.
- **Launch categories:** plumber, electrician, carpenter, AC repair, painter, appliance repair. Cities: Mohali and Chandigarh launched; Zirakpur and Panchkula seeded but not launched.

## State machine (`worker_profiles.verification_status`)
```
draft ──submit──▶ pending_review ──approve──▶ approved
  ▲                    │  └──reject──▶ rejected (final)
  └──resubmit── changes_requested ◀──request changes──┘
```
- Suspension is separate (`suspended_at`), so a suspended worker keeps their approval history and can be reinstated.
- Documents can be edited only in `draft` and `changes_requested`. Approval requires every pending document to be decided, and both required kinds approved, in the same transaction.
- `available` can be true only when the worker is approved and not suspended. This is enforced by a DB CHECK constraint as well as the policy.

## Data handling
- **Identity numbers:** only the last 4 characters are stored. Full Aadhaar copies are not accepted (the UI asks for masked Aadhaar, and verifiers reject unmasked ones).
- **Files:** stored on a private disk in development and a private S3 bucket with SSE-KMS in production. The API hands out only 5-minute signed URLs, and in production the non-expiring Rails blob routes are turned off.
- **Upload checks:** file types are checked from the file bytes (Marcel), not the file name. Limits: photo 5 MB, documents 10 MB.
- **Who sees documents:** only the worker and staff with the `admin`, `verifier` or `support` role. Customers never see them.
- **Audit trail:** every staff decision writes a `worker_verifications` row and an `admin_actions` row in the same transaction. Both are append-only in the app (read-only models). DB triggers will follow when the schema moves to `structure.sql` (needed for the ledger in Phase 7).

## Role matrix
| Action | admin | verifier | support | finance |
| --- | --- | --- | --- | --- |
| View workers and documents | ✓ | ✓ | ✓ | – |
| Approve / request changes / reject | ✓ | ✓ | – | – |
| Suspend / reinstate | ✓ | – | ✓ | – |
| Audit log | ✓ | – | – | – |
| Create / edit categories | ✓ | – | – | – |
