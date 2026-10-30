# Phase 1 — Foundation (handover)

**Exit gate:** a user can log in by OTP on all three apps and switch role, and CI has a request spec for every auth path.
**Status (2026-10-30):** met locally. 90 RSpec examples, 30 Vitest tests and 5 Playwright browser tests pass. RuboCop, Brakeman, bundler-audit, ESLint and `nuxt typecheck` (all 3 targets) are clean. The GitHub Actions workflow is written but has not run yet: there is no remote.

## 1. What was built

**Backend (Identity module)**
- Mobile OTP login (India-only numbers, normalised to E.164). Codes are 6 digits, stored as HMAC, expire after 5 min and allow 5 attempts. The DB enforces 3 sends per 15 min per phone and 30 s between sends. SMS goes through a Sidekiq job and an adapter; only `fake` exists until D6 is decided.
- Users can hold several roles (`customer`, `worker`, `admin`, `finance`, `support`, `verifier`). A first consumer login creates the user with the `customer` role.
- Sessions: 15-min JWT access token plus a rotating, hashed refresh token in an HttpOnly cookie. Replaying an old token revokes the whole session (with a 15 s grace for parallel tabs). Every request checks the session, so logout and suspension take effect immediately. Design: `docs/adr/0003-auth-sessions.md`.
- Staff login = OTP + TOTP, with an 8 h session cap. TOTP is provisioned only via `bin/rails "admin:grant[phone,role]"`.
- One error shape everywhere: `{ error: { code, message, details, request_id } }`. JSON 404 for unknown routes. `Cache-Control: no-store` on API responses.
- Pundit with default-deny `ApplicationPolicy`. Policies receive user + session + active role.
- Rack::Attack throttles, CORS restricted to `APP_ORIGINS`, Lograge JSON in production. OTP codes, phone numbers and tokens are filtered from logs and job arguments.
- rswag request specs generate `backend/swagger/v1/openapi.yaml`, and the frontend generates `app/types/api.d.ts` from it.

**Frontend (Nuxt 4, three targets)**
- `APP_TARGET` selects routes, layout, theme and icon. Ports in development: customer 3001, worker 3002, admin 3003.
- Login flow: phone → code (supports SMS autofill on Android via WebOTP) → TOTP on admin only.
- The access token is kept in memory only. Expired tokens are refreshed once and the request retried, and parallel requests share a single refresh.
- Role switching: customer ↔ worker moves between apps, and the shared refresh cookie means no second login. Staff roles switch in place.
- Design tokens (Tailwind v4 `@theme`, re-tinted per app) and the UI kit: Button, Input, Select, Modal, ConfirmDialog, Card, Table, Badge, Toaster, Skeleton, EmptyState.
- English, Hindi and Punjabi for every Phase 1 string. **The Hindi and Punjabi copy needs review by a native speaker.**

## 2. API examples

```http
POST /api/v1/auth/otp
{ "phone": "98765 43210" }
→ 202 { "data": { "phone": "+91******3210", "expires_in": 300, "resend_after": 30 } }

POST /api/v1/auth/otp/verify
{ "phone": "9876543210", "code": "123456", "scope": "consumer", "role": "worker" }
→ 201 Set-Cookie: wk_rt=…; path=/api/v1/auth; HttpOnly; SameSite=Lax
  { "data": { "access_token": "eyJ…", "token_type": "Bearer", "expires_in": 900,
              "active_role": "worker", "session": { "scope": "consumer", "expires_at": "…" },
              "user": { "id": "01a1…", "phone": "+919876543210", "roles": ["customer","worker"], … } } }

POST /api/v1/auth/otp/verify      { …, "scope": "staff" }
→ 200 { "data": { "mfa_required": true, "mfa_token": "eyJ…", "expires_in": 300 } }
POST /api/v1/auth/totp            { "mfa_token": "eyJ…", "code": "654321" }
→ 201 (session, cookie wk_rt_staff)

POST /api/v1/auth/refresh          (Origin must be a Workerly app) { "scope": "consumer", "role": "customer" }
POST /api/v1/auth/switch_role      Authorization: Bearer …  { "role": "worker" }
DELETE /api/v1/auth/session        Authorization: Bearer …  → 204
GET /api/v1/me                     PATCH /api/v1/me { "user": { "name": "…", "locale": "pa" } }

Error example → 422
{ "error": { "code": "otp_incorrect", "message": "That code is incorrect.",
             "details": { "attempts_left": 3 }, "request_id": "8f2c…" } }
```

The full spec is in `backend/swagger/v1/openapi.yaml`, with a browsable UI at `http://localhost:3000/api-docs` in development.

## 3. Commands

See the root `README.md` for setup. Useful extras:

```bash
bin/rails "admin:grant[9876543210,admin]"   # staff role + TOTP QR URI (RESET_TOTP=1 to rotate)
bin/rails "admin:revoke[9876543210,admin]"
bundle exec rake rswag:specs:swaggerize      # regenerate OpenAPI after changing request specs
npm run gen:api                              # regenerate frontend API types
npm run build:all                            # .output/{customer,worker,admin}
```

## 4. Manual verification

1. `tail -f backend/log/fake_sms.log`, then open http://localhost:3001 → *Get started* → enter any 10-digit number starting with 6–9 → enter the code from the log. You land on the customer home screen and can save your name.
2. Click *Send code* twice quickly. The second attempt shows "Please wait…" (30 s rule). Enter a wrong code 5 times: the next attempt says the code expired.
3. `bin/rails runner 'User.find_by(phone_e164: "+91<your number>").grant_role!(:worker)'`, then reload. A *Customer | Worker* switch appears. Click *Worker*: http://localhost:3002 opens already logged in, showing "No leads yet".
4. Open http://localhost:3002 in a private window with a new number. You see "Become a Workerly Pro".
5. Run `bin/rails "admin:grant[<number>,admin]"` and scan the URI into an authenticator app (or paste it into one that accepts URIs). Log in at http://localhost:3003 with OTP and then TOTP. Logging in on :3003 doesn't log you out of :3001.
6. Click *Log out*, then reload: you see the public landing page, not your account. DevTools → Application → Cookies shows no `wk_rt`.
7. In DevTools, the access token appears only in request headers. Nothing is in localStorage or sessionStorage.

## 5. Not done in Phase 1 (by design)

- Real SMS provider (D6) and DLT templates. The OTP text in `lib/adapters/sms.rb` must match the registered template exactly.
- PWA manifests and service worker (Phase 9). Push subscriptions (`device_subscriptions`) come with Notifications.
- `customer_profiles` and `worker_profiles` arrive in Phase 2 with onboarding. `POST /worker/registration` will grant the worker role.
- Action Cable is configured (Redis DB 2) but has no channels until Phase 4.
- Production secrets come from ENV; boot fails if `JWT_SECRET`, `OTP_PEPPER`, `TOKEN_PEPPER` or the AR encryption keys are missing.
