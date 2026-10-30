<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, ref } from 'vue'
import { ApiError } from '~/utils/api-error'
import { normalizeIndianMobile, formatIndianMobile } from '~/utils/phone'

const emit = defineEmits<{ done: [] }>()
const { requestOtp, verifyOtp, verifyTotp, target } = useAuth()
const { t } = useI18n()

type Step = 'phone' | 'code' | 'totp'
const step = ref<Step>('phone')
const phoneInput = ref('')
const phone = ref('')
const code = ref('')
const totp = ref('')
const mfaToken = ref('')
const error = ref<string | null>(null)
const loading = ref(false)
const resendIn = ref(0)
let timer: ReturnType<typeof setInterval> | undefined
let webOtpAbort: AbortController | undefined

const normalized = computed(() => normalizeIndianMobile(phoneInput.value))

function startCountdown(seconds: number) {
  resendIn.value = seconds
  clearInterval(timer)
  timer = setInterval(() => {
    resendIn.value = Math.max(0, resendIn.value - 1)
    if (!resendIn.value) clearInterval(timer)
  }, 1000)
}

// Android Chrome can read the code from the SMS (it ends with "@workerly.in #123456").
async function listenForSms() {
  if (!import.meta.client || !('OTPCredential' in window)) return
  webOtpAbort?.abort()
  webOtpAbort = new AbortController()
  try {
    const cred = await navigator.credentials.get({ otp: { transport: ['sms'] }, signal: webOtpAbort.signal } as CredentialRequestOptions) as (Credential & { code?: string }) | null
    if (cred?.code) {
      code.value = cred.code
      await submitCode()
    }
  }
  catch { /* user dismissed or unsupported */ }
}

async function run(fn: () => Promise<void>) {
  error.value = null
  loading.value = true
  try {
    await fn()
  }
  catch (e) {
    const err = ApiError.from(e)
    error.value = err.code === 'otp_incorrect' && typeof err.details.attempts_left === 'number'
      ? t('auth.wrongCode', { n: err.details.attempts_left })
      : err.message
    if (err.details.retry_after) startCountdown(Number(err.details.retry_after))
  }
  finally {
    loading.value = false
  }
}

const sendCode = () => run(async () => {
  if (!normalized.value) {
    error.value = t('auth.invalidPhone')
    return
  }
  phone.value = normalized.value
  const res = await requestOtp(phone.value)
  step.value = 'code'
  code.value = ''
  startCountdown(res.resend_after)
  listenForSms()
  await nextTick()
  document.getElementById('otp-code')?.focus()
})

const submitCode = () => run(async () => {
  const mfa = await verifyOtp(phone.value, code.value)
  webOtpAbort?.abort()
  if (mfa) {
    mfaToken.value = mfa.mfaToken
    step.value = 'totp'
    return
  }
  emit('done')
})

const submitTotp = () => run(async () => {
  await verifyTotp(mfaToken.value, totp.value)
  emit('done')
})

function changeNumber() {
  step.value = 'phone'
  error.value = null
  webOtpAbort?.abort()
}

onBeforeUnmount(() => {
  clearInterval(timer)
  webOtpAbort?.abort()
})
</script>

<template>
  <form
    v-if="step === 'phone'"
    class="flex flex-col gap-4"
    novalidate
    @submit.prevent="sendCode"
  >
    <UiInput
      v-model="phoneInput"
      :label="t('auth.phoneLabel')"
      :hint="t('auth.phoneHint')"
      :error="error"
      type="tel"
      inputmode="numeric"
      autocomplete="tel-national"
      placeholder="98765 43210"
      maxlength="16"
      required
    >
      <template #prefix>
        +91
      </template>
    </UiInput>
    <UiButton
      type="submit"
      block
      :loading="loading"
      :disabled="!normalized"
    >
      {{ t('auth.sendCode') }}
    </UiButton>
  </form>

  <form
    v-else-if="step === 'code'"
    class="flex flex-col gap-4"
    novalidate
    @submit.prevent="submitCode"
  >
    <p class="text-sm text-ink-muted">
      {{ t('auth.codeSentTo', { phone: formatIndianMobile(phone) }) }}
      <button
        type="button"
        class="font-medium text-brand-700 underline"
        @click="changeNumber"
      >
        {{ t('auth.change') }}
      </button>
    </p>
    <UiInput
      id="otp-code"
      v-model="code"
      :label="t('auth.codeLabel')"
      :error="error"
      inputmode="numeric"
      autocomplete="one-time-code"
      pattern="\d{6}"
      maxlength="6"
      required
    />
    <UiButton
      type="submit"
      block
      :loading="loading"
      :disabled="code.length !== 6"
    >
      {{ t('auth.verify') }}
    </UiButton>
    <UiButton
      variant="ghost"
      :disabled="resendIn > 0 || loading"
      @click="sendCode"
    >
      {{ resendIn > 0 ? t('auth.resendIn', { s: resendIn }) : t('auth.resend') }}
    </UiButton>
  </form>

  <form
    v-else
    class="flex flex-col gap-4"
    novalidate
    @submit.prevent="submitTotp"
  >
    <p class="text-sm text-ink-muted">
      {{ t('auth.totpHelp') }}
    </p>
    <UiInput
      v-model="totp"
      :label="t('auth.totpLabel')"
      :error="error"
      inputmode="numeric"
      autocomplete="one-time-code"
      maxlength="6"
      required
    />
    <UiButton
      type="submit"
      block
      :loading="loading"
      :disabled="totp.length !== 6"
    >
      {{ t('auth.verify') }}
    </UiButton>
  </form>

  <p
    v-if="target.scope === 'staff' && step === 'phone'"
    class="mt-4 text-center text-xs text-ink-subtle"
  >
    {{ t('auth.staffOnly') }}
  </p>
</template>
