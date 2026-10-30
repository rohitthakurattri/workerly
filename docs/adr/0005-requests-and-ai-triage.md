# ADR 0005 — Customer requests and AI triage

**Status:** accepted 2026-10-30 (Phase 3). These choices follow the plan; deviations from it are marked.

## Requests
- **Lifecycle:** `draft → open` in Phase 3; `quoting`, `booked`, `fulfilled` and `expired` are in the CHECK constraint already and get their transitions in Phases 4–6. Customers can cancel `open` and `quoting` requests.
- **Completeness is a DB rule:** anything past `draft` must have a category, address, city, location, address snapshot, `submitted_at` and `expires_at` (`service_requests_submitted_complete_check`).
- **Address snapshot (deviation):** on submit, the request copies the address (`address_snapshot` jsonb + `location` + `city_id`). Editing or deleting an address never moves a live request. The plan's `customer_profiles.default_address_id` was replaced by `addresses.is_default` with a partial unique index (one default per user).
- **City from the pin:** an address's city is the nearest launched city whose service radius covers the pin. Pins outside every launched city are refused.
- **Limits:** 10 addresses, 5 drafts, 5 active requests, 6 photos per request. `expires_at` = submit + `REQUEST_TTL_HOURS` (24, pending decision D5). The expiry job comes with matching in Phase 4.
- **What workers will see:** `address_snapshot.locality` only, until booking (Phase 4–6 serializers).

## Photos
- Uploaded through the API (multipart), not direct-to-S3 as the plan suggested, because every image is re-encoded on the server: auto-rotate, **strip EXIF (including GPS)**, max 2048 px, JPEG q82. Type is sniffed from the bytes.
- The customer app also shrinks photos to 1600 px before upload. This is what keeps a request fast on mobile data (a 4 MB camera photo becomes a few hundred KB).
- **ImageMagick, not libvips:** the servers need ImageMagick (`image_processing` with MiniMagick). HEIC needs ImageMagick built with libheif; without it, HEIC uploads fail with "Try a JPEG" (most Android cameras save JPEG).

## AI triage
- **Flag:** `AI_TRIAGE_ENABLED` (default on in development/test, off in production). When it's off or failing, the endpoint returns `503 ai_unavailable` and the app shows the category picker. Request creation never depends on AI.
- **Endpoint (deviation):** `POST /customer/service_requests/:id/triage` instead of `/customer/ai/triage`, so the analysis belongs to the draft and its photos.
- **Adapters:** `fake` (keyword rules in English/Hindi/Punjabi; offline and deterministic, the default) and `openai` (Chat Completions with a strict JSON schema; images sent inline as base64, never as bucket links). `AI_TRIAGE_MODEL` must be set for `openai`; the model was not chosen in this phase.
- **Gateway (`Ai::Gateway`):** 8 s timeout; cache by input hash (prompt version + model + text + image checksums) for 7 days; per-user budget (`AI_USER_DAILY_LIMIT`, 20/day; then `429 ai_budget_exceeded`); global budget (`AI_GLOBAL_DAILY_LIMIT`, 5000/day); circuit breaker (5 failures within 1 minute stops calls for a minute). Every call, failure and cache hit is an append-only `ai_analyses` row. Cost is filled in once prices are added to `config/ai/pricing.yml`.
- **Guardrails:** phone numbers and e-mails are removed from the text before sending; names and addresses are never sent. Unknown slugs are dropped and all output is clipped. A suggestion with confidence below 0.6 is not pre-selected. The customer always confirms the category. `category_source` (`ai` or `customer`) is recorded to build the Phase 8 accuracy test set.
- **Prompt:** `config/ai/prompts/triage.yml`, versioned; the version is stored on every analysis.

## Maps
- Leaflet 1.9.4 with OpenStreetMap tiles in development. **OSM's tile servers are not for production traffic:** set `NUXT_PUBLIC_MAP_TILE_URL` and `NUXT_PUBLIC_MAP_ATTRIBUTION` to a provider before launch, and allow it in the CSP (Phase 9).
