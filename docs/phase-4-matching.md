# Phase 4 — Matching (handover)

**Exit gate:** a request in Mohali reaches the right 10 workers within 30 s; out-of-area workers never see it.
**Status (2026-10-30):** met locally.
- `spec/requests/matching_gate_spec.rb` runs the real chain (submit → match → notify → leads API) with 14 nearby plumbers and three who must be excluded (out of range, wrong trade, off duty). Exactly the 10 best are invited and notified, and nobody else can list or open the lead.
- In the browser (`e2e/matching.spec.ts`), a customer posts a job and the nearby plumber's open app shows it **0.1–0.2 s** later, without a reload. The far plumber never sees it, even after a reload or by opening its link.
- RSpec: 308 examples. Vitest: 53 tests. Playwright: 8 tests. RuboCop, Brakeman, bundler-audit, ESLint and typecheck (all 3 apps) are clean.

Design, defaults and rules: `docs/adr/0006-matching-and-notifications.md`. **D5 is still open**; the plan's numbers (10 workers, 5 quotes, 24 h) are settings.

## 1. What was built

**Backend**
- **Matching:** PostGIS eligibility query, ranking (closeness, rating, fair share, responsiveness), `request_invitations` with rank, score and distance. Runs once per request, in a critical-queue job after submit.
- **Leads API:** live leads (invited, not declined, still open), lead detail (records the first view), decline with a reason. Contact details typed into free text are masked, and distance is shown as a band only.
- **Notifications:** `notifications` (in-app record) and `device_subscriptions` (web push, VAPID, encrypted keys, push-service hosts only). Push goes first; SMS goes out only if no device took the push. Text in English, Hindi and Punjabi.
- **Realtime:** Action Cable with one-time tickets and `WorkerLeadsChannel` (`lead.new`, `lead.closed`).
- **Scheduled jobs (sidekiq-cron):** expire requests every 5 minutes; delete stale drafts daily.
- **Admin:** requests list (*Needs attention* = open with nobody invited, or no quotes after 30 minutes), and request detail with every invitation (rank, score, distance, how they were notified, viewed or declined). For admin and support.

**Frontend**
- **Worker app:** the job list updates live (new jobs appear with a toast; cancelled or expired ones disappear). Lead page with photos, the customer's answers, the area and distance band, and "Not interested". The **Job alerts** switch turns on browser push for this phone. Logout turns off alerts and closes the socket. "Send quote" is visible but disabled until Phase 5.
- **Customer app:** the request page shows "Finding workers…", then "Sent to N nearby workers", or tells them nobody is free yet.
- **Admin app:** a **Requests** tab and a *Requests needing attention* card on the dashboard.

## 2. API
| Endpoint | Who |
| --- | --- |
| `GET /worker/leads`, `GET /worker/leads/:id`, `POST /worker/leads/:id/decline` | approved, unsuspended worker; only their own invitations |
| `POST /cable_tickets` → `wss …/cable?ticket=…` | any signed-in user |
| `GET /devices/push_config`, `POST /devices`, `DELETE /devices` | customer or worker session |
| `GET /notifications`, `POST /notifications/:id/read`, `POST /notifications/read_all` | any signed-in user |
| `GET /admin/service_requests?filter[status]=…&filter[attention]=true`, `GET /admin/service_requests/:id` | admin, support |

```http
GET /api/v1/worker/leads
→ 200 { "data": [ { "id": "01a1…", "status": "new", "category": { "slug": "plumber", "name": "Plumber" },
                     "description": "Tap leaking. Call me on [phone removed]", "locality": "Sector 70", "city": "mohali",
                     "distance_band": "under_1km", "urgency": "today", "photos": [ … ], "expires_at": "…" } ], "meta": { "next_cursor": null } }

WebSocket message on WorkerLeadsChannel:
{ "type": "lead.new", "lead": { …same shape… } }      { "type": "lead.closed", "id": "01a1…", "status": "cancelled" }
```

## 3. Commands and settings
```bash
cd backend && bundle install && bin/rails db:migrate   # request_invitations, notifications, device_subscriptions
bin/rails webpush:keys                                 # VAPID pair for .env (already added to your local backend/.env)
# Restart Sidekiq after deploys: it loads config/schedule.yml on start.
```
New ENV: `MATCH_FANOUT`, `MAX_QUOTES_PER_REQUEST`, `LEAD_SMS_FALLBACK`, `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT`, `ACTION_CABLE_URL` (public `wss://` URL in production).

## 4. Manual verification
1. Run `bin/rails runner script/e2e_seed.rb` once. It creates *Near Plumber* (`9814000011`, covers Mohali Sector 70) and *Far Plumber* (`9814000012`, a 2 km circle in Chandigarh Sector 17).
2. Log in as Near Plumber on http://localhost:3002 and leave the page open. In another browser, post a plumbing job in Sector 70 on http://localhost:3001. The job appears for the plumber within a second, with a toast, without a reload.
3. Log in as Far Plumber: no new job. Paste the job's link from step 2: "This job is no longer available".
4. Open the job as Near Plumber: you see the area and distance band, never the house number or phone. If the description contained a phone number, it shows `[phone removed]`.
5. As the customer, cancel the job. It disappears from the plumber's open list.
6. Turn on **Job alerts** in the worker app (allow notifications), then close the tab and post another job. A browser notification arrives; tapping it opens the job. Without alerts, `log/fake_sms.log` shows the SMS instead.
7. Admin (http://localhost:3003, admin or support role) → **Requests**: post a job for a trade nobody covers (e.g. Carpenter). It appears under *Needs attention* with 0 invited. Open any request to see who was invited, their rank, score and distance, and whether they viewed or declined it.
8. Set the plumber to unavailable and post a job: they aren't invited.

## 5. Not done in Phase 4
- **Re-matching:** requests aren't offered later to workers who come online, and the radius doesn't widen when nobody matched. Support handles these via *Needs attention*. Revisit with real data.
- **Notification centre UI:** the API exists (list, unread count, mark read); a bell and list in the apps come later.
- **Customer live updates:** quotes arriving live is Phase 5 (`RequestChannel`) — done, see `phase-5-quotations.md`.
- **Suspending a worker doesn't close their open socket;** the channel and leads API refuse them on the next subscribe or fetch.
- **Full PWA service worker:** Phase 9. iPhone web push only works for installed PWAs, so SMS stays the safety net.
