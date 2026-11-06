<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useAuthStore } from '~/stores/auth'
import type { AdminWorkerSummary } from '~/types/models'

definePageMeta({ middleware: ['role'], roles: ['admin', 'finance', 'support', 'verifier'] })
const auth = useAuthStore()
const api = useApi()
const { canViewWorkers, canViewRequests, canMoveMoney } = useStaff()
const { t } = useI18n()
const waiting = ref<number | null>(null)
const attention = ref<number | null>(null)
const bookingAttention = ref<number | null>(null)

onMounted(async () => {
  if (canViewRequests.value) {
    const res = await api<{ meta: { attention_count: number } }>('/admin/service_requests', { query: { 'filter[attention]': 'true', 'limit': 1 } })
    attention.value = res.meta.attention_count
    const bookings = await api<{ meta: { attention_count: number } }>('/admin/bookings', { query: { 'filter[attention]': 'true', 'limit': 1 } })
    bookingAttention.value = bookings.meta.attention_count
  }
  if (!canViewWorkers.value) return
  const res = await api<{ data: AdminWorkerSummary[], meta: { next_cursor: string | null } }>('/admin/workers', { query: { 'filter[status]': 'pending_review', 'limit': 100 } })
  waiting.value = res.data.length
})
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="flex items-center gap-3">
      <h1 class="text-2xl font-semibold">
        {{ t('admin.dashboard') }}
      </h1>
      <UiBadge tone="info">
        {{ t(`roles.${auth.activeRole}`) }}
      </UiBadge>
    </div>
    <div class="grid gap-4 sm:grid-cols-2">
      <UiCard v-if="canViewWorkers">
        <template #title>
          {{ t('admin.verificationQueue') }}
        </template>
        <p class="text-3xl font-bold tabular-nums">
          {{ waiting ?? '–' }}{{ waiting === 100 ? '+' : '' }}
        </p>
        <p class="mb-3 text-sm text-ink-muted">
          {{ t('admin.waitingForReview') }}
        </p>
        <NuxtLink
          to="/workers?status=pending_review"
          class="font-medium text-brand-700 underline"
        >
          {{ t('admin.openQueue') }}
        </NuxtLink>
      </UiCard>
      <UiCard v-if="canViewRequests">
        <template #title>
          {{ t('admin.needsAttention') }}
        </template>
        <p
          class="text-3xl font-bold tabular-nums"
          :class="{ 'text-danger': !!attention }"
        >
          {{ attention ?? '–' }}
        </p>
        <p class="mb-3 text-sm text-ink-muted">
          {{ t('admin.needsAttentionHint') }}
        </p>
        <NuxtLink
          to="/requests?tab=attention"
          class="font-medium text-brand-700 underline"
        >
          {{ t('admin.openRequests') }}
        </NuxtLink>
      </UiCard>
      <UiCard v-if="canViewRequests">
        <template #title>
          {{ t('admin.bookingsAttention') }}
        </template>
        <p
          class="text-3xl font-bold tabular-nums"
          :class="{ 'text-danger': !!bookingAttention }"
        >
          {{ bookingAttention ?? '–' }}
        </p>
        <NuxtLink
          to="/bookings?tab=attention"
          class="font-medium text-brand-700 underline"
        >
          {{ t('admin.openBookings') }}
        </NuxtLink>
      </UiCard>
      <UiCard v-if="canMoveMoney">
        <template #title>
          {{ t('admin.finance') }}
        </template>
        <p class="mb-3 text-sm text-ink-muted">
          {{ t('finance.dashboardHint') }}
        </p>
        <div class="flex flex-wrap gap-3">
          <NuxtLink
            to="/finance"
            class="text-sm font-medium text-brand-700"
          >
            {{ t('finance.tabs.balances') }} →
          </NuxtLink>
          <NuxtLink
            to="/finance?tab=reconciliation"
            class="text-sm font-medium text-brand-700"
          >
            {{ t('finance.tabs.reconciliation') }} →
          </NuxtLink>
          <NuxtLink
            to="/payments"
            class="text-sm font-medium text-brand-700"
          >
            {{ t('admin.payments') }} →
          </NuxtLink>
        </div>
      </UiCard>
      <UiCard v-if="!canViewWorkers && !canViewRequests && !canMoveMoney">
        <UiEmptyState
          :title="t('admin.emptyTitle')"
          :description="t('admin.emptyBody')"
        />
      </UiCard>
    </div>
  </div>
</template>
