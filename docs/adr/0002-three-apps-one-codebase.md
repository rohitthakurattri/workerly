# ADR 0002 — Three apps on three subdomains from one Nuxt codebase

**Status:** accepted 2026-10-30 (plan decision D2)

- `workerly.in` (customer), `pro.workerly.in` (worker), `admin.workerly.in` (admin).
- `APP_TARGET=customer|worker|admin` is set at build time. `app/utils/target-routes.ts` keeps only `pages/<target>/**` (with the prefix removed) plus shared pages such as `login.vue`, so other apps' pages never ship in a bundle.
- Each target has its own build dir (`.nuxt/<target>`), output (`.output/<target>`), theme colour, icon and, from Phase 9, PWA manifest.
- Admin is a client-only SPA marked `noindex`; it can be IP-restricted at CloudFront/ALB.
- Route middleware is UX only. Rails policies are the real guard.
