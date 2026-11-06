# Phase 2 — Worker management (handover)

**Exit gate:** an admin approves a worker end to end, and an unapproved worker gets 403 on every lead endpoint (tested).
**Status (2026-10-30):** met locally.
- RSpec: 173 examples, including a 403 test for every non-approved state.
- Vitest: 40 tests.
- Playwright: 6 tests. One of them runs the full flow: register → onboard → upload documents → submit → admin approves → worker reaches leads.
- RuboCop and Brakeman are clean.

Decisions and defaults are in `docs/adr/0004-worker-verification.md`.

## 1. What was built

**Backend**
- **Geo:** `countries`, `states`, `cities` (PostGIS centre, service radius, `launched` flag). **Catalog:** `service_categories` (tree, names in en/hi/pa). Idempotent seeds: India, Punjab, Chandigarh UT, Haryana; Mohali and Chandigarh launched; six categories.
- **Workers:** `worker_profiles`, `worker_skills`, `worker_service_areas` (geography point + radius 0.5–50 km, must lie inside a launched city, max 3), `worker_documents` (Active Storage, last-4 only, one live document per kind), `worker_verifications` (append-only).
- **Admin:** review queue (oldest first, cursor pagination, search), detail view with short-lived document URLs, per-document approve/reject with reasons, approve / request changes / reject, suspend / reinstate, audit log, category create/update.
- **Lead gate:** `LeadPolicy` returns a specific code: `worker_not_verified`, `worker_suspended`, `worker_not_registered` or `role_required`. `GET /worker/leads` returns `[]` for approved workers until matching arrives in Phase 4.
- **SMS** to the worker on approve, request changes or reject (fake adapter for now).
- **Shared pieces:** keyset pagination (`Shared::Pagination`), `Current` request context, `Admin::Audit.record!`.

**Frontend**
- **Worker app:** "Become a Workerly Pro", then a five-step onboarding: photo/experience/bio → skills → service area (city centre or GPS, radius slider) → ID and address documents → submit. Then a verification status page. Approved workers get an availability switch and the (empty) leads list. Routing follows verification state (`middleware/worker-profile.ts`).
- **Admin app:** nav (Dashboard, Workers, Audit log, shown by role), queue count on the dashboard, worker list with status tabs and search, worker detail with document previews, per-document verdicts, decision dialog, suspension, history.
- Worker-facing text in English, Hindi and Punjabi (**needs native-speaker review**). Admin screens are English only, with fallback.
- The phone header now wraps instead of overflowing.

## 2. API

| Endpoint | Who |
| --- | --- |
| `GET /categories`, `GET /categories/:slug`, `GET /cities` | public, cacheable 5 min |
| `POST /worker/registration` `{ name }` → profile + worker access token | logged-in consumer |
| `GET/PATCH /worker/profile` (multipart `profile[photo]`), `POST /worker/profile/submit_for_review`, `GET /worker/verification` | worker |
| `PUT /worker/skills`, `GET/POST/PATCH/DELETE /worker/service_areas`, `GET/POST/DELETE /worker/documents` | worker (documents only while editable) |
| `PATCH /worker/availability`, `GET /worker/leads`, `GET /worker/leads/:id` | approved worker |
| `GET /admin/workers`, `GET /admin/workers/:id` | admin, verifier, support |
| `POST /admin/workers/:id/verification` | admin, verifier |
| `POST /admin/workers/:id/suspend`, `…/reinstate` | admin, support |
| `GET /admin/audit_logs`, `GET/POST/PATCH /admin/categories` | admin (listing categories: any staff) |

```http
POST /api/v1/admin/workers/01a1…/verification
{ "decision": "changes_requested", "reason": "Address proof is blurry",
  "documents": [ { "id": "01a2…", "status": "approved" },
                 { "id": "01a3…", "status": "rejected", "reason": "Blurry, upload again" } ] }

GET /api/v1/worker/leads   (pending worker)
→ 403 { "error": { "code": "worker_not_verified", "message": "Your profile must be approved before you can see jobs.", … } }
```

Full schema: `backend/swagger/v1/openapi.yaml`. Frontend types: `frontend/app/types/api.d.ts`.

## 3. Commands
```bash
cd backend
bin/rails db:migrate db:seed          # new tables + reference data (seed is idempotent)
bin/rails "admin:grant[9876543210,verifier]"
```

## 4. Manual verification
1. Start everything (see README). Open http://localhost:3002 and log in with a new number. Enter a name and choose **Start registration**.
2. Work through the five steps. Try a `.txt` file renamed to `.jpg`: it is refused. Try *Use my location* (desktop browsers will ask for permission).
3. Choose **Submit for verification**. You land on "We're reviewing your profile". You can't edit documents any more.
4. On http://localhost:3003, log in as a verifier or admin. The dashboard shows the queue count; choose **Open queue** and open the worker.
5. Reject the address proof with a reason, then choose **Ask for changes**. The worker gets an SMS (`log/fake_sms.log`). The worker app goes back to onboarding with a banner showing your reason and the rejected document.
6. Re-upload as the worker and resubmit. As admin, approve both documents and then the worker.
7. The worker app shows the availability switch and "No leads yet". As admin, choose **Suspend** (reason required). The worker's next request gets a 403, and the app shows "Account suspended". Reinstate restores access.
8. Check **Audit log**: every decision, suspension and reinstatement appears with who, when and why.

## 5. Not done in Phase 2
- **Map picker:** the service-area centre is the city centre or GPS for now. The shared Leaflet map picker comes with customer addresses in Phase 3.
- **Bank/UPI payout details:** they depend on D3 (Razorpay Route linked accounts and KYC), so they are deferred to Phase 7.
- **EXIF stripping and image resizing:** need libvips on the servers. They come with customer photos in Phase 3. Worker documents are seen only by staff.
- **Admin category UI:** the API exists, but there is no screen yet (categories are seeded).
- **Database triggers** for the append-only tables: done in Phase 7 (see `docs/phase-7-payments.md`), kept in `schema.rb` rather than `structure.sql`.
- **Worker availability schedule** (days and hours): only the on/off switch exists for now.
