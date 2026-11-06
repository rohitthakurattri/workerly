<script setup lang="ts">
import { onMounted, ref } from 'vue'
import type { Earnings } from '~/types/models'
import { ApiError } from '~/utils/api-error'
import { formatMoney } from '~/utils/money'

definePageMeta({ middleware: ['worker-profile'] })

const api = useApi()
const { t, locale } = useI18n()
const earnings = ref<Earnings | null>(null)
const error = ref<string | null>(null)

onMounted(async () => {
  try {
    earnings.value = (await api<{ data: Earnings }>('/worker/earnings')).data
  }
  catch (e) {
    error.value = ApiError.from(e).message
  }
})

const date = (iso: string) => new Intl.DateTimeFormat(locale.value, { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'Asia/Kolkata' }).format(new Date(iso))
</script>

<template>
  <div class="mx-auto flex max-w-2xl flex-col gap-4">
    <NuxtLink
      to="/"
      class="text-sm text-brand-700"
    >
      ← {{ t('earnings.back') }}
    </NuxtLink>
    <h1 class="text-2xl font-semibold">
      {{ t('earnings.title') }}
    </h1>
    <p
      v-if="error"
      class="text-danger"
      role="alert"
    >
      {{ error }}
    </p>
    <UiSkeleton
      v-else-if="!earnings"
      :lines="6"
    />
    <template v-else>
      <div class="grid gap-3 sm:grid-cols-3">
        <UiCard>
          <p class="text-sm text-ink-muted">
            {{ t('earnings.held') }}
          </p>
          <p
            class="text-xl font-semibold tabular-nums"
            data-testid="earnings-held"
          >
            {{ formatMoney(earnings.balance.held) }}
          </p>
          <p class="text-xs text-ink-muted">
            {{ t('earnings.heldHint') }}
          </p>
        </UiCard>
        <UiCard>
          <p class="text-sm text-ink-muted">
            {{ t('earnings.owed') }}
          </p>
          <p
            class="text-xl font-semibold tabular-nums"
            data-testid="earnings-owed"
          >
            {{ formatMoney(earnings.balance.owed) }}
          </p>
          <p class="text-xs text-ink-muted">
            {{ t('earnings.owedHint') }}
          </p>
        </UiCard>
        <UiCard>
          <p class="text-sm text-ink-muted">
            {{ earnings.balance.net.minor >= 0 ? t('earnings.nextPayout') : t('earnings.youOwe') }}
          </p>
          <p
            class="text-xl font-semibold tabular-nums"
            :class="earnings.balance.net.minor < 0 && 'text-danger'"
            data-testid="earnings-net"
          >
            {{ formatMoney({ ...earnings.balance.net, minor: Math.abs(earnings.balance.net.minor) }) }}
          </p>
        </UiCard>
      </div>

      <UiCard>
        <template #title>
          {{ t('earnings.jobs') }}
        </template>
        <UiEmptyState
          v-if="!earnings.jobs.length"
          :title="t('earnings.noJobs')"
        />
        <ul
          v-else
          class="flex flex-col divide-y divide-border"
        >
          <li
            v-for="j in earnings.jobs"
            :key="`${j.booking_id}-${j.paid_at}`"
            class="py-3"
          >
            <NuxtLink
              :to="`/jobs/${j.booking_id}`"
              class="flex items-start justify-between gap-3"
            >
              <span>
                <span class="font-medium">{{ j.category }}</span>
                <span class="block text-xs text-ink-muted">{{ date(j.paid_at) }} · {{ t(`pay.method.${j.method}`) }}</span>
              </span>
              <span class="text-right text-sm tabular-nums">
                <span class="block font-semibold">{{ formatMoney(j.earnings) }}</span>
                <span class="block text-xs text-ink-muted">{{ t('earnings.breakdown', { amount: formatMoney(j.amount), commission: formatMoney(j.commission) }) }}</span>
                <span
                  v-if="j.refunded.minor"
                  class="block text-xs text-warning"
                >{{ t('pay.refunded', { amount: formatMoney(j.refunded) }) }}</span>
              </span>
            </NuxtLink>
          </li>
        </ul>
      </UiCard>

      <UiCard>
        <template #title>
          {{ t('earnings.payouts') }}
        </template>
        <UiEmptyState
          v-if="!earnings.payouts.length"
          :title="t('earnings.noPayouts')"
        />
        <ul
          v-else
          class="flex flex-col divide-y divide-border text-sm"
        >
          <li
            v-for="p in earnings.payouts"
            :key="p.id"
            class="flex justify-between py-2"
          >
            <span>{{ date(p.paid_at) }}<span
              v-if="p.reference"
              class="text-ink-muted"
            > · {{ p.reference }}</span></span>
            <span class="font-medium tabular-nums">{{ formatMoney(p.amount) }}</span>
          </li>
        </ul>
      </UiCard>
    </template>
  </div>
</template>
