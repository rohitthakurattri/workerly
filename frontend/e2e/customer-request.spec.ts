import { devices, expect, test } from '@playwright/test'
import { login, seed, type Seed } from './helpers'

// Phase 3 exit gate: a customer creates a categorised request with photos in under 2 minutes on a
// mid-range Android phone. Emulated here: Pixel 5 screen, 4x slower CPU, a 4G-like connection and
// a full-size camera photo. The script types instantly, so this measures the app's share of the
// two minutes; the human share is covered by the manual check in docs/phase-3-customer-requests.md.
const CUSTOMER = 'http://localhost:3001'
const MOHALI_SECTOR_70 = { latitude: 30.7001, longitude: 76.7203 }
let data: Seed

test.use({ ...devices['Pixel 5'], geolocation: MOHALI_SECTOR_70, permissions: ['geolocation'] })

test.beforeAll(() => {
  data = seed()
})

test('customer posts a categorised request with photos, fast enough on a mid-range phone', async ({ page }) => {
  test.setTimeout(180_000)
  await login(page, CUSTOMER, data.phones.customer)
  await expect(page.getByRole('button', { name: 'Post a job' })).toBeVisible()

  const cdp = await page.context().newCDPSession(page)
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: 4 })
  await cdp.send('Network.emulateNetworkConditions', {
    offline: false, latency: 60, downloadThroughput: (4 * 1024 * 1024) / 8, uploadThroughput: (1.5 * 1024 * 1024) / 8,
  })
  const started = Date.now()

  // 1. Describe + two photos (one camera-sized)
  await page.getByRole('button', { name: 'Post a job' }).click()
  await page.getByLabel('Describe the problem').fill('Kitchen tap is leaking and the pipe under the sink drips')
  await page.getByTestId('photo-input').setInputFiles([data.camera_photo, data.camera_photo])
  await expect(page.getByAltText('Photo of the problem')).toHaveCount(2, { timeout: 60_000 })
  await page.getByRole('button', { name: 'Continue' }).click()

  // 2. AI suggestion is pre-selected; answer one follow-up question
  await expect(page.getByText('Suggested', { exact: true })).toBeVisible()
  await expect(page.getByRole('radio', { name: /Plumber/ })).toBeChecked()
  await page.getByLabel('Is water leaking right now?').fill('Yes, slowly')
  await page.getByRole('button', { name: 'Continue' }).click()

  // 3. New address: the pin comes from GPS
  await expect(page.getByText('Pin set. Drag it to adjust.')).toBeVisible()
  await page.getByLabel('House / flat number and street').fill('House 1234')
  await page.getByLabel('Sector or area').fill('Sector 70')
  await page.getByLabel('PIN code').fill('160071')
  await page.getByRole('button', { name: 'Save address' }).click()

  // 4. When
  await page.getByText('Today', { exact: true }).click()
  await page.getByRole('button', { name: 'Continue' }).click()

  // 5. Review and send
  await expect(page.getByText('Summary (written by AI):')).toBeVisible()
  await page.getByRole('button', { name: 'Send request' }).click()
  await expect(page.getByText('Waiting for quotes').first()).toBeVisible()
  const seconds = (Date.now() - started) / 1000

  await expect(page.getByRole('heading', { name: 'Plumber' })).toBeVisible()
  await expect(page.getByText('House 1234, Sector 70 160071')).toBeVisible()
  console.log(`[phase-3 gate] app time for a full request on an emulated mid-range phone: ${seconds.toFixed(1)} s`)
  // Leaves 90 s of the 2-minute budget for reading and typing.
  expect(seconds).toBeLessThan(30)

  // The dashboard lists it as active.
  await page.goto(`${CUSTOMER}/`)
  await expect(page.getByRole('link', { name: /Plumber.*Waiting for quotes/ })).toBeVisible()
})
