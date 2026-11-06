# ADR 0011 — PWA, security headers and deployment shape

**Status:** accepted 2026-11-07 (Phase 9). Everything here was built and checked **locally**. The AWS Terraform in `infra/terraform/` is a first draft: it has **not been validated or applied** (the founders asked to stay local for now).

## PWA (all three apps)
- **Manifest per app** from `server/routes/manifest.webmanifest.ts` (one `public/` folder serves three apps): name, theme colour, 192/512 icons and a maskable icon per app; Apple touch icon and meta tags in `nuxt.config.ts`.
- **One service worker** (`public/sw.js`, `?app=` picks icons):
  - pages always come from the network (they show live, personal data); if the network is down, a trilingual **offline page**;
  - `/_nuxt/*` (content-hashed) is cache-first; icons are stale-while-revalidate;
  - the API is never cached;
  - it takes over **push** (Phase 4). `push-sw.js` remains as a shim so existing registrations update.
  - In development `?cache=0` turns caching off (Vite modules aren't hashed).
- **Install card** on the customer and worker home pages: the browser's prompt where there is one (Android/Chrome), "Share → Add to Home Screen" on iPhone. On iPhone, installing is what makes job-alert push possible for workers.

## Security headers
- **Apps** (`server/plugins/security-headers.ts`, `app/utils/security-headers.ts`): a strict CSP on every HTML page, built per app:
  - scripts: `'self'` + a per-request **nonce** added to Nuxt's own script tags; plus Razorpay checkout in the customer app only;
  - styles allow inline (Vue/Leaflet style attributes);
  - images/media from the API origin, the files bucket (`NUXT_PUBLIC_ASSET_ORIGINS`) and the map tile host;
  - connect to the API and its websocket; frames only Razorpay (customer); `frame-ancestors 'none'`, `object-src 'none'`.
  - Also Permissions-Policy (microphone only in the customer app, payment only there), nosniff, DENY framing, Referrer-Policy, COOP, and HSTS + `upgrade-insecure-requests` when the API is https.
  - Development skips the CSP (Vite HMR).
- **API** (`config/initializers/security_headers.rb`): JSON only, so `default-src 'none'; frame-ancestors 'none'`, DENY, nosniff, no-referrer, all permissions off (Swagger UI in development excepted).
- **Hosts:** `APP_HOSTS` allow-list in production (`/up` exempt for the load balancer).
- **Map tiles:** production logs a warning if `NUXT_PUBLIC_MAP_TILE_URL` still points at OpenStreetMap's own servers.

## Refusing to run on stand-ins
Production refuses to boot with `SMS_ADAPTER=fake` or `PAYMENT_ADAPTER=fake` (fake SMS would drop every login code), or Razorpay without a key id, unless `DEPLOY_ENV=staging`. In staging the fake SMS adapter writes codes to the log for testers.

## Images and the local production-like stack
- `backend/Dockerfile`: one image for API, Sidekiq and migrations (ImageMagick, jemalloc, non-root, bootsnap).
- `frontend/Dockerfile`: one image with all three builds; `APP_TARGET` picks the server.
- `docker compose --profile app up --build` runs those images locally on plain http:
  - API on :3100, customer :3101, worker :3102, admin :3103;
  - its own database, staging mode, files on disk;
  - local-only switches: `FORCE_SSL=false`, `LOCAL_DISK_STORAGE=1`.

## Cloud (draft, not applied)
`infra/terraform/` sketches AWS ap-south-1:
- VPC with private subnets and NAT;
- RDS Postgres 16 + PostGIS (forced TLS, managed password);
- ElastiCache Redis 7 (TLS, auth, noeviction);
- KMS-encrypted versioned S3 for files;
- ECR;
- ECS Fargate services: api (CPU autoscaling), jobs, customer, worker, admin, plus a migrate task;
- ALB routed by host, with ACM and Route 53;
- WAF (managed rules + rate limit);
- Secrets Manager;
- CloudWatch alarms to email.

Review, `terraform validate` and a staging apply are the next steps when cloud work starts.
