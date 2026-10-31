import { devices, expect, test } from '@playwright/test'
import { login, seed, type Seed } from './helpers'

// Phase 4 exit gate: a request in Mohali reaches the right workers within 30 s, live, and
// out-of-area workers never see it. (The "best 10 of many" ranking is covered by
// spec/requests/matching_gate_spec.rb, which can create dozens of workers.)
const CUSTOMER = 'http://localhost:3001'
const WORKER = 'http://localhost:3002'
let data: Seed

test.beforeAll(() => {
  data = seed()
})

test('a new request appears live for the nearby plumber and never for the far one', async ({ browser }) => {
  test.setTimeout(120_000)
  const near = await (await browser.newContext()).newPage()
  const far = await (await browser.newContext()).newPage()
  await login(near, WORKER, data.phones.pro_near)
  await login(far, WORKER, data.phones.pro_far)
  await expect(near.getByText('Job requests', { exact: true })).toBeVisible()
  await expect(far.getByText('Job requests', { exact: true })).toBeVisible()

  const customer = await (await browser.newContext({ ...devices['Pixel 5'], geolocation: { latitude: 30.7001, longitude: 76.7203 }, permissions: ['geolocation'] })).newPage()
  await login(customer, CUSTOMER, data.phones.customer)
  const description = `Bathroom tap leaking ${Date.now()}`
  await customer.getByRole('button', { name: 'Post a job' }).click()
  await customer.getByLabel('Describe the problem').fill(description)
  await customer.getByRole('button', { name: 'Continue' }).click()
  await expect(customer.getByRole('radio', { name: /Plumber/ })).toBeChecked()
  await customer.getByRole('button', { name: 'Continue' }).click()
  await expect(customer.getByText('Pin set. Drag it to adjust.')).toBeVisible()
  await customer.getByLabel('House / flat number and street').fill('House 77')
  await customer.getByLabel('Sector or area').fill('Sector 70')
  await customer.getByLabel('PIN code').fill('160071')
  await customer.getByRole('button', { name: 'Save address' }).click()
  await customer.getByRole('button', { name: 'Continue' }).click()

  await customer.getByRole('button', { name: 'Send request' }).click()
  const sent = Date.now()

  // The near worker's open app shows it without a reload.
  const card = near.getByTestId('lead-card').filter({ hasText: description })
  await expect(card).toBeVisible({ timeout: 30_000 })
  const seconds = (Date.now() - sent) / 1000
  console.log(`[phase-4 gate] lead visible to the nearby worker ${seconds.toFixed(1)} s after sending`)
  expect(seconds).toBeLessThan(30)
  await expect(card).toContainText('Sector 70')
  await expect(card).toContainText('under 1 km')

  // The customer sees how many workers got it.
  await expect(customer.getByTestId('match-status')).toContainText(/Sent to \d+ nearby worker/)

  // The far worker: nothing live, nothing after a reload, and the lead page is closed to them.
  await far.reload()
  await expect(far.getByText('Job requests', { exact: true })).toBeVisible()
  await expect(far.getByTestId('lead-card').filter({ hasText: description })).toHaveCount(0)

  // Opening the lead shows the area but not the address; "Not interested" removes it.
  await card.click()
  await expect(near).toHaveURL(/\/leads\/[0-9a-f-]{36}$/)
  await expect(near.getByRole('heading', { name: 'Plumber' })).toBeVisible()
  await expect(near.getByText(description, { exact: true })).toBeVisible()
  await expect(near.getByText('House 77')).toHaveCount(0)
  const leadUrl = near.url()
  await far.goto(leadUrl)
  await expect(far.getByText('This job is no longer available')).toBeVisible()

  await near.getByRole('button', { name: 'Not interested' }).click()
  await near.getByRole('dialog').getByRole('button', { name: 'Not interested' }).click()
  await expect(near.getByTestId('lead-card').filter({ hasText: description })).toHaveCount(0)
})
