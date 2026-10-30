# ADR 0003 — OTP login, sessions and role switching

**Status:** accepted 2026-10-30 (Phase 1)

## Model
- `user_sessions`: one per login per device, with a `scope` of **consumer** (customer + worker roles) or **staff** (admin, finance, support, verifier) and an absolute `expires_at` (consumer 180 days, staff 8 hours).
- `refresh_tokens`: rotate on every refresh, stored as HMAC digests, 30-day idle expiry capped at the session's expiry.
- Access token: HS256 JWT, 15 min, claims `sub` (user public id), `sid` (session), `scope`, `role` (the active role).

## Decisions
1. **The active role is a JWT claim, not stored state.** `POST /auth/switch_role` returns a new access token in the same session. Refresh takes an optional `role`, so the customer app and the worker app can share one consumer session and each ask for its own role.
2. **Separate refresh cookies per scope** (`wk_rt`, `wk_rt_staff`), HttpOnly, `SameSite=Lax`, path `/api/v1/auth`, host-only on the API domain. An admin login never replaces a customer login on the same browser. Cookie refreshes also require an allow-listed `Origin`.
3. **Every API call checks the session row.** Logout, reuse detection, suspension and role removal take effect immediately instead of after 15 min. Cost: one indexed query per request.
4. **Reuse detection with a 15-second grace window.** Replaying a rotated token revokes the whole session. Within 15 s of its rotation it is treated as a parallel refresh from another tab: it gets an access token, and no new cookie is set because the browser already has it.
5. **Staff login = OTP + TOTP.** OTP returns a 5-minute `mfa` token, never a session. TOTP secrets are provisioned only out of band (`bin/rails "admin:grant[...]"`), never through the API, so a stolen phone alone cannot enrol a new authenticator. Accepted TOTP steps cannot be replayed.
6. **OTP limits are enforced in the database** (3 per 15 min per phone, 30 s between sends, 5 attempts per code, 5 min TTL, codes stored as HMAC). Rack::Attack adds per-IP throttles in front; localhost is exempt in development only.
7. **Consumer logins create the user with the customer role. Staff logins never create users.**
