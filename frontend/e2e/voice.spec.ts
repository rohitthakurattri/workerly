import { devices, expect, test } from '@playwright/test'
import { login, seed, totp, type Seed } from './helpers'

// Phase 8: a voice note recorded with Chromium's fake microphone, transcribed by the fake
// adapter, added to the description by the customer, and read by triage (plumber). Then the
// admin AI quality report. Needs AI_TRANSCRIBE_ENABLED (default in development).
const CUSTOMER = 'http://localhost:3001'
const ADMIN = 'http://localhost:3003'
let data: Seed

test.use({
  launchOptions: { args: ['--use-fake-ui-for-media-stream', '--use-fake-device-for-media-stream'] },
})

test.beforeAll(() => {
  data = seed()
})

test('voice note: record, transcribe, add to description, triage reads it', async ({ browser }) => {
  test.setTimeout(120_000)
  const ctx = await browser.newContext({ ...devices['Pixel 5'], permissions: ['microphone'] })
  const customer = await ctx.newPage()
  await login(customer, CUSTOMER, data.phones.customer)
  await customer.getByRole('button', { name: 'Post a job' }).click()

  await customer.getByTestId('voice-record').click()
  await expect(customer.getByRole('timer')).toBeVisible()
  await customer.waitForTimeout(2_000)
  await customer.getByTestId('voice-stop').click()

  await expect(customer.getByTestId('voice-transcript')).toContainText('kitchen tap is leaking', { timeout: 30_000 })
  await expect(customer.getByTestId('voice-note').locator('audio')).toHaveCount(1)
  await customer.getByTestId('voice-use').click()
  await expect(customer.getByLabel('Describe the problem')).toHaveValue(/kitchen tap is leaking/)
  await customer.getByTestId('voice-use').click() // a second tap doesn't duplicate it
  expect(((await customer.getByLabel('Describe the problem').inputValue()).match(/kitchen tap/g) ?? []).length).toBe(1)

  await customer.getByRole('button', { name: 'Continue' }).click()
  await expect(customer.getByText('Suggested', { exact: true }).first()).toBeVisible({ timeout: 15_000 })
  await expect(customer.getByRole('radio', { name: /Plumber/ })).toBeChecked()
})

test('admin sees the AI quality report', async ({ browser }) => {
  const admin = await (await browser.newContext()).newPage()
  await login(admin, ADMIN, data.phones.admin)
  await admin.getByLabel('Authenticator code').fill(totp(data.totp_secret))
  await admin.getByRole('button', { name: 'Continue' }).click()
  await admin.getByRole('navigation').getByRole('link', { name: 'AI quality' }).click()
  await expect(admin.getByRole('heading', { name: 'AI triage quality' })).toBeVisible()
  await expect(admin.getByTestId('ai-accuracy')).toHaveText(/%|–/)
})
