import { devices, expect, test, type Page } from '@playwright/test'
import { login, postRequest, seed, type Seed } from './helpers'

// Phase 5: two plumbers quote, the customer compares them live, and two simultaneous "Book"
// taps on different quotes produce exactly one booking. The race itself is proven with real
// threads in spec/requests/quotations_gate_spec.rb; this shows the same guarantee end to end.
const CUSTOMER = 'http://localhost:3001'
const WORKER = 'http://localhost:3002'
let data: Seed

test.beforeAll(() => {
  data = seed()
})

async function openLead(worker: Page, description: string) {
  const card = worker.getByTestId('lead-card').filter({ hasText: description })
  await expect(card).toBeVisible({ timeout: 30_000 })
  await card.click()
  await expect(worker).toHaveURL(/\/leads\/[0-9a-f-]{36}$/)
}

test('workers quote, the customer compares live, and only one of two simultaneous bookings wins', async ({ browser }) => {
  test.setTimeout(180_000)
  const near = await (await browser.newContext()).newPage()
  const near2 = await (await browser.newContext()).newPage()
  await login(near, WORKER, data.phones.pro_near)
  await login(near2, WORKER, data.phones.pro_near2)
  await expect(near.getByText('Job requests', { exact: true })).toBeVisible()
  await expect(near2.getByText('Job requests', { exact: true })).toBeVisible()

  const ctx = await browser.newContext({ ...devices['Pixel 5'], geolocation: { latitude: 30.7001, longitude: 76.7203 }, permissions: ['geolocation'] })
  const customer = await ctx.newPage()
  await login(customer, CUSTOMER, data.phones.customer)
  const description = `Kitchen sink blocked ${Date.now()}`
  await postRequest(customer, description)
  await expect(customer.getByTestId('no-quotes')).toBeVisible()

  // Worker 1: a fixed, itemised quote. The total is computed as they type.
  await openLead(near, description)
  await near.getByTestId('start-quote').click()
  const lines = near.getByTestId('quote-line')
  await lines.nth(0).getByLabel('Description').fill('Clear the blockage')
  await lines.nth(0).getByLabel('Price per unit (₹)').fill('500')
  await near.getByRole('button', { name: '+ Add a line' }).click()
  await lines.nth(1).getByLabel('Description').fill('Sink trap')
  await lines.nth(1).getByLabel('Price per unit (₹)').fill('450')
  await lines.nth(1).getByLabel('Warranty (days)').fill('90')
  await expect(near.getByTestId('quote-total')).toHaveText('₹950')
  await near.getByTestId('send-quote').click()
  await expect(near.getByTestId('my-quote')).toContainText('₹950')

  // The customer's open page shows it without a reload.
  await expect(customer.getByTestId('quote-card')).toHaveCount(1, { timeout: 15_000 })
  await expect(customer.getByTestId('quote-card').first()).toContainText('₹950')

  // Worker 2: an inspection visit, cheaper, so it sorts first.
  await openLead(near2, description)
  await near2.getByTestId('start-quote').click()
  await near2.getByTestId('kind-inspection').check()
  await near2.getByLabel('Visit fee (₹)').fill('199')
  await near2.getByTestId('send-quote').click()
  await expect(near2.getByTestId('my-quote')).toContainText('₹199')
  await expect(customer.getByTestId('quote-card')).toHaveCount(2, { timeout: 15_000 })
  await expect(customer.getByTestId('quote-price')).toHaveText(['₹199', '₹950'])

  // The customer is about to book worker 1 at ₹950 when worker 1 lowers the price. Confirming the
  // old price fails (consent is per version) and the page shows the new one.
  await expect(customer).toHaveURL(/\/requests\/[0-9a-f-]{36}$/)
  const requestUrl = customer.url()
  await customer.getByTestId('quote-card').filter({ hasText: '₹950' }).click()
  await customer.getByTestId('accept-quote').click()
  await expect(customer.getByRole('dialog')).toContainText('₹950')
  await near.getByRole('button', { name: 'Change quote' }).click()
  await near.getByTestId('quote-line').nth(0).getByLabel('Price per unit (₹)').fill('400')
  await expect(near.getByTestId('quote-total')).toHaveText('₹850')
  await near.getByRole('button', { name: 'Send changed quote' }).click()
  await expect(near.getByTestId('my-quote')).toContainText('Version 2')
  await customer.getByRole('dialog').getByRole('button', { name: 'Book this worker' }).click()
  await expect(customer.getByText('The worker just changed this quote. Check the new price before booking.')).toBeVisible()
  await expect(customer.getByTestId('quote-detail-price')).toHaveText('₹850')
  await customer.goto(requestUrl)
  await expect(customer.getByTestId('quote-price')).toHaveText(['₹199', '₹850'], { timeout: 15_000 })

  // Side-by-side comparison.
  await customer.getByLabel('Compare').selectOption('table')
  await expect(customer.getByTestId('quote-compare')).toContainText('90-day warranty')
  await customer.getByLabel('Compare').selectOption('cards')

  // Two tabs, one on each quote, both tap Book at the same moment.
  const quoteUrl = /\/quotes\/[0-9a-f-]{36}$/
  await customer.getByTestId('quote-card').nth(0).click()
  await expect(customer).toHaveURL(quoteUrl)
  const quoteA = customer.url()
  await customer.goto(requestUrl)
  await customer.getByTestId('quote-card').nth(1).click()
  await expect(customer).toHaveURL(quoteUrl)
  const quoteB = customer.url()
  const tabA = await ctx.newPage()
  const tabB = await ctx.newPage()
  await Promise.all([tabA.goto(quoteA), tabB.goto(quoteB)])
  for (const tab of [tabA, tabB]) {
    await tab.getByTestId('accept-quote').click()
    await expect(tab.getByRole('dialog')).toBeVisible()
  }
  const confirm = (tab: Page) => tab.getByRole('dialog').getByRole('button', { name: 'Book this worker' }).click()
  const answer = (tab: Page) => tab.waitForResponse(r => r.url().endsWith('/accept'))
  const [resA, resB] = await Promise.all([answer(tabA), answer(tabB), confirm(tabA), confirm(tabB)])
  const statuses = [resA.status(), resB.status()]
  console.log(`[phase-5 gate] simultaneous accepts answered ${statuses.join(' and ')}`)
  expect([...statuses].sort()).toEqual([201, 409])
  const [winner, loser, lostRes] = resA.status() === 201 ? [tabA, tabB, resB] : [tabB, tabA, resA]
  expect((await lostRes.json()).error.code).toBe('request_already_booked')
  await expect(winner.getByTestId('booking-confirmed')).toBeVisible()
  await expect(loser.getByTestId('accept-quote')).toHaveCount(0)
  await expect(loser.getByText('Not chosen')).toBeVisible()
  const winnerIsNear = (await winner.getByText('Near Plumber').count()) > 0
  await expect(winner.getByRole('link', { name: /Call/ })).toBeVisible()

  // The winning worker gets the job live, with the address and the customer's number.
  const [won, lost] = winnerIsNear ? [near, near2] : [near2, near]
  await won.goto(`${WORKER}/`)
  await expect(won.getByTestId('job-card').filter({ hasText: 'Sector 70' }).first()).toBeVisible({ timeout: 15_000 })
  await won.getByTestId('job-card').first().click()
  await expect(won.getByTestId('job-address')).toContainText('House 77')
  await expect(won.getByTestId('call-customer')).toBeVisible()

  // The other worker's lead has closed, and their quote reads "Not chosen".
  await lost.goto(`${WORKER}/`)
  await expect(lost.getByTestId('lead-card').filter({ hasText: description })).toHaveCount(0)
  await lost.goto(`${WORKER}/quotes`)
  await expect(lost.getByRole('link').filter({ hasText: 'Not chosen' }).first()).toBeVisible()

  // The request now points at the booking.
  await customer.goto(requestUrl)
  await expect(customer.getByRole('link', { name: 'View booking' })).toBeVisible()
})
