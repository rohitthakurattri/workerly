import { devices, expect, test, type Page } from '@playwright/test'
import { login, postRequest, seed, totp, type Seed } from './helpers'

// Phase 6: an inspection job from booking to review, both screens live, with every price the
// customer pays approved by them (the visit fee, the final price, and extra charges one by one).
const CUSTOMER = 'http://localhost:3001'
const WORKER = 'http://localhost:3002'
const ADMIN = 'http://localhost:3003'
let data: Seed

test.beforeAll(() => {
  data = seed()
})

const amountDue = (page: Page) => page.getByTestId('amount-due')

test('inspection job: visit, final price, extra charges, done, rated, dispute resolved', async ({ browser }) => {
  test.setTimeout(240_000)
  const worker = await (await browser.newContext()).newPage()
  await login(worker, WORKER, data.phones.pro_jobs)
  await expect(worker.getByText('Job requests', { exact: true })).toBeVisible()
  const customer = await (await browser.newContext({ ...devices['Pixel 5'], geolocation: { latitude: 30.7001, longitude: 76.7203 }, permissions: ['geolocation'] })).newPage()
  await login(customer, CUSTOMER, data.phones.customer)
  const description = `Water heater not working ${Date.now()}`
  await postRequest(customer, description)

  // The worker quotes an inspection visit; the customer books it.
  const lead = worker.getByTestId('lead-card').filter({ hasText: description })
  await expect(lead).toBeVisible({ timeout: 30_000 })
  await lead.click()
  await worker.getByTestId('start-quote').click()
  await worker.getByTestId('kind-inspection').check()
  await worker.getByLabel('Visit fee (₹)').fill('199')
  await worker.getByTestId('send-quote').click()
  await expect(worker.getByTestId('my-quote')).toBeVisible()

  await customer.getByTestId('quote-card').filter({ hasText: 'Job Plumber' }).click({ timeout: 15_000 })
  await customer.getByTestId('accept-quote').click()
  await customer.getByRole('dialog').getByRole('button', { name: 'Book this worker' }).click()
  await expect(customer.getByTestId('booking-confirmed')).toBeVisible()
  await expect(amountDue(customer)).toHaveText('₹199')
  const bookingId = customer.url().split('/').pop()!

  // Visit time, then chat both ways, live.
  await worker.goto(`${WORKER}/jobs/${bookingId}`)
  await worker.getByTestId('visit-time').fill(new Date(Date.now() + 3 * 3600_000 + 5.5 * 3600_000).toISOString().slice(0, 16))
  await worker.getByRole('button', { name: 'Set visit time' }).click()
  await expect(customer.getByText(/^Visit: /)).toBeVisible({ timeout: 10_000 })
  await expect(customer.getByTestId('booking-status')).toHaveText('Visit scheduled')

  await customer.getByTestId('chat-input').fill('Gate code is 4321')
  await customer.getByRole('button', { name: 'Send', exact: true }).click()
  await expect(worker.getByTestId('chat-messages')).toContainText('Gate code is 4321', { timeout: 10_000 })
  await worker.getByTestId('chat-input').fill('On my way')
  await worker.getByRole('button', { name: 'Send', exact: true }).click()
  await expect(customer.getByTestId('chat-messages')).toContainText('On my way', { timeout: 10_000 })

  // Inspection, then the final price, which the customer approves.
  await worker.getByRole('button', { name: "I've arrived" }).click()
  await expect(customer.getByTestId('booking-status')).toHaveText('Inspecting', { timeout: 10_000 })
  await worker.getByRole('button', { name: 'Send final price' }).click()
  await worker.getByTestId('quote-line').nth(0).getByLabel('Description').fill('Replace heating element')
  await worker.getByTestId('quote-line').nth(0).getByLabel('Price per unit (₹)').fill('1200')
  await worker.getByTestId('send-quote').click()
  await expect(worker.getByText('Waiting for the customer to approve ₹1,200')).toBeVisible()
  await expect(amountDue(worker)).toHaveText('₹199') // not owed until approved

  const pending = customer.getByTestId('pending-price')
  await expect(pending).toContainText('Replace heating element', { timeout: 10_000 })
  await customer.getByTestId('approve-price').click()
  await expect(amountDue(customer)).toHaveText('₹1,200') // the visit fee is taken off the bill
  await expect(customer.getByTestId('booking-status')).toHaveText('Scheduled')

  // Work starts; the first extra charge is refused, the second approved.
  await expect(worker.getByRole('button', { name: 'Start work' })).toBeVisible({ timeout: 10_000 })
  await worker.getByRole('button', { name: 'Start work' }).click()
  for (const [price, approve] of [['300', false], ['150', true]] as const) {
    await worker.getByRole('button', { name: 'Ask for extra charges' }).click()
    await worker.getByTestId('quote-line').nth(0).getByLabel('Description').fill(`Extra part ${price}`)
    await worker.getByTestId('quote-line').nth(0).getByLabel('Price per unit (₹)').fill(price)
    await worker.getByTestId('send-quote').click()
    await expect(worker.getByRole('button', { name: 'Mark job done' })).toHaveCount(0) // blocked while waiting
    await expect(pending).toContainText(`Extra part ${price}`, { timeout: 10_000 })
    if (approve) {
      await customer.getByTestId('approve-price').click()
    }
    else {
      await customer.getByRole('button', { name: 'Say no' }).click()
      await customer.getByRole('dialog').getByRole('button', { name: 'Say no' }).click()
    }
    await expect(pending).toHaveCount(0)
    await expect(amountDue(customer)).toHaveText(approve ? '₹1,350' : '₹1,200')
    await expect(worker.getByRole('button', { name: 'Ask for extra charges' })).toBeVisible({ timeout: 10_000 })
  }
  await expect(amountDue(worker)).toHaveText('₹1,350')

  // Done, rated.
  await worker.getByRole('button', { name: 'Mark job done' }).click()
  await worker.getByRole('dialog').getByRole('button', { name: 'Mark job done' }).click()
  await expect(customer.getByTestId('booking-status')).toHaveText('Done', { timeout: 10_000 })
  await customer.getByRole('radio', { name: '5 stars' }).click()
  await customer.getByLabel('Tell others about the work (optional)').fill('Fixed it in an hour')
  await customer.getByRole('button', { name: 'Send rating' }).click()
  await expect(customer.getByText('You rated 5 ★')).toBeVisible()
  await expect(worker.getByText('Rated 5 ★')).toBeVisible({ timeout: 10_000 })

  // A problem report, resolved by support.
  await customer.getByRole('button', { name: 'Report a problem' }).click()
  await customer.getByLabel('Tell us what happened').fill(`Heater trips the switch ${description}`)
  await customer.getByRole('button', { name: 'Report problem' }).click()
  await expect(customer.getByTestId('booking-status')).toHaveText('Problem reported')

  const admin = await (await browser.newContext()).newPage()
  await login(admin, ADMIN, data.phones.admin)
  await admin.getByLabel('Authenticator code').fill(totp(data.totp_secret))
  await admin.getByRole('button', { name: 'Continue' }).click()
  await expect(admin.getByRole('heading', { name: 'Dashboard' })).toBeVisible()
  await admin.getByRole('link', { name: 'Disputes' }).click()
  const card = admin.getByRole('listitem').filter({ hasText: description })
  await card.getByRole('button', { name: 'Resolve' }).click()
  await admin.getByLabel('Resolution (shown to both sides)').fill('Worker revisited and reset the breaker')
  await admin.getByRole('dialog').getByRole('button', { name: 'Resolve' }).click()
  await expect(admin.getByRole('listitem').filter({ hasText: description })).toHaveCount(0)

  await expect(customer.getByText('Resolved by support: Worker revisited and reset the breaker')).toBeVisible({ timeout: 10_000 })
  await expect(customer.getByTestId('booking-status')).toHaveText('Done')
})
