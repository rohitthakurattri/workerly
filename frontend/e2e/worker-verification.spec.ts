import { resolve } from 'node:path'
import { expect, test, type Page } from '@playwright/test'
import { otpFor, seed, totp, type Seed } from './helpers'

// Phase 2 exit gate: a new worker onboards, an admin approves them, and only then do they reach leads.
const WORKER = 'http://localhost:3002'
const ADMIN = 'http://localhost:3003'
const files = resolve(import.meta.dirname, '../../backend/spec/fixtures/files')
let data: Seed

test.beforeAll(() => {
  data = seed()
})

async function login(page: Page, base: string, phone: string) {
  await page.goto(`${base}/login`)
  await page.getByLabel('Mobile number').fill(phone.replace('+91', ''))
  const since = new Date()
  await page.getByRole('button', { name: 'Send code' }).click()
  await page.getByLabel('6-digit code').fill(await otpFor(phone, since))
  await page.getByRole('button', { name: 'Continue' }).click()
}

test('worker onboards, admin approves, worker gets access to leads', async ({ browser }) => {
  const workerCtx = await browser.newContext()
  const worker = await workerCtx.newPage()
  const phone = data.phones.new_worker

  // 1. Register as a worker
  await login(worker, WORKER, phone)
  await expect(worker.getByText('Become a Workerly Pro')).toBeVisible()
  await worker.getByLabel('Full name').fill('Harpreet Singh')
  await worker.getByRole('button', { name: 'Start registration' }).click()
  await expect(worker).toHaveURL(`${WORKER}/onboarding`)

  // 2. About you
  await worker.getByTestId('photo-input').setInputFiles(resolve(files, 'photo.png'))
  await worker.getByLabel('Years of experience').fill('6')
  await worker.getByLabel('About your work').fill('Bathroom fittings and leak repair')
  await worker.getByRole('button', { name: 'Save and continue' }).click()

  // 3. Skills
  await worker.getByRole('checkbox', { name: 'Plumber' }).check()
  await worker.getByRole('button', { name: 'Save and continue' }).click()

  // 4. Service area (city centre + default radius)
  await worker.getByRole('button', { name: 'Add area' }).click()
  await expect(worker.getByText('within 5 km')).toBeVisible()
  await worker.getByRole('button', { name: 'Continue', exact: true }).click()

  // 5. Documents
  const identity = worker.getByTestId('doc-identity')
  await identity.getByLabel('Document type').selectOption('pan')
  await identity.getByLabel('Last 4 digits/letters of the number').fill('234F')
  await identity.getByTestId('file-identity').setInputFiles(resolve(files, 'id.jpg'))
  await identity.getByRole('button', { name: 'Upload' }).click()
  await expect(identity.getByText('Under review')).toBeVisible()

  const address = worker.getByTestId('doc-address')
  await address.getByLabel('Document type').selectOption('utility_bill')
  await address.getByTestId('file-address').setInputFiles(resolve(files, 'address.pdf'))
  await address.getByRole('button', { name: 'Upload' }).click()
  await expect(address.getByText('Under review')).toBeVisible()
  await worker.getByRole('button', { name: 'Continue', exact: true }).click()

  // 6. Submit
  await worker.getByRole('button', { name: 'Submit for verification' }).last().click()
  await expect(worker).toHaveURL(`${WORKER}/verification`)
  await expect(worker.getByText('We\'re reviewing your profile')).toBeVisible()

  // The API refuses leads until approval.
  const denied = await worker.evaluate(async () => {
    const r = await fetch('http://localhost:3000/api/v1/auth/refresh', { method: 'POST', credentials: 'include', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ role: 'worker' }) })
    const token = (await r.json()).data.access_token
    const leads = await fetch('http://localhost:3000/api/v1/worker/leads', { headers: { Authorization: `Bearer ${token}` } })
    return [leads.status, (await leads.json()).error.code]
  })
  expect(denied).toEqual([403, 'worker_not_verified'])

  // 7. Admin reviews and approves
  const adminCtx = await browser.newContext()
  const admin = await adminCtx.newPage()
  await login(admin, ADMIN, data.phones.admin)
  await admin.getByLabel('Authenticator code').fill(totp(data.totp_secret))
  await admin.getByRole('button', { name: 'Continue' }).click()
  await admin.getByRole('link', { name: 'Open queue' }).click()
  await admin.getByRole('link', { name: 'Harpreet Singh' }).first().click()

  await admin.getByTestId('review-identity').getByRole('button', { name: 'Looks valid' }).click()
  await admin.getByTestId('review-address').getByRole('button', { name: 'Looks valid' }).click()
  await admin.getByRole('button', { name: 'Approve worker' }).click()
  await admin.getByRole('dialog').getByRole('button', { name: 'Confirm' }).click()
  await expect(admin.getByText('Worker approved')).toBeVisible()
  await expect(admin.getByText('Approved', { exact: true }).first()).toBeVisible()

  // 8. Worker now lands on leads and can go available
  await worker.goto(`${WORKER}/verification`)
  await expect(worker).toHaveURL(`${WORKER}/`)
  await expect(worker.getByText('No leads yet')).toBeVisible()
  await worker.getByRole('switch', { name: 'Available for jobs' }).click()
  await expect(worker.getByText('You\'re available for jobs')).toBeVisible()

  // 9. The decision is in the audit log
  await admin.getByRole('link', { name: 'Audit log' }).click()
  await expect(admin.getByText('worker.verification.approved').first()).toBeVisible()
})
