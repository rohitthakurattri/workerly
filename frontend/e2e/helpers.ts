import { execFileSync } from 'node:child_process'
import type { Page } from '@playwright/test'
import { createHmac } from 'node:crypto'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const backend = resolve(import.meta.dirname, '../../backend')

export interface Seed {
  phones: { dual: string, admin: string, logout: string, fresh: string, new_worker: string, customer: string }
  totp_secret: string
  camera_photo: string
}

export function seed(): Seed {
  const out = execFileSync('bin/rails', ['runner', 'script/e2e_seed.rb'], { cwd: backend, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] })
  return JSON.parse(out.trim().split('\n').pop()!)
}

/** Waits for the fake SMS adapter to write a code for `phone` after `since`. */
export async function otpFor(phone: string, since: Date): Promise<string> {
  for (let i = 0; i < 40; i++) {
    const lines = (() => {
      try {
        return readFileSync(resolve(backend, 'log/fake_sms.log'), 'utf8').trim().split('\n')
      }
      catch {
        return []
      }
    })()
    for (const line of lines.reverse()) {
      const [ts, to, code] = line.split(' ')
      if (to === phone && new Date(ts!) >= new Date(since.getTime() - 1000)) return code!
    }
    await new Promise(r => setTimeout(r, 250))
  }
  throw new Error(`No OTP for ${phone} (is Sidekiq running?)`)
}

/** RFC 6238 TOTP, SHA-1, 6 digits, 30 s. */
export function totp(base32: string, at = Date.now()): string {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'
  let bits = ''
  for (const c of base32.replace(/=+$/, '')) bits += alphabet.indexOf(c).toString(2).padStart(5, '0')
  const key = Buffer.from(bits.match(/.{8}/g)!.map(b => Number.parseInt(b, 2)))
  const counter = Buffer.alloc(8)
  counter.writeBigUInt64BE(BigInt(Math.floor(at / 30_000)))
  const h = createHmac('sha1', key).update(counter).digest()
  const o = h[h.length - 1]! & 0xF
  return String((h.readUInt32BE(o) & 0x7FFFFFFF) % 1_000_000).padStart(6, '0')
}

/** Consumer OTP login on one of the apps (customer :3001 or worker :3002). */
export async function login(page: Page, base: string, phone: string) {
  await page.goto(`${base}/login`)
  await page.getByLabel('Mobile number').fill(phone.replace('+91', ''))
  const since = new Date()
  await page.getByRole('button', { name: 'Send code' }).click()
  await page.getByLabel('6-digit code').fill(await otpFor(phone, since))
  await page.getByRole('button', { name: 'Continue' }).click()
}
