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

## Tests

```bash
cd backend && bundle exec rspec && bundle exec rubocop && bundle exec brakeman -q
cd frontend && npm test && npm run lint && npx playwright test   # e2e needs everything above running
```

API docs: `http://localhost:3000/api-docs` in development (generated from request specs by `bundle exec rake rswag:specs:swaggerize`).
