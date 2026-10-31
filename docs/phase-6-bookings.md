# Phase 6 — Bookings (handover)

**Exit gate:** every transition covered by policy + request specs; no path charges above approved amounts.
**Status (2026-10-31):** met locally.
- `spec/requests/bookings_gate_spec.rb`: every booking endpoint from all 14 statuses over HTTP (right answer every time), every wrong actor refused, and a 300-step random walk that checks after every step that the customer owes exactly what they approved.
- `e2e/bookings.spec.ts`: an inspection job end to end in two browsers — visit time, live chat, check-in, final price approved (₹199 fee → ₹1,200), extra charges refused then approved (₹1,350), done, rated 5★, problem reported and resolved by support.
- RSpec: 442 examples. Vitest: 65. Playwright: 10. RuboCop, Brakeman, bundler-audit, ESLint and typecheck (all 3 apps) are clean.

Rules and defaults: `docs/adr/0008-booking-lifecycle.md`.

## 1. What was built
**Backend:** booking state machine with history; scheduling, check-in, final price after inspection, extra charges, completion, cancellation (customer, worker, support); customer approvals with Idempotency-Key; amount owed from approvals only; request reopens for the other quotes when a booking ends before work; chat; reviews (worker rating updates); disputes and resolution; `BookingChannel`; notifications in English, Hindi and Punjabi; admin bookings list with *Needs attention* (unscheduled 24 h, missed visit, price waiting 24 h, disputed) and disputes queue; contact details and chat close 48 h after completion.

**Worker app:** job page with only the buttons that apply now (set/change visit time, I've arrived, send final price, start, ask for extra charges, mark done, cancel), amount owed, chat; job list shows status; **Reviews** page.
**Customer app:** booking page with progress, visit time, approve / say no to a waiting price, amount due, cancel (with the visit-fee warning after check-in), chat, rating, report a problem.
**Admin app:** **Bookings** (attention / all) with full history, approvals, chat and cancel; **Disputes** with resolve; dashboard card.

## 2. API
| Endpoint | Who |
| --- | --- |
| `POST /worker/bookings/:id/{schedule,check_in,final_quotation,start,change_orders,complete,cancel}` | the booking's worker, not suspended |
| `GET/POST /worker/bookings/:id/messages`, `GET /worker/reviews` | the booking's worker / any worker |
| `POST /customer/bookings/:id/approvals { revision_id, decision }` + `Idempotency-Key` | the booking's customer |
| `POST /customer/bookings/:id/{cancel,review,disputes}`, `GET/POST …/messages` | the booking's customer |
| `GET /admin/bookings`, `GET /admin/bookings/:id`, `POST /admin/bookings/:id/cancel { reason }` | admin, support |
| `GET /admin/disputes`, `POST /admin/disputes/:id/resolve { resolution }` | admin, support |
| `BookingChannel { id }` | the booking's customer or worker |

New error codes: `invalid_transition` (409, with `from` and `event`), `revision_not_pending`, `chat_closed`, `review_not_allowed`, `review_window_closed`, `already_reviewed`, `dispute_window_closed`, `dispute_already_open`, `dispute_not_open`.

## 3. Commands and settings
```bash
cd backend && bin/rails db:migrate        # booking lifecycle columns, messages, reviews, disputes
bin/rails runner script/e2e_seed.rb       # adds Job Plumber (9814000014)
# Restart the API and Sidekiq after migrating (new columns and job classes).
cd ../frontend && npm run gen:api
```
New ENV: `INSPECTION_FEE_ADJUSTED`, `BOOKING_CONTACT_HOURS`, `REVIEW_WINDOW_DAYS`, `DISPUTE_WINDOW_DAYS`.

## 4. Manual verification
1. Seed, then log in as *Job Plumber* (`9814000014`) on :3002 and as a customer on :3001. Post a job; the plumber sends an **Inspection visit** of ₹199; book it.
2. Worker: open the job, **Set visit time**. The customer's booking shows the time live.
3. Chat a message each way; it appears on the other screen without a reload.
4. Worker: **I've arrived** → **Send final price** (₹1,200). The worker still sees ₹199 owed. Customer: **Approve ₹1,200** → amount due ₹1,200 (the fee is taken off).
5. Worker: **Start work** → **Ask for extra charges** ₹300. **Mark job done** is gone while it waits. Customer: **Say no** → still ₹1,200. Ask again ₹150 → **Approve** → ₹1,350.
6. Worker: **Mark job done**. Customer: rate 5★; the worker sees it, and on **Reviews**.
7. Customer: **Report a problem**. Admin (:3003) → **Disputes** → **Resolve** with a note; the customer sees the resolution and the booking is back to *Done*.
8. On another booking, cancel as the customer before the visit: nothing owed, and the request shows the other quotes again.
9. Admin → **Bookings** → *Needs attention*; open one to see its history, approvals and chat; cancel it with a reason (logged in the audit log).

## 5. Not done in Phase 6
- **Payments, invoices, commission, payouts and refunds:** Phase 7 (needs D3 and D4). `paid` exists in the status list but nothing sets it yet; cash receipt arrives with payments.
- **Dispute messages** (a thread between support and both sides) and photos on disputes: only a description and a resolution for now.
- **Cancellation charges beyond the visit fee** (e.g. for a fixed-price job after travel): not charged; revisit with real data.
- Reassigning a booking to another worker, and reminders before the visit.
