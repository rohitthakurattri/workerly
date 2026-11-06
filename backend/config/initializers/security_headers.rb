# The API only ever returns JSON (and files via signed S3 URLs), so its responses forbid
# everything a browser could do with them: no scripts, no framing, no sniffing, no referrer
# leakage. HSTS comes from config.force_ssl in production. The apps' own CSP is set by the
# Nuxt servers (frontend/server/plugins/security-headers.ts).
# (Development serves Swagger UI at /api-docs, an HTML page, so it skips the CSP.)
Rails.application.config.action_dispatch.default_headers.merge!(
  **(Rails.env.development? ? {} : { "Content-Security-Policy" => "default-src 'none'; frame-ancestors 'none'; base-uri 'none'" }),
  "X-Content-Type-Options" => "nosniff",
  "X-Frame-Options" => "DENY",
  "Referrer-Policy" => "no-referrer",
  "Permissions-Policy" => "camera=(), microphone=(), geolocation=(), payment=()",
  "Cross-Origin-Resource-Policy" => "same-site"
)
