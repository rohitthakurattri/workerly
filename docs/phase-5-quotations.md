# Phase 5 — Quotations (handover)

**Exit gate:** two simultaneous accepts produce exactly one booking.
**Status (2026-10-31):** met locally.
- `spec/requests/quotations_gate_spec.rb` races real threads with their own database connections: two different quotes accepted at the same instant (10 rounds), the same quote accepted twice, and the same race with the row lock switched off so only the unique index protects it. Every run ends with exactly one booking, one approval, and the loser gets `409 request_already_booked`.
- In the browser (`e2e/quotations.spec.ts`), two plumbers quote, the customer sees both arrive live and compares them, then two tabs tap **Book** on different quotes at the same moment: one gets `201` and the booking page, the other `409` and the quote shown as "Not chosen".
- RSpec: 375 examples. Vitest: 61 tests. Playwright: 9 tests. RuboCop, Brakeman, bundler-audit, ESLint and typecheck (all 3 apps) are clean.

Design and rules: `docs/adr/0007-quotations-bookings-ledger.md`. **D5 still open** (10 / 5 / 24 h as settings). **D4 not needed yet.**

## 1. What was built

**Backend**
- **Quotes:** fixed price (itemised: labour, parts with brand/condition/warranty, travel, other) or inspection visit (a fee; the final price follows in Phase 6). Server-side pricing, per-category tax (0 until GST is settled), immutable versions, change and withdraw until accepted, at most 5 live quotes per request, one per worker, only invited workers.
- **Accepting:** version check, row locks, unique indexes, `Idempotency-Key`, one transaction creating the booking, the consent record and the history row; other quotes declined; address and phone revealed to the winner.
- **Bookings (read-only for now):** customer and worker views. Scheduling, check-in and the rest are Phase 6.
- **Ledger schema** and `Ledger::Post` (balanced, idempotent, append-only), ready for Phase 7.
- **Notifications:** customer — new and updated quotes (in-app + push). Worker — accepted (push, SMS fallback), declined or not chosen (in-app + push). English, Hindi, Punjabi.
- **Realtime:** `RequestChannel` for the customer; `quote.status` events on `WorkerLeadsChannel`.
- **Jobs:** expiry also expires open quotes and quotes past `valid_until`; daily purge of idempotency keys.
- **Admin:** request detail shows every quote with its full price history and the booking; the list shows the quote count.

**Frontend**
- **Worker app:** **Send quote** on a lead opens the quote form (fixed or inspection, lines with live totals, estimate, note). After sending, the lead shows *Your quote* with **Change quote** and **Withdraw quote**. A **My quotes** page lists quotes by status. **Jobs you won** appears on the home page (live, with a toast) and opens the job with the customer's name, a call button, the address and a Maps link.
- **Customer app:** quotes appear live on the request page, sorted by price, rating or distance, as cards or a side-by-side **Compare** table. Each quote opens to its breakdown, price history and **Book this worker** / **Decline**. Booking shows the worker's phone and the agreed price.
- **Admin app:** quotes and booking on the request page; a quotes column on the list.

## 2. API
| Endpoint | Who |
| --- | --- |
| `POST /worker/leads/:lead_id/quotations` | approved, unsuspended, invited worker |
| `GET /worker/quotations`, `GET /worker/quotations/:id` | worker; own quotes only |
| `PATCH /worker/quotations/:id` (new version), `POST /worker/quotations/:id/withdraw` | approved, unsuspended worker; own submitted quote |
| `GET /worker/bookings`, `GET /worker/bookings/:id` | unsuspended worker; own jobs only |
| `GET /customer/service_requests/:id/quotations`, `GET /customer/quotations/:id` | customer; own requests only (others: 404) |
| `POST /customer/quotations/:id/accept` `{ version }` + `Idempotency-Key` | customer; own request |
| `POST /customer/quotations/:id/decline` `{ reason? }` | customer; own request |
| `GET /customer/bookings`, `GET /customer/bookings/:id` | customer; own bookings |
| `RequestChannel` `{ id }` over `/cable` | customer; own submitted request |

