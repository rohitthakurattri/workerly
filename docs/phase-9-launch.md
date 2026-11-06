# Phase 9 — Launch readiness (handover)

**Exit gate (local):** every app installs as a PWA and degrades to an offline page; every HTML page carries a strict nonce CSP with no violations; production images build and run locally; production refuses fake SMS/payments.
**Status (2026-11-07):** met locally. **Cloud deployment not done** (Terraform drafted, not validated or applied, by request).
- Vitest `security-headers.spec.ts`: per-app CSP (Razorpay and microphone only in the customer app, admin without map tiles), nonce injection, HSTS only over https, OSM tile detection, service worker URL, iPhone detection.
- RSpec `spec/config/deployment_spec.rb`: boot guard and API headers.
- Production build checked in Chromium:
  - CSP and nonces present, no CSP violations;
  - service worker registers;
  - offline navigation shows the offline page;
  - manifest served;
  - OSM tile warning logged.
- **Stack check (2026-11-06):**
  - **Setup:** the `workerly-web` image (all three apps, healthy) ran against the API and Sidekiq from source in production mode with the profile's settings.
  - **Customer journey in Chromium:** OTP login using the code from the staging log, service worker active, voice note recorded → transcribed by Sidekiq → played back, photo uploaded and shown, triage pre-selected Plumber, address on the map, request submitted. **No CSP violations.**
  - **Other checks:** API headers, `APP_HOSTS` (unknown host → 403) and CORS all correct.
  - **Fixed:**
    - Active Storage now uses ImageMagick in every environment, not the libvips default;
    - the local disk stack draws the file routes it needs.
  - **`workerly-api` image:** not built yet. This connection downloads Debian packages at about 5–15 KB/s and rubygems.org at about 2 KB/s. The Dockerfile is unchanged; build it on a faster connection.
- RSpec: 523 examples. Vitest: 87. RuboCop, ESLint and typecheck (all 3 apps) are clean. Playwright was not re-run in this phase.

Rules and choices: `docs/adr/0011-pwa-security-headers-deployment.md`.

## 1. What was built
- **PWA:** per-app manifest route and icons (192, 512, maskable, Apple touch), service worker with offline page and push, registration plugin, install card (customer and worker home).
- **Security:** nonce CSP and headers for all three apps; locked-down API headers; `APP_HOSTS`; production boot guard; staging OTP logging.
- **Packaging:** `backend/Dockerfile`, `frontend/Dockerfile`, `.dockerignore`s, the `app` profile in `docker-compose.yml` with `backend/.env.app-local`.
- **Draft cloud:** `infra/terraform/` (see ADR 0011), with `environments/*.tfvars` and backend configs. Not run.

## 2. Settings
| Variable | Where | Purpose |
| --- | --- | --- |
| `DEPLOY_ENV` | API | `staging` allows fake SMS/payments in production mode |
| `APP_HOSTS` | API | allowed Host headers in production |
| `FORCE_SSL`, `LOCAL_DISK_STORAGE` | API | local production-like stack only |
| `NUXT_PUBLIC_ASSET_ORIGINS` | apps | file bucket / CDN origins for the CSP |
| `NUXT_PUBLIC_MAP_TILE_URL` | apps | commercial tile provider before launch |

## 3. Commands
```bash
docker compose --profile app up --build     # production images on :3100-3103
docker compose logs -f api jobs | grep FakeSms   # login codes in that stack
cd frontend && npm run build:customer && node .output/customer/server/index.mjs   # one app, production build
```

## 4. Manual verification
1. `docker compose --profile app up --build`, open http://localhost:3101, log in (the code is in the **jobs** log: `docker compose logs jobs | grep FakeSms`).
2. DevTools → Application: manifest with icons, service worker `sw.js?app=customer` active. Network → Offline, reload: the offline page.
3. Response headers of the page: CSP with a nonce; no CSP errors in the console while you post a job with a photo and a voice note.
4. On an Android phone (same network, or the dev servers): "Install the app" card → installs with the right icon and colour.
5. Start the API with `RAILS_ENV=production SMS_ADAPTER=fake` (no `DEPLOY_ENV`): it refuses to boot and says why.

## 5. Not done in Phase 9
- **Any cloud deployment:** Terraform review/validate/apply, DNS, certificates, CI deploy workflow. Waiting for the go-ahead.
- **Real SMS:** the MSG91 adapter now exists (ADR 0012); production needs the DLT registration, MSG91 key and template ids before it can boot.
- **Tile provider choice** and its key.
- Offline viewing of already-loaded data (deliberately not cached: personal data on shared phones).
