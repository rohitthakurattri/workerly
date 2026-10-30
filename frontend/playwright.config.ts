import { defineConfig } from '@playwright/test'

// Smoke test against locally running apps: API on :3000 (with Sidekiq), Nuxt on :3001-3003.
export default defineConfig({
  testDir: 'e2e',
  timeout: 60_000,
  workers: 1,
  use: { headless: true, trace: 'retain-on-failure' },
})
