# Phase 3 — Customer requests (handover)

**Exit gate:** a customer creates a categorised request with photos in under 2 minutes on a mid-range Android phone.
**Status (2026-10-30):** met locally, in emulation.
- Playwright (`e2e/customer-request.spec.ts`) emulates a Pixel 5 with a 4× slower CPU, a 4G-like network (4 Mbps down, 1.5 Mbps up, 60 ms) and two 4000×3000 camera photos. The app's share of the full flow takes **9.1 s**. The test fails above 30 s, leaving 90 s for reading and typing.
- **Still to do by hand:** time a real person on a real mid-range Android phone (step 1 below). The test types instantly, so it can't measure the human part.
- RSpec: 245 examples. Vitest: 49 tests. Playwright: 7 tests. RuboCop, Brakeman, bundler-audit, ESLint and typecheck (all 3 targets) are clean.

Decisions, defaults and deviations from the plan: `docs/adr/0005-requests-and-ai-triage.md`.

## 1. What was built

**Backend**
- **Addresses:** GPS pin + house/street, sector/area, PIN code, landmark, label. The city is derived from the pin, with one default address. Addresses are soft-deleted.
- **Service requests:** draft → open → cancelled. Each request has a description, a category, answers to follow-up questions, urgency (`asap` / `today` / `this_week` / `flexible`), an optional time window, and an address snapshot taken at submit. A draft lists what it is still `missing`. Completeness is also enforced by a DB constraint.
- **Photos:** up to 6. Each is re-encoded to JPEG: rotation applied, EXIF and GPS removed, max 2048 px.
- **AI triage behind a flag:** `Ai::TriageRequest` → `Ai::Gateway` → adapter (`fake` or `openai`). The gateway applies the timeout, cache, budgets and circuit breaker and logs every call to `ai_analyses`. The prompt is versioned (`config/ai/prompts/triage.yml`). Contact details are redacted before sending, and model output is validated and clipped.
- **Policies:** `ServiceRequestPolicy` and `AddressPolicy`. A customer only ever sees their own requests and addresses: someone else's gives 404. Other roles get 403.

**Frontend (customer app)**
- Dashboard: "Post a job", unfinished drafts, active requests, past requests on demand.
- Five-step wizard (`/requests/new`): describe + photos → service (AI suggestion pre-selected, safety warning, optional follow-up questions) → address (saved, or new with a map pin from GPS) → when → check and send. Each step is saved as it's completed, so a reload or lost connection resumes the draft (`?id=…`).
- Request page with status, details and cancel. Address book (`/addresses`).
- Photos are shrunk on the phone before upload. Parallel uploads share one draft.
- Shared `SharedMapPicker` (Leaflet). The worker service-area step now uses it too, with the radius drawn on the map, as promised in Phase 2.
- All new text is in English, Hindi and Punjabi (**needs native-speaker review**).

## 2. API

| Endpoint | Notes |
| --- | --- |
| `GET/POST /customer/addresses`, `PATCH/DELETE /customer/addresses/:id` | `{ label, line1, line2, landmark, locality, pincode, lat, lng, is_default }` |
| `GET /customer/service_requests?filter[status]=active\|draft\|past&cursor=` | newest first, keyset pagination |
| `POST /customer/service_requests` | creates a draft |
| `GET/PATCH/DELETE /customer/service_requests/:id` | PATCH and DELETE work on drafts only (`403 request_locked` otherwise) |
| `POST /customer/service_requests/:id/submit` | `422 request_incomplete { missing }`, `too_many_active_requests` |
| `POST /customer/service_requests/:id/cancel` `{ reason? }` | open/quoting only |
| `POST /customer/service_requests/:id/attachments` (multipart `file`), `DELETE …/attachments/:aid` | drafts only |
| `POST /customer/service_requests/:id/triage` | `503 ai_unavailable` → pick manually; `429 ai_budget_exceeded` |

```http
POST /api/v1/customer/service_requests/01a1…/triage
→ 200 { "data": { "id": "01a2…", "suggested_category": { "slug": "plumber", "name": "Plumber", "icon": "wrench" },
                  "confidence": 0.9, "needs_confirmation": false, "alternatives": [],
                  "summary": "Plumber job: Kitchen tap is leaking…", "questions": ["Where is the problem…?", "Is water leaking right now?"],
                  "urgency": "flexible", "safety_flag": false } }

PATCH /api/v1/customer/service_requests/01a1…
{ "category": "plumber", "address": "01a3…", "urgency": "today",
  "answers": [{ "question": "Is water leaking right now?", "answer": "Yes, slowly" }] }

POST /api/v1/customer/service_requests/01a1…/submit
→ 200 { "data": { "status": "open", "submitted_at": "…", "expires_at": "…+24h", "address": { "locality": "Sector 70", … }, … } }
```

Full schema: `backend/swagger/v1/openapi.yaml`.

## 3. Commands and settings
```bash
cd backend && bin/rails db:migrate        # addresses, service_requests, request_attachments, ai_analyses
# Requires ImageMagick on every machine that runs the API (photo processing).
cd frontend && npm install                # adds leaflet
```
New settings (see `backend/.env.example`): `AI_TRIAGE_ENABLED`, `AI_ADAPTER` (`fake` | `openai`), `OPENAI_API_KEY`, `AI_TRIAGE_MODEL`, `AI_USER_DAILY_LIMIT`, `AI_GLOBAL_DAILY_LIMIT`, `REQUEST_TTL_HOURS`. Frontend: `NUXT_PUBLIC_MAP_TILE_URL` and `NUXT_PUBLIC_MAP_ATTRIBUTION` (needed for production).

## 4. Manual verification
1. **Gate check on a real phone:** open the customer app on a mid-range Android phone on mobile data (e.g. via your machine's LAN IP). Log in, then time from **Post a job** to the "Waiting for quotes" page, including one camera photo. It should take under 2 minutes.
2. Type "pankha nahi chal raha, switch se spark aa raha hai" → the service suggested is Electrician, and the red safety warning appears. Type "something is broken" → nothing is pre-selected and you're asked to choose.
3. Set `AI_TRIAGE_ENABLED=false` and restart the API. The service step goes straight to the picker and the flow still completes.
4. Upload a phone photo that has location data, then download it from the request page. `exiftool` shows no GPS or camera tags.
5. Drag the pin to Delhi when adding an address → "Workerly doesn't serve this location yet".
6. Submit a request, then edit that address in **Addresses**. The request still shows the old address.
7. Cancel an open request → it moves to past requests and the Cancel button disappears.
8. Worker app (`:3002`), onboarding step 3: the map shows the radius circle, and tapping moves the centre.

## 5. Not done in Phase 3
- **Voice notes and transcription:** Phase 8, as planned. `request_attachments.kind` already allows `audio` and `video`.
- **Request expiry job and notifying workers:** Phase 4 (matching). Requests stay `open` past `expires_at` until then.
- **Stale-draft cleanup:** needs a scheduler (Phase 4 adds one).
- **Admin view of requests:** Phase 4, with "requests with no quotes".
- **Reverse geocoding** (filling in the locality from the pin): customers type it for now.
- **Category questions table** (`category_questions`): follow-up questions come only from AI. With AI off, there are none.
- **Choosing a real AI model, a budget and prices** (`config/ai/pricing.yml`); production keeps the flag off until then.
