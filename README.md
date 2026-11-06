# Workerly.in

Home-services marketplace for Mohali and Chandigarh: customers post a problem, verified workers send quotes, the customer picks one.

| Path | What |
| --- | --- |
| `backend/` | Rails 8.1 API (modular monolith), PostgreSQL + PostGIS, Sidekiq |
| `frontend/` | Nuxt 4 codebase built three times: customer, worker (Pro) and admin apps |
| `docs/` | Architecture decisions (`adr/`) and per-phase handover notes |
| `infra/` | Terraform for AWS (draft, not applied yet) |

## Run it locally

Requires Ruby 3.4, Node 24, Docker and ImageMagick (photo processing).

```bash
docker compose up -d                      # Postgres+PostGIS on :5433, Redis on :6380

cd backend
bundle install
cp .env.example .env                      # then fill the secrets: bin/rails secret / openssl rand -hex 32
bin/rails db:prepare
bin/rails server -p 3000                  # API
bundle exec sidekiq -C config/sidekiq.yml # jobs: OTP SMS, matching, quote and booking notifications, scheduled expiry
tail -f log/fake_sms.log                  # your "phone": OTP codes appear here in development

cd ../frontend
npm install
npm run dev:customer                      # http://localhost:3001
npm run dev:worker                        # http://localhost:3002
npm run dev:admin                         # http://localhost:3003
```

Create a staff user (prints a TOTP QR URI for an authenticator app):

```bash
cd backend && bin/rails "admin:grant[9876543210,admin]"
```

## Production-like stack (local)

The real Docker images, production builds, on plain http:

```bash
docker compose --profile app up --build   # API :3100, customer :3101, worker :3102, admin :3103
docker compose logs -f jobs | grep FakeSms   # login codes (sent by Sidekiq; staging mode, fake SMS)
```

## Razorpay test mode (local)

Real Razorpay checkout with test money, no tunnel needed:

1. Razorpay dashboard → switch to **Test Mode** → Account & Settings → API Keys → generate a test key.
2. In `backend/.env`: `PAYMENT_ADAPTER=razorpay`, `RAZORPAY_KEY_ID=rzp_test_…`, `RAZORPAY_KEY_SECRET=…`; restart the API and Sidekiq.
3. Finish a job, then **Pay** as the customer and use Razorpay's test details:
   - UPI: `success@razorpay` to pay, `failure@razorpay` to fail;
   - cards: see https://razorpay.com/docs/payments/payments/test-card-details/
4. The booking turns paid within a few seconds: after checkout the API asks Razorpay what happened (webhooks can't reach `localhost`).
   - Refunds from Admin → Payments work the same way: a refund Razorpay reports as pending is completed by `Payments::SyncPendingJob` (every 5 minutes).

Live keys are refused outside production, and test keys in production.

Browser test against real Razorpay (pays through Razorpay's demo bank): `RAZORPAY_E2E=1 npx playwright test e2e/razorpay-test-mode.spec.ts`. The rest of the browser suite uses the fake checkout, so run it with `PAYMENT_ADAPTER=fake`.

## Tests

```bash
cd backend && bundle exec rspec && bundle exec rubocop && bundle exec brakeman -q
cd frontend && npm test && npm run lint && npx playwright test   # e2e needs everything above running
```

API docs: `http://localhost:3000/api-docs` in development (generated from request specs by `bundle exec rake rswag:specs:swaggerize`).
