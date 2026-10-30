import { expect, test, type Page } from '@playwright/test'
import { otpFor, seed, totp, type Seed } from './helpers'

const URLS = { customer: 'http://localhost:3001', worker: 'http://localhost:3002', admin: 'http://localhost:3003' }
let data: Seed

test.beforeAll(() => {
  data = seed()
})

async function loginWithOtp(page: Page, base: string, phone: string) {
  await page.goto(`${base}/login`)
  await page.getByLabel('Mobile number').fill(phone.replace('+91', ''))
  const since = new Date()
  await page.getByRole('button', { name: 'Send code' }).click()
  await page.getByLabel('6-digit code').fill(await otpFor(phone, since))
  await page.getByRole('button', { name: 'Continue' }).click()
}

test('customer logs in, then switches to the worker app without logging in again', async ({ page }) => {
  await loginWithOtp(page, URLS.customer, data.phones.dual)
  await expect(page.getByText('No requests yet')).toBeVisible()

  await page.getByRole('group', { name: 'Switch role' }).getByRole('button', { name: 'Worker' }).click()
  await expect(page).toHaveURL(`${URLS.worker}/`)
  await expect(page.getByText('No leads yet')).toBeVisible()
  await expect(page.getByRole('button', { name: 'Worker', pressed: true })).toBeVisible()
})

test('a new user on the worker app is a customer until they register as a worker', async ({ page }) => {
  await loginWithOtp(page, URLS.worker, data.phones.fresh)
  await expect(page.getByText('Become a Workerly Pro')).toBeVisible()
})

test('admin logs in with OTP + TOTP and switches staff role', async ({ page }) => {
  await loginWithOtp(page, URLS.admin, data.phones.admin)
  await page.getByLabel('Authenticator code').fill(totp(data.totp_secret))
  await page.getByRole('button', { name: 'Continue' }).click()

  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible()
  await page.getByRole('button', { name: 'Support' }).click()
  await expect(page.getByRole('button', { name: 'Support', pressed: true })).toBeVisible()
})

test('logout ends the session and a reload stays logged out', async ({ page }) => {
  await loginWithOtp(page, URLS.customer, data.phones.logout)
  await expect(page.getByText('No requests yet')).toBeVisible()
  await page.getByRole('button', { name: 'Log out' }).click()
  await expect(page).toHaveURL(/\/login$/)
  await page.goto(`${URLS.customer}/`)
  await expect(page.getByRole('button', { name: 'Get started' })).toBeVisible()
})

test('logged-out users are sent to login', async ({ page }) => {
  await page.goto(`${URLS.worker}/`)
  await expect(page).toHaveURL(/\/login/)
})
