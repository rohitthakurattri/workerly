<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import type { AdminPayment } from '~/types/models'
import { ApiError } from '~/utils/api-error'
import { randomKey } from '~/utils/id'
import { formatMoney } from '~/utils/money'
import { paymentTone, toMinor } from '~/utils/payments'

definePageMeta({ middleware: ['role'], roles: ['admin', 'finance', 'support'] })

const STATUSES = ['', 'captured', 'created', 'failed', 'partially_refunded', 'refunded', 'amount_mismatch'] as const
const METHODS = ['', 'online', 'cash'] as const

const api = useApi()
const toast = useToast()
const { t } = useI18n()
const { canMoveMoney } = useStaff()

const status = ref<string>('')
const method = ref<string>('')
const rows = ref<AdminPayment[] | null>(null)
const cursor = ref<string | null>(null)
const loading = ref(false)

const refunding = ref<AdminPayment | null>(null)
const refundAmount = ref('')
const refundReason = ref('')
const busy = ref(false)
// One key per refund decision; kept after a failure so a retry can't refund twice.
let refundKey = ''

async function load(reset = true) {
  loading.value = true
  try {
    const res = await api<{ data: AdminPayment[], meta: { next_cursor: string | null } }>('/admin/payments', {
      query: {
        ...(status.value ? { 'filter[status]': status.value } : {}),
        ...(method.value ? { 'filter[method]': method.value } : {}),
        ...(reset ? {} : { cursor: cursor.value }),
      },
    })
    rows.value = reset ? res.data : [...(rows.value ?? []), ...res.data]
    cursor.value = res.meta.next_cursor
  }
  catch (e) {
    toast.error(ApiError.from(e).message)
  }
  finally {
    loading.value = false
  }
}
watch([status, method], () => load(), { immediate: true })

function openRefund(p: AdminPayment) {
  refunding.value = p
  refundAmount.value = String(p.refundable.minor / 100)
  refundReason.value = ''
  refundKey = randomKey()
}
const refundMinor = computed(() => toMinor(refundAmount.value))
const refundError = computed(() => {
  if (!refunding.value || !refundAmount.value) return null
  if (refundMinor.value === null) return t('finance.invalidAmount')
  if (refundMinor.value > refunding.value.refundable.minor) return t('finance.refundTooMuch', { amount: formatMoney(refunding.value.refundable) })
  return null
})

async function refund() {
  if (!refunding.value || refundMinor.value === null || refundError.value) return
  busy.value = true
  try {
    await api(`/admin/payments/${refunding.value.id}/refunds`, {
      method: 'POST',
      body: { amount_minor: refundMinor.value, reason: refundReason.value.trim() },
      headers: { 'Idempotency-Key': refundKey },
    })
    toast.success(t('finance.refundStarted'))
    refunding.value = null
    await load()
  }
  catch (e) {
    toast.error(ApiError.from(e).message)
  }
  finally {
    busy.value = false
  }
}

const fmt = (iso?: string | null) => (iso ? new Date(iso).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }) : '–')
</script>

<template>
  <div class="flex flex-col gap-4">
    <h1 class="text-2xl font-semibold">
      {{ t('admin.payments') }}
    </h1>
    <div class="flex flex-wrap gap-3">
      <UiSelect
        v-model="status"
        :label="t('finance.status')"
        :options="STATUSES.map(s => ({ value: s, label: s ? t(`paymentStatus.${s}`) : t('finance.any') }))"
      />
      <UiSelect
        v-model="method"
        :label="t('finance.method')"
        :options="METHODS.map(m => ({ value: m, label: m ? t(`pay.method.${m}`) : t('finance.any') }))"
      />
    </div>
    <UiSkeleton
      v-if="rows === null"
      :lines="5"
    />
    <UiEmptyState
      v-else-if="!rows.length"
      :title="t('finance.noPayments')"
    />
    <ul
      v-else
      class="flex flex-col gap-3"
    >
      <li
        v-for="p in rows"
        :key="p.id"
      >
        <UiCard>
          <div class="flex flex-wrap items-start justify-between gap-3">
            <div class="flex flex-col gap-1">
              <p class="flex items-center gap-2 font-medium">
                {{ formatMoney(p.amount) }}
                <UiBadge :tone="paymentTone(p.status)">
                  {{ t(`paymentStatus.${p.status}`) }}
                </UiBadge>
                <span class="text-sm font-normal text-ink-muted">{{ t(`pay.method.${p.method}`) }} · {{ p.provider }}</span>
              </p>
              <p class="text-sm text-ink-muted">
                {{ p.customer_name || '–' }} → {{ p.worker_name || '–' }} · {{ fmt(p.captured_at || p.created_at) }}
              </p>
              <p
                v-if="p.commission"
                class="text-sm"
              >
                {{ t('finance.split', { commission: formatMoney(p.commission), worker: p.worker_share ? formatMoney(p.worker_share) : '–' }) }}
              </p>
              <ul
                v-if="p.refunds.length"
                class="text-sm"
              >
                <li
                  v-for="r in p.refunds"
                  :key="r.id"
                >
                  ↩ {{ formatMoney(r.amount) }} · {{ t(`refundStatus.${r.status}`) }}<template v-if="r.reason">
                    · {{ r.reason }}
                  </template>
                </li>
              </ul>
            </div>
            <div class="flex gap-2">
              <NuxtLink
                :to="`/bookings/${p.booking_id}`"
                class="inline-flex h-9 items-center rounded-[var(--radius-control)] border border-border px-3 text-sm"
              >
                {{ t('admin.booking') }}
              </NuxtLink>
              <UiButton
                v-if="canMoveMoney && p.method === 'online' && p.refundable.minor > 0"
                size="sm"
                variant="secondary"
                data-testid="refund"
                @click="openRefund(p)"
              >
                {{ t('finance.refund') }}
              </UiButton>
            </div>
          </div>
        </UiCard>
      </li>
    </ul>
    <div v-if="cursor">
      <UiButton
        variant="secondary"
        :loading="loading"
        @click="load(false)"
      >
        {{ t('admin.loadMore') }}
      </UiButton>
    </div>

    <UiModal
      :open="!!refunding"
      :title="t('finance.refundTitle')"
      @update:open="v => { if (!v) refunding = null }"
    >
      <form
        v-if="refunding"
        class="flex flex-col gap-4"
        @submit.prevent="refund"
      >
        <p class="text-sm text-ink-muted">
          {{ t('finance.refundOnlineHint') }}
        </p>
        <UiInput
          v-model="refundAmount"
          :label="t('finance.refundAmount', { max: formatMoney(refunding.refundable) })"
          inputmode="decimal"
          :error="refundError"
          required
        />
        <UiInput
          v-model="refundReason"
          :label="t('finance.reason')"
          maxlength="500"
          required
        />
        <div class="flex justify-end gap-2">
          <UiButton
            variant="ghost"
            @click="refunding = null"
          >
            {{ t('common.cancel') }}
          </UiButton>
          <UiButton
            type="submit"
            variant="danger"
            :disabled="refundMinor === null || !!refundError || !refundReason.trim()"
            :loading="busy"
          >
            {{ refundMinor ? t('finance.refundConfirm', { amount: formatMoney({ minor: refundMinor, currency: refunding.amount.currency }) }) : t('finance.refund') }}
          </UiButton>
        </div>
      </form>
    </UiModal>
  </div>
</template>
