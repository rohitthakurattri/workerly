# Phase 7 — Payments (handover)

**Exit gate:** no path marks money paid without a verified gateway event or a confirmed cash amount; the ledger balances after every money event; nobody can charge or refund more than is owed.
**Status (2026-11-06):** met locally.
- `spec/services/payments/money_flow_spec.rb` + `spec/requests/payments_gate_spec.rb`: online, cash, partial and full refunds, payouts with cash offset, replayed and forged webhooks, amount mismatches; the ledger is checked balanced after each step.
- `e2e/payments.spec.ts`: a ₹1,000 job paid online through the fake checkout → invoice `WK/2026-27/…` → worker sees ₹1,000 − ₹100 commission → finance refunds ₹200 → records a payout → reconciliation shows the ledger balanced; and a job paid in cash, confirmed by the worker, visible on both screens.
- RSpec: 488 examples. Vitest: 76. Playwright: `payments.spec.ts` 2/2 (the earlier specs were not re-run this phase). RuboCop, Brakeman, bundler-audit, ESLint and typecheck (all 3 apps) are clean.

Rules and defaults: `docs/adr/0009-payments-ledger-payouts.md`.

## 1. What was built
**Backend:** payments (online via Razorpay or fake adapter, cash), signed webhook handling with stored events, commission rules with a per-booking snapshot, the payment split (commission on labour, tax pass-through, worker share), ledger postings for every money event, invoices with gapless per-year numbering, refunds (partial/full), worker balances and payouts, daily reconciliation; booking API now returns `paid`, `outstanding`, `payable`, `payments`, `invoice_number`; dev-only fake gateway endpoint.

**Customer app:** **Pay** card on a finished booking (Razorpay checkout loaded on demand; in development a test checkout with *Succeed* / *Fail*), waits for the webhook before saying paid, payment history with refunds, **invoice** page (print / save as PDF).
**Worker app:** job page shows what's left to collect and **Customer paid me in cash** (confirms the exact amount), payment history and invoice; **Earnings** page — held for you, commission owed on cash jobs, next payout, paid jobs with commission, payouts.
**Admin app:** **Payments** (filter by status/method, split per payment, refunds with reason); **Finance** — worker balances with **Record payout** (UTR reference), **Reconciliation** by date range, **Commission rules** (add, scheduled rules shown as upcoming); dashboard card for finance staff.

## 2. API
| Endpoint | Who |
| --- | --- |
| `POST /customer/bookings/:id/payments` + `Idempotency-Key` → `{ payment, checkout }` | the booking's customer, when `payable` |
| `GET /customer/payments/:id`, `POST /customer/payments/:id/verify { razorpay_* }` | the payment's customer |
| `GET /customer/bookings/:id/invoice`, `GET /worker/bookings/:id/invoice` | either side, once fully paid |
| `POST /worker/bookings/:id/cash_received { amount_minor }` + `Idempotency-Key` | the booking's worker |
| `GET /worker/earnings` | worker |
| `GET /admin/payments?filter[status]&filter[method]` | admin, finance, support |
| `POST /admin/payments/:id/refunds { amount_minor, reason }` + `Idempotency-Key` | admin, finance |
| `GET /admin/finance/balances`, `POST /admin/finance/payouts { worker_id, amount_minor, reference }` + `Idempotency-Key` | admin, finance |
| `GET /admin/finance/reconciliation?from&to`, `GET/POST /admin/finance/commission_rules` | admin, finance |
| `POST /webhooks/razorpay` (signature header) | Razorpay |
| `POST /dev/fake_payments/:order_id/capture { fail? }` | development and test only |

New error codes: `nothing_to_pay` (409), `amount_mismatch`, `invalid_signature`, `payment_gateway_error` (502), `not_refundable` (409), `refund_too_large`, `reason_required`, `payout_too_large`, `reference_required`.

## 3. Commands and settings
```bash
cd backend && bin/rails db:migrate && bin/rails db:seed   # payment tables + the default 10% commission rule
# Restart the API and Sidekiq after migrating.
cd ../frontend && npm run gen:api
```
New ENV: `PAYMENT_ADAPTER` (`fake` default), `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`, `INVOICE_PREFIX`. For Razorpay test mode, point a webhook at `https://<api>/api/v1/webhooks/razorpay` with events `payment.captured`, `payment.failed`, `order.paid`, `refund.processed`, `refund.failed`.

## 4. Manual verification
1. Seed; log in as *Job Plumber* (`9814000014`) on :3002 and as a customer on :3001. Post a job, send a fixed ₹1,000 labour quote, book it.
2. No **Pay** card yet. Worker: set a time → **Start work** → **Mark job done**.
3. Customer: **Pay ₹1,000 online** → test checkout → **Succeed**. The card turns to *Paid in full*; the worker's job shows it too, live.
4. Customer: open **Invoice WK/2026-27/…** → **Print / save PDF**.
5. Worker → **Earnings**: the job shows `₹1,000 − ₹100 commission`, *Held for you* ₹900.
6. Admin (:3003) → **Payments**: the payment shows *Commission ₹100 · worker ₹900*. **Refund** ₹200 with a reason → *Partly refunded*.
7. Admin → **Finance** → **Record payout** for Job Plumber with a UTR → the balance drops. **Reconciliation** → *Ledger balanced*.
8. On another job, try **Fail** in the test checkout: the customer is told it failed and can pay again.
9. On another job, worker → **Customer paid me in cash** → confirm. Both sides show paid; Earnings shows *Commission you owe*, which the next payout offsets.
10. Admin → Finance → **Commission rules**: add 12% for one category from next month; it shows as *upcoming*, and bookings made before then keep 10%.

## 5. Not done in Phase 7
- **Razorpay Route / automatic worker payouts and worker bank/UPI details with KYC:** wait for D3. Payouts are recorded manually.
- **Real commission numbers:** D4. The 10% default is a seed and can be changed in the admin app.
- **DB triggers for append-only tables and the move to `structure.sql`:** planned for this phase and not done. Ledger entries, invoices and payment events are append-only in the app (`AppendOnly`), not in Postgres yet.
- **GST invoices** (GSTIN, HSN/SAC, place of supply): wait for the CA. Tax lines are 0.
- Refunds for cash payments, customer-initiated refund requests, and invoice PDFs generated on the server (the browser's print-to-PDF covers it for now).
- **CSP for checkout.razorpay.com:** Phase 9, with the rest of the CSP.
