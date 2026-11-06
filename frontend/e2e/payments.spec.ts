import { devices, expect, test, type Browser, type Page } from '@playwright/test'
import { login, postRequest, seed, totp, type Seed } from './helpers'

// Phase 7: a finished job paid online (fake gateway), the invoice, the worker's earnings,
// then a partial refund and a payout by finance; and a job paid in cash. Needs PAYMENT_ADAPTER=fake
// and the seeded 10% commission rule.
const CUSTOMER = 'http://localhost:3001'
const WORKER = 'http://localhost:3002'
const ADMIN = 'http://localhost:3003'
let data: Seed

test.beforeAll(() => {
  data = seed()
})

/** A fixed ₹1,000 labour job, booked, worked and marked done. Returns both pages. */
async function finishedJob(browser: Browser, description: string): Promise<{ customer: Page, worker: Page, bookingId: string }> {
  const worker = await (await browser.newContext()).newPage()
  await login(worker, WORKER, data.phones.pro_jobs)
  await expect(worker.getByText('Job requests', { exact: true })).toBeVisible()
  const customer = await (await browser.newContext({ ...devices['Pixel 5'], geolocation: { latitude: 30.7001, longitude: 76.7203 }, permissions: ['geolocation'] })).newPage()
  await login(customer, CUSTOMER, data.phones.customer)
  await postRequest(customer, description)

  const lead = worker.getByTestId('lead-card').filter({ hasText: description })
  await expect(lead).toBeVisible({ timeout: 30_000 })
  await lead.click()
  await worker.getByTestId('start-quote').click()
  await worker.getByTestId('quote-line').nth(0).getByLabel('Description').fill('Fix the leaking tap')
  await worker.getByTestId('quote-line').nth(0).getByLabel('Price per unit (₹)').fill('1000')
  await worker.getByTestId('send-quote').click()
  await expect(worker.getByTestId('my-quote')).toBeVisible()

  await customer.getByTestId('quote-card').filter({ hasText: 'Job Plumber' }).click({ timeout: 15_000 })
  await customer.getByTestId('accept-quote').click()
  await customer.getByRole('dialog').getByRole('button', { name: 'Book this worker' }).click()
  await expect(customer.getByTestId('booking-confirmed')).toBeVisible()
  const bookingId = customer.url().split('/').pop()!
  await expect(customer.getByTestId('pay-card')).toHaveCount(0) // nothing owed before the work is done

  await worker.goto(`${WORKER}/jobs/${bookingId}`)
  await worker.getByTestId('visit-time').fill(new Date(Date.now() + 3 * 3600_000 + 5.5 * 3600_000).toISOString().slice(0, 16))
  await worker.getByRole('button', { name: 'Set visit time' }).click()
  await worker.getByRole('button', { name: 'Start work' }).click()
  await worker.getByRole('button', { name: 'Mark job done' }).click()
  await worker.getByRole('dialog').getByRole('button', { name: 'Mark job done' }).click()
  await expect(customer.getByTestId('booking-status')).toHaveText('Done', { timeout: 10_000 })
  return { customer, worker, bookingId }
}

test('online payment, invoice, earnings, refund and payout', async ({ browser }) => {
  test.setTimeout(240_000)
  const description = `Tap leaking ${Date.now()}`
  const { customer, worker, bookingId } = await finishedJob(browser, description)

  // The customer pays through the (fake) checkout; the webhook settles it.
  await expect(customer.getByTestId('outstanding')).toHaveText('₹1,000', { timeout: 10_000 })
  await customer.getByTestId('pay-now').click()
  await customer.getByTestId('fake-pay').click()
  await expect(customer.getByText('Paid in full')).toBeVisible({ timeout: 20_000 })
  await expect(customer.getByTestId('pay-now')).toHaveCount(0)
  await expect(worker.getByTestId('payment-card')).toContainText('Paid in full', { timeout: 10_000 })

  // The invoice, numbered per financial year.
  await customer.getByTestId('invoice-link').click()
  await expect(customer.getByTestId('invoice')).toContainText(/WK\/\d{4}-\d{2}\/\d{6}/)
  await expect(customer.getByTestId('invoice-total')).toHaveText('₹1,000')
  await expect(customer.getByTestId('invoice')).toContainText('Fix the leaking tap')

  // The worker sees ₹1,000 less 10% commission on labour.
  await worker.goto(`${WORKER}/earnings`)
  await expect(worker.getByText('₹1,000 − ₹100 commission').first()).toBeVisible()

  // Finance: a partial refund, then a payout of what's left for the worker.
  const admin = await (await browser.newContext()).newPage()
  await login(admin, ADMIN, data.phones.admin)
  await admin.getByLabel('Authenticator code').fill(totp(data.totp_secret))
  await admin.getByRole('button', { name: 'Continue' }).click()
  await expect(admin.getByRole('heading', { name: 'Dashboard' })).toBeVisible()
  await admin.getByRole('navigation').getByRole('link', { name: 'Payments' }).click()
  const row = admin.getByRole('listitem').filter({ has: admin.locator(`a[href="/bookings/${bookingId}"]`) })
  await expect(row).toContainText('Commission ₹100 · worker ₹900')
  await row.getByTestId('refund').click()
  await admin.getByLabel(/^Amount \(up to/).fill('200')
  await admin.getByLabel('Reason').fill('Tap still drips slightly')
  await admin.getByRole('dialog').getByRole('button', { name: 'Refund ₹200' }).click()
  await expect(row).toContainText('Partly refunded', { timeout: 10_000 })
  await expect(row).toContainText('₹200')

  await admin.getByRole('navigation').getByRole('link', { name: 'Finance' }).click()
  const balance = admin.getByRole('row').filter({ hasText: 'Job Plumber' })
  await balance.getByTestId('record-payout').click()
  await admin.getByLabel('Transfer reference').fill(`UTR${Date.now()}`)
  await admin.getByRole('dialog').getByRole('button', { name: 'Record payout' }).click()
  await expect(admin.getByText('Payout recorded')).toBeVisible()

  await admin.getByRole('tab', { name: 'Reconciliation' }).click()
  await expect(admin.getByTestId('ledger-balanced')).toHaveText('✓ Ledger balanced')
})

test('cash payment confirmed by the worker', async ({ browser }) => {
  test.setTimeout(180_000)
  const { customer, worker } = await finishedJob(browser, `Tap dripping ${Date.now()}`)

  await expect(worker.getByTestId('outstanding')).toHaveText('₹1,000', { timeout: 10_000 })
  await worker.getByTestId('cash-received').click()
  await expect(worker.getByRole('dialog')).toContainText('₹1,000')
  await worker.getByRole('dialog').getByRole('button', { name: 'Yes, I received it' }).click()
  await expect(worker.getByTestId('payment-card')).toContainText('Paid in full')
  await expect(customer.getByText('Paid in full')).toBeVisible({ timeout: 10_000 })
  await expect(customer.getByTestId('pay-now')).toHaveCount(0)

  await worker.goto(`${WORKER}/earnings`)
  await expect(worker.getByTestId('earnings-owed')).not.toHaveText('₹0')
})