```http
POST /api/v1/worker/leads/0199…/quotations
{ "kind": "fixed", "estimated_minutes": 60, "notes": "Includes cleaning the trap.",
  "items": [ { "type": "labour", "description": "Clear the blockage", "quantity": 1, "unit": "job", "unit_price_minor": 50000 },
             { "type": "material", "description": "Sink trap", "brand": "Jaquar", "quantity": 1, "unit": "item",
               "unit_price_minor": 45000, "condition": "new", "warranty_days": 90 } ] }
→ 201 { "data": { "id": "0199…", "status": "submitted", "current_version": 1,
                  "revision": { "total": { "minor": 95000, "currency": "INR" }, "items": [ … ] }, … } }

POST /api/v1/customer/quotations/0199…/accept
Idempotency-Key: 6b1e2f0c-…
{ "version": 1 }
→ 201 { "data": { "id": "0199…", "status": "confirmed", "kind": "fixed",
                  "approved_total": { "minor": 95000, "currency": "INR" }, "worker": { "name": "…", "phone": "+91…" }, … } }
→ 409 { "error": { "code": "quotation_changed", "details": { "current_version": 2 }, … } }
→ 409 { "error": { "code": "request_already_booked", … } }
```
Error codes: `already_quoted`, `quote_limit_reached`, `request_closed`, `lead_declined`, `inspection_not_allowed`, `quotation_not_editable`, `too_many_revisions`, `quotation_not_acceptable`, `quotation_expired`, `quotation_changed`, `request_already_booked`, `worker_unavailable`, `idempotency_key_required` / `_invalid` / `_reused` / `_in_progress`, and `validation_failed` with `field_errors` keyed like `items.0.unit_price_minor`.

## 3. Commands and settings
```bash
cd backend && bin/rails db:migrate            # quotations, revisions, items, bookings, approvals, ledger, idempotency keys
bin/rails runner script/e2e_seed.rb           # adds Second Plumber (9814000013) for two competing quotes
# Restart Sidekiq after deploys: it loads config/schedule.yml (new: purge_idempotency_keys) on start.
cd ../frontend && npm run gen:api             # regenerated types from swagger/v1/openapi.yaml
```
No new ENV. `MAX_QUOTES_PER_REQUEST` (default 5) is now in use. A category's tax rate is set by an admin with `PATCH /admin/categories/:slug { category: { tax_rate_bps: 1800 } }` (18 %).

## 4. Manual verification
1. Run the seed (above). Log in on http://localhost:3002 as *Near Plumber* (`9814000011`) and, in another browser, as *Second Plumber* (`9814000013`).
2. As a customer on http://localhost:3001, post a plumbing job in Sector 70 and stay on the request page ("No quotes yet").
3. Near Plumber: open the job → **Send quote** → two lines (₹500 labour, ₹450 part with 90 days warranty). The total reads ₹950 as you type. Send. The customer's page shows the quote within a second, without a reload.
4. Second Plumber: **Inspection visit**, fee ₹199. The customer now sees two quotes, ₹199 first. Switch **Sort by** to Rating or Distance, and the view to **Compare**.
5. Near Plumber: **Change quote** to ₹400 labour. The customer's card updates to ₹850 and shows *Updated*. On the quote page, *Price changes* lists v1 ₹950 → v2 ₹850.
6. Stale price: as the customer, open Near Plumber's quote and tap **Book this worker** but don't confirm yet. As the worker, change the price. Now confirm: "The worker just changed this quote", and the page shows the new price. (With the dialog closed, the page simply updates to the new price by itself.)
7. Two-tab race: open each quote in its own tab, tap **Book this worker** in both, then confirm both quickly. One tab shows *Booking confirmed* with a call button; the other says the request is already booked and its quote reads *Not chosen*.
8. The winning worker's home shows the job (and a toast if it was open). The job page has the customer's name, phone, *House 77* and a Maps link. The other worker's lead is gone and **My quotes** shows *Not chosen*. With no push set up, `log/fake_sms.log` has the "your quote was accepted" SMS.
9. Try to quote a sixth time on a job with 5 quotes (or set `MAX_QUOTES_PER_REQUEST=1`): the lead says it's full and the API answers `quote_limit_reached`.
10. Admin (http://localhost:3003) → **Requests** → the request: every quote with its version history, and the booking.

## 5. Not done in Phase 5
- **Booking actions** (schedule, check-in, final quote after inspection, change orders, complete, cancel), chat, reviews and disputes: Phase 6. Cancelling a booked request isn't possible yet.
- **Inspection-fee policy:** whether the visit fee is deducted from the repair bill is still an open requirement; nothing assumes either way yet.
- **Payments, commission (D4), invoices and ledger postings:** Phase 7. Tax rates are 0 until the CA's GST opinion.
- **Hiding contact details again 48 h after completion:** Phase 6, when bookings complete.
- **Notification centre UI** (still API-only) and **re-matching** (from Phase 4).
