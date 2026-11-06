import { devices, expect, test } from '@playwright/test'
import { login, postRequest, seed } from './helpers'

// Opt-in: a real Razorpay test-mode checkout. Needs backend/.env with PAYMENT_ADAPTER=razorpay and
// test keys (rzp_test_…), internet access, and RAZORPAY_E2E=1. Pays through Razorpay's demo bank
// (Netbanking → "Success"); no webhook can reach localhost, so the app settles the payment by
// asking Razorpay (Payments::Sync).
const CUSTOMER = 'http://localhost:3001'
const WORKER = 'http://localhost:3002'

test.skip(!process.env.RAZORPAY_E2E, 'set RAZORPAY_E2E=1 with Razorpay test keys in backend/.env')

test('real Razorpay test-mode checkout settles the booking', async ({ browser }) => {
  test.setTimeout(300_000)
  const data = seed()
  const worker = await (await browser.newContext()).newPage()
  await login(worker, WORKER, data.phones.pro_jobs)
  const ctx = await browser.newContext({ ...devices['Pixel 5'], geolocation: { latitude: 30.7001, longitude: 76.7203 }, permissions: ['geolocation'] })
  const customer = await ctx.newPage()
  await login(customer, CUSTOMER, data.phones.customer)
  const description = `Razorpay test ${Date.now()}`
  await postRequest(customer, description)

  // A ₹100 job, booked, done.
  const lead = worker.getByTestId('lead-card').filter({ hasText: description })
  await expect(lead).toBeVisible({ timeout: 30_000 })
  await lead.click()
  await worker.getByTestId('start-quote').click()
  await worker.getByTestId('quote-line').nth(0).getByLabel('Description').fill('Fix the leaking tap')
  await worker.getByTestId('quote-line').nth(0).getByLabel('Price per unit (₹)').fill('100')
  await worker.getByTestId('send-quote').click()
  await customer.getByTestId('quote-card').filter({ hasText: 'Job Plumber' }).click({ timeout: 15_000 })
  await customer.getByTestId('accept-quote').click()
  await customer.getByRole('dialog').getByRole('button', { name: 'Book this worker' }).click()
  await expect(customer.getByTestId('booking-confirmed')).toBeVisible()
  const bookingId = customer.url().split('/').pop()!
  await worker.goto(`${WORKER}/jobs/${bookingId}`)
  await worker.getByTestId('visit-time').fill(new Date(Date.now() + 3 * 3600_000 + 5.5 * 3600_000).toISOString().slice(0, 16))
  await worker.getByRole('button', { name: 'Set visit time' }).click()
  await worker.getByRole('button', { name: 'Start work' }).click()
  await worker.getByRole('button', { name: 'Mark job done' }).click()
  await worker.getByRole('dialog').getByRole('button', { name: 'Mark job done' }).click()
  await expect(customer.getByTestId('outstanding')).toHaveText('₹100', { timeout: 15_000 })

  // Razorpay's own checkout, in its iframe.
  await customer.getByTestId('pay-now').click()
  await customer.locator('iframe.razorpay-checkout-frame').waitFor({ timeout: 30_000 })
  const checkout = customer.frameLocator('iframe.razorpay-checkout-frame')
  await checkout.getByText('Netbanking', { exact: true }).click()
  await checkout.getByText('Canara Bank', { exact: true }).click()
  await customer.waitForTimeout(2500) // the bank choice settles before Continue reacts
  // Razorpay's CTA never reports "stable" to Playwright (it animates), so it is clicked directly.
  await checkout.getByTestId('bottom-cta-button').click({ force: true })

  // The demo bank opens in a popup (not always seen as a "page" event, so look for it).
  let bank = ctx.pages().find(p => p.url().includes('razorpay.com/v1/gateway'))
  for (let i = 0; !bank && i < 60; i++) {
    await customer.waitForTimeout(500)
    bank = ctx.pages().find(p => p.url().includes('razorpay.com/v1/gateway'))
  }
  expect(bank, 'Razorpay demo bank page').toBeTruthy()
  await expect(bank!.getByText('This is just a demo bank page.')).toBeVisible()
  await bank!.getByRole('button', { name: /success/i }).first().click()

  await expect(customer.getByText('Paid in full')).toBeVisible({ timeout: 60_000 })
  await expect(customer.getByTestId('invoice-link')).toBeVisible()
})
