# ADR 0007 — Quotations, accepting a quote, and the ledger schema

**Status:** accepted 2026-10-31 (Phase 5). D5 was not answered again, so the plan's numbers stay as settings (10 workers invited, 5 quotes per request, 24 h open). D4 (commission) is not needed yet: quotes are what the customer pays, and commission comes out of the worker's side in Phase 7.

## Tables
| Table | Rule |
| --- | --- |
| `quotations` | One per invited worker per request (`unique(service_request_id, worker_profile_id)` and a required `request_invitation_id`, so only invited workers can quote). `kind` fixed or inspection, `status` submitted / accepted / declined / withdrawn / expired, `current_version`, `valid_until` (never past the request's expiry). **At most one accepted quote per request** (partial unique index). |
| `quotation_revisions` | Every price change is a new row (`unique(quotation_id, version)`), never updated or deleted. `subtotal + tax = total` is a CHECK. Stage `initial` (fixed) or `inspection_fee`; `final` and `change_order` are for Phase 6. |
| `quotation_items` | Lines: labour, material (brand, condition, warranty), transport, inspection, other. CHECKs: quantity > 0, prices ≥ 0. |
| `bookings` | Created in `confirmed` on accept. **One active booking per request** (partial unique index, ignoring cancelled/rejected). Carries `approved_total_minor`, the amount the customer has agreed to so far. The full status list from the plan is already in the CHECK so Phase 6 adds transitions, not a migration. |
| `booking_approvals` | Proof of consent: who approved which exact revision, when, IP and browser. `unique(quotation_revision_id)`. |
| `booking_status_histories` | Append-only log of every booking status change. |
| `ledger_accounts / ledger_transactions / ledger_entries` | Double-entry schema (Phase 7 posts to it). `Ledger::Post` refuses unbalanced transactions per currency and is idempotent by key. Entries are append-only. |
| `idempotency_keys` | Stored responses for `Idempotency-Key` replays, per user, kept 24 h. |
| `service_categories.tax_rate_bps` | Tax per category, **0 by default** until the CA's opinion on GST. Quotes copy the rate onto each revision. |

## Prices are computed by the server
The worker sends lines (quantity, unit, unit price in paise). `Quotations::Build` computes each line (quantity × price, rounded half up), the subtotal, tax (basis points, half up) and the total. Amounts sent by the client are ignored. The worker app shows the same maths live (`app/utils/quotes.ts`, tested to match), but the server's number is the one the customer sees and accepts. Limits: 1–30 lines, total ≤ ₹5,00,000 (larger jobs go through support), fixed quotes must be above zero, an inspection visit may be free, 10 versions per quote. Phone numbers and e-mails typed into notes and line descriptions are masked, so quotes can't be used to take the customer off-platform.

## Accepting: exactly one booking
`POST /customer/quotations/:id/accept { version }` with an `Idempotency-Key` header.
1. **Row lock on the request** (`SELECT … FOR UPDATE`), then on the quotation. Every write to a request's quotes (create, revise, withdraw, decline, accept) takes the same locks in the same order, so they run one at a time per request.
2. **Checks:** request still open/quoting and not expired; quote still submitted and within `valid_until`; **`version` equals `current_version`** (if the worker changed the price while the customer was looking, the accept fails with `quotation_changed` and the app shows the new price); worker not suspended.
3. **One transaction:** booking, approval of that revision, history row, quote accepted, every other open quote declined (`another_accepted`), request `booked`, address and phone revealed to the winner.
4. **Backstops:** the partial unique indexes reject a second booking or a second accepted quote even if a future code path forgets the lock. A unique violation becomes `409 request_already_booked`; a deadlock (possible only without the lock) is retried.
5. **After commit:** the winner is told live, by push, or by SMS (critical event); the others get an in-app notice; every invited worker's lead closes.

**Idempotency:** the customer app makes one key per decision. A replay of a successful accept returns the stored response with `Idempotent-Replayed: true`. A failed attempt isn't stored, so the same key can be retried. The same key with a different body is refused.

**Exit gate:** `spec/requests/quotations_gate_spec.rb` runs real threads with separate database connections: two different quotes accepted at the same moment (10 rounds), the same quote twice (double tap), and the same race with the row lock disabled (the index alone holds). Every run produces exactly one booking.

## Live updates
`RequestChannel` (customer, own submitted requests only) carries `quote.new`, `quote.updated`, `quote.withdrawn`, `quote.declined`, `request.booked`, with ids only; the app refetches through the API so the serializer stays the single source of what a customer may see. `WorkerLeadsChannel` adds `quote.status` (accepted or declined).

## What each side sees
- **Customer, before booking:** the worker's name, photo, rating, jobs done, experience, verified badge, distance band, quote type, lines, total, estimate, warranty, validity and price history. Never the worker's phone. Withdrawn quotes are hidden.
- **Worker:** only their own quote. Other workers' prices are never shown; the lead says how many quotes exist and whether it's full.
- **After booking:** the customer gets the worker's phone; the worker gets the customer's name, phone, full address with a map link, and the unmasked description. A suspended worker loses access to booked customers' details.

## Choices made without a decision
- **Quote limit counts live quotes** (submitted + accepted). A withdrawal frees a slot.
- **Withdrawn is final:** one quote per worker per request, as in the plan's unique index.
- **Request goes `open → quoting`** at the first quote and stays there even if every quote is withdrawn; *Needs attention* still shows open requests with no quotes after 30 minutes.
- **Tax:** per-category rate on the revision, default 0. No platform fee is added to the customer's price.
