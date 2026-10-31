# ADR 0006 — Matching, leads and notifications

**Status:** accepted 2026-10-30 (Phase 4). Decision D5 was not answered, so the plan's numbers are used as settings, all changeable without a deploy of code.

## Defaults (D5, pending)
| Setting | Default | ENV |
| --- | --- | --- |
| Workers invited per request | 10 | `MATCH_FANOUT` |
| Quotes accepted per request (used in Phase 5) | 5 | `MAX_QUOTES_PER_REQUEST` |
| Request open for quotes | 24 h | `REQUEST_TTL_HOURS` |
| SMS when push didn't reach the worker | on | `LEAD_SMS_FALLBACK` |

## Who is eligible (`Matching::FindCandidates`, one PostGIS query)
Approved, not suspended, switched to available, account active, has the request's category as a skill, and **at least one service area whose circle contains the request's location** (`ST_DWithin(center, location, radius_m)`). Never the customer themselves. Distance is measured to the nearest qualifying area centre.

## Ranking (`Matching::Rank`; the plan's open "ranking" question, answered with defaults)
Score 0–1 = 0.40 × closeness (3 km scores half of 0 km) + 0.25 × rating (Bayesian: new workers count as 5 reviews of 4.0) + 0.20 × fair share (fewer leads in the last 7 days scores higher, so new workers aren't starved) + 0.15 × responsiveness (share of the last 30 days' leads opened within 15 minutes; 0.5 until 5 leads). Ties go to the closer worker. The score and rank are stored on each invitation and shown to support staff.

## Flow
`Requests::Submit` → `MatchRequestJob` (critical queue) → `InviteWorkers` (row lock + `matched_at` + unique index: runs once) → per worker `NotifyWorkerJob` → live via Action Cable, web push to the worker's browsers, SMS only if no push was delivered. The customer gets an in-app notification with the count. Cancel and expiry broadcast `lead.closed`.

Matching runs once, at submit. Workers who become available later don't get existing requests; re-matching (and widening the radius when nobody was found) is left for when real numbers show it's needed. Support sees such requests under **Needs attention**.

## What workers see before booking
Category, the customer's description and answers with phone numbers and e-mails masked, the AI summary, photos, urgency and time window, locality, city, and a **distance band** (under 1 km, 1–3, 3–5, 5–10, over 10) — never the exact distance, address or phone, so a home can't be triangulated.

## Realtime
Action Cable at `/cable`, Redis DB 2. Browsers can't send headers on WebSockets, so the app gets a **one-time ticket** (`POST /cable_tickets`, JWT, 60 s, single use via the cache) and connects with `?ticket=`. The connection is checked against the live session like any API call. Allowed origins = `APP_ORIGINS`. The app's small client fetches a new ticket on each reconnect and refetches leads after resubscribing, so nothing is lost while offline.

## Web push
VAPID keys (`bin/rails webpush:keys`) in `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY`. Without them push is off and SMS covers new leads. Subscriptions are per app (customer/worker); a browser endpoint moves to whoever signs in on it, and logout removes it. Keys are encrypted at rest. **Endpoints must be a known browser push service** (FCM, Mozilla, Apple, Windows), because the server POSTs to them (SSRF guard). A push-only service worker (`public/push-sw.js`) shows the notification; the Phase 9 PWA worker takes it over. iPhones get web push only for installed PWAs, hence the SMS fallback.

## Scheduling
sidekiq-cron (`config/schedule.yml`): expire requests every 5 minutes; delete drafts untouched for 30 days at 03:30 UTC.
