# ADR 0008 — Booking lifecycle, consent to every rupee, chat, reviews, disputes

**Status:** accepted 2026-10-31 (Phase 6). The plan's open policy questions were not answered, so these defaults are settings:

| Policy | Default | ENV |
| --- | --- | --- |
| Visit fee and the repair bill | taken off: owed = max(final price, fee) | `INSPECTION_FEE_ADJUSTED=true` (false: fee + final) |
| Cancellation | free until the worker checks in; after an inspection visit the fee stays due | — |
| Materials | the worker's risk until the customer approves them (as a final price or extra charge) | — |
| Contact details and chat after completion | 48 h | `BOOKING_CONTACT_HOURS` |
| Review window | 30 days | `REVIEW_WINDOW_DAYS` |
| Dispute window | 7 days | `DISPUTE_WINDOW_DAYS` |

## State machine (`Bookings::Transitions`)
| Event | Who | From → to |
| --- | --- | --- |
| schedule | worker | confirmed → scheduled (fixed) / inspection_scheduled (inspection); also reschedules |
| check_in | worker | inspection_scheduled → inspecting |
| final_quotation | worker | inspecting → awaiting_final_approval |
| approve_final / reject_final | customer | awaiting_final_approval → scheduled / closed_after_inspection |
| start | worker | scheduled → in_progress |
| change_order | worker | in_progress → awaiting_change_approval |
| approve_change / reject_change | customer | awaiting_change_approval → in_progress |
| complete | worker | in_progress → completed (request fulfilled) |
| cancel | customer, worker | confirmed, inspection_scheduled, scheduled → cancelled |
| admin_cancel | admin, support (reason, audited) | any open status → cancelled |
| dispute | customer, within 7 days | completed, paid → disputed |
| resolve_dispute | admin, support (resolution, audited) | disputed → previous status |

`Bookings::Perform` runs every event in one transaction (request, booking, quotation locks in that order, same as accepting a quote), writes a `booking_status_histories` row, recomputes the amount owed, and sends live updates and notifications after commit. Anything else is `409 invalid_transition`. The apps get `actions` (what this viewer may press now) from the API instead of re-implementing the rules.

## No path charges above approved amounts
`bookings.approved_total_minor` is what the customer owes, and it is only ever written by `Bookings::AmountDue`, which reads **approved `booking_approvals` only**. A final price or extra charge is a new immutable revision held in `pending_revision`; it counts only once the customer approves exactly that revision (`revision_not_pending` otherwise; `unique(quotation_revision_id)` stops a second decision; approvals take an `Idempotency-Key`). The worker can't complete while a price waits. Amounts sent by the worker are ignored (server-side pricing, ADR 0007).

**Exit gate:** `spec/requests/bookings_gate_spec.rb` — every endpoint from every one of the 14 statuses over HTTP (allowed → 200, otherwise 409), wrong people (other worker, other customer, suspended worker, verifier, customer on worker endpoints, worker approving) refused, and a 300-step random walk over real bookings checking after every step that the amount owed equals the approved revisions, never exceeds their sum, and never includes the pending one.

## Request after a booking ends early
Cancelled before work, or closed after a rejected final price: the booking's quote is declined (`booking_cancelled`) and, if the request hasn't expired, the quotes that lost to it come back (if still valid and their worker can take jobs). The request goes back to quoting (or open), invited workers see the lead again, and restored workers are told. The one-active-booking index ignores `closed_after_inspection` so a new booking can be made.

## Chat, reviews, disputes
- **Chat:** `messages`, append-only, both parties, live over `BookingChannel`; one push per 10-minute burst. Open while contact details are. Support can read it in the admin app.
- **Reviews:** one per finished booking, 1–5 and text, updates the worker's average (which feeds matching).
- **Disputes:** one open per booking, category + description; support resolves with a written resolution. Refunds wait for Phase 7 (finance).
