<script setup lang="ts">
import { computed, ref } from 'vue'
import type { CustomerBooking, PaymentOrder } from '~/types/models'
import { ApiError } from '~/utils/api-error'
import { randomKey } from '~/utils/id'
import { formatMoney } from '~/utils/money'
import { paymentTone } from '~/utils/payments'
import type { CheckoutResult } from '~/composables/usePayments'

/** What's owed, the Pay button, and what's been paid so far. */
const props = defineProps<{ booking: CustomerBooking }>()
const emit = defineEmits<{ paid: [] }>()

const { createOrder, razorpayCheckout, fakeCheckout, confirm } = usePayments()
const toast = useToast()
const { t } = useI18n()

const busy = ref(false)
const waiting = ref(false)
const fakeOrder = ref<PaymentOrder | null>(null)
// One key per attempt: a retried tap reuses the same order instead of opening a second one.
let key = ''

const paidSome = computed(() => props.booking.paid.minor > 0)

async function pay() {
  busy.value = true
  key ||= randomKey()
  try {
    const order = await createOrder(props.booking.id, key)
    if (order.checkout.provider === 'fake') {
      fakeOrder.value = order // the dev modal below plays the gateway
      return
    }
    await finish(order, await razorpayCheckout(order))
  }
  catch (e) {
    if ((e as Error).message === 'cancelled') return
    if ((e as Error).message === 'checkout_unavailable') toast.error(t('pay.checkoutUnavailable'))
    else toast.error(ApiError.from(e).message)
  }
  finally {
    busy.value = false
  }
}

async function fake(fail: boolean) {
  const order = fakeOrder.value!
  fakeOrder.value = null
  busy.value = true
  try {
    await finish(order, await fakeCheckout(order, fail))
  }
  catch (e) {
    toast.error(ApiError.from(e).message)
  }
  finally {
    busy.value = false
  }
}

async function finish(order: PaymentOrder, result: CheckoutResult) {
  waiting.value = true
  try {
    const p = await confirm(order, result)
    if (p.status === 'captured') {
      key = ''
      toast.success(t('pay.success'))
    }
    else if (p.status === 'failed') {
      key = ''
      toast.error(t('pay.failed'))
    }
    else {
      toast.show(t('pay.processing'))
    }
    emit('paid')
  }
  finally {
    waiting.value = false
  }
}
</script>

<template>
  <UiCard
    v-if="booking.payable || paidSome"
    :class="booking.payable && 'border-brand-700'"
    data-testid="pay-card"
  >
    <template #title>
      <template v-if="booking.payable">
        {{ t('pay.due') }}: <span data-testid="outstanding">{{ formatMoney(booking.outstanding) }}</span>
      </template>
      <template v-else>
        ✓ {{ t('pay.paidInFull') }}
      </template>
    </template>
    <div
      v-if="booking.payable"
      class="flex flex-col gap-2"
    >
      <p class="text-sm text-ink-muted">
        {{ t('pay.hint', { name: booking.worker.name || '' }) }}
      </p>
      <UiButton
        size="lg"
        :loading="busy || waiting"
        data-testid="pay-now"
        @click="pay"
      >
        {{ waiting ? t('pay.confirming') : t('pay.payNow', { amount: formatMoney(booking.outstanding) }) }}
      </UiButton>
    </div>
    <ul
      v-if="booking.payments.length"
      class="mt-3 flex flex-col gap-1 text-sm"
    >
      <li
        v-for="p in booking.payments"
        :key="p.id"
        class="flex items-center justify-between gap-2"
      >
        <span>{{ t(`pay.method.${p.method}`) }}<template v-if="p.refunded.minor"> · {{ t('pay.refunded', { amount: formatMoney(p.refunded) }) }}</template></span>
        <span class="flex items-center gap-2">
          <UiBadge :tone="paymentTone(p.status)">{{ t(`paymentStatus.${p.status}`) }}</UiBadge>
          {{ formatMoney(p.amount) }}
        </span>
      </li>
    </ul>
    <NuxtLink
      v-if="booking.invoice_number"
      :to="`/bookings/${booking.id}/invoice`"
      class="mt-3 inline-block text-sm text-brand-700"
      data-testid="invoice-link"
    >
      {{ t('invoice.view', { number: booking.invoice_number }) }} →
    </NuxtLink>

    <UiModal
      :open="!!fakeOrder"
      :title="t('pay.fakeTitle')"
      @update:open="v => { if (!v) fakeOrder = null }"
    >
      <div class="flex flex-col gap-4">
        <p class="text-sm text-ink-muted">
          {{ t('pay.fakeBody') }}
        </p>
        <div class="flex justify-end gap-2">
          <UiButton
            variant="danger"
            data-testid="fake-fail"
            @click="fake(true)"
          >
            {{ t('pay.fakeFail') }}
          </UiButton>
          <UiButton
            data-testid="fake-pay"
            @click="fake(false)"
          >
            {{ t('pay.fakePay', { amount: fakeOrder ? formatMoney({ minor: fakeOrder.checkout.amount, currency: fakeOrder.checkout.currency }) : '' }) }}
          </UiButton>
        </div>
      </div>
    </UiModal>
  </UiCard>
</template>
