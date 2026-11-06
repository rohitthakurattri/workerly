# ADR 0009 — Payments, commission, invoices, refunds and payouts

**Status:** accepted 2026-11-06 (Phase 7). D3 (Razorpay Route) and D4 (commission numbers) are still open, so these defaults are settings:

| Question | Default | Where |
| --- | --- | --- |
| Gateway | Razorpay Standard Checkout (orders + webhooks). A **fake** adapter in development/test. | `PAYMENT_ADAPTER=fake\|razorpay`, `RAZORPAY_*` |
| Money to workers (D3) | Workerly collects online payments and **finance pays workers by bank/UPI outside the app**, recording each transfer with its UTR. Route (automatic split to linked accounts) replaces this when D3 is decided. | `POST /admin/finance/payouts` |
| Commission (D4) | 10% of **labour lines and the visit fee** (never parts or travel), no fixed fee, everywhere. | seeded `commission_rules` row; finance adds rules in the admin app |
| Tax | `tax_rate_bps` per category, 0 until the CA's GST opinion. Tax is passed through, never commissioned. | categories |
| Cash | Allowed. The worker confirms the exact amount owed; Workerly's commission becomes a balance the worker owes, netted from their next payout. | `POST /worker/bookings/:id/cash_received` |
| Invoice numbers | One invoice per fully-paid booking, gapless per Indian financial year: `WK/2026-27/000001`. | `INVOICE_PREFIX` |

## Rules
- **The server decides every amount.** The app never sends what to charge: an order is created for exactly what's outstanding (`Bookings::AmountDue` – approvals only, see ADR 0008). Cash must match it to the paisa.
- **Only the signed webhook makes anything paid.** The checkout callback (`/verify`) checks the signature and remembers the gateway payment id, but status changes come from `payment.captured` / `payment.failed` / `refund.*` webhooks, verified against the raw body. Each event is stored once (`payment_events`, unique provider + event id) and applied in the same transaction, so redeliveries change nothing. A captured amount that differs from the order becomes `amount_mismatch` for finance.
- **Idempotency everywhere money moves:** creating an order, cash, refunds and payouts all take an `Idempotency-Key`; an open unpaid order for the same amount is reused.
- **Commission is snapshotted at booking** (`Quotations::Accept` copies the matching rule onto the booking), so a rule change never re-prices accepted work. Rules are never edited: a new rule with a later `effective_from` replaces the old one; the most specific (city + category › category › city › everywhere) wins. Creating one is audited.
- **Double-entry ledger** (`Ledger::Post`, balanced per currency, idempotent by key, append-only):

  | Event | Debit | Credit |
  | --- | --- | --- |
  | online payment captured | gateway_clearing | platform_revenue (commission), tax_payable, worker_payable (share) |
  | cash recorded | cash_commission_receivable (worker) | platform_revenue, tax_payable |
  | refund processed | platform_revenue, tax_payable, worker_payable (pro rata) | gateway_clearing |
  | payout offset | worker_payable | cash_commission_receivable |
  | payout | worker_payable | gateway_clearing |

- **Refunds:** online payments only, by admin or finance, with a reason (audited); partial refunds allowed up to what's left. Each refund reverses the split pro rata on cumulative amounts, so a full refund leaves no rounding behind. Cash disputes are settled outside the app for now.
- **Payouts:** a payout can't exceed the worker's net (held − owed); commission owed on cash jobs is offset first.
- **Reconciliation** (`GET /admin/finance/reconciliation`) checks that the ledger balances and lists payments without ledger entries, amount mismatches, refunds pending over a day and unpaid orders over a day old.

## Roles
Customers pay their own bookings. Workers confirm cash and see their earnings. Support can **view** payments; only **admin and finance** refund, record payouts, run reconciliation and manage commission rules.

## Consequences
- Until Route (D3), Workerly holds workers' money between capture and payout. That is a regulatory and trust question for the founders. The ledger already separates `worker_payable`, so moving to Route changes the payout path, not the books.
- Raising commission (D4) is an admin action with no deploy, and it applies to new bookings only.
- The customer app loads `checkout.razorpay.com` only when the customer taps Pay. The Phase 9 CSP must allow it (`script-src`, `frame-src`).
