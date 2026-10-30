<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useAuthStore } from '~/stores/auth'
import type { AdminWorkerSummary } from '~/types/models'

definePageMeta({ middleware: ['role'], roles: ['admin', 'finance', 'support', 'verifier'] })
const auth = useAuthStore()
const api = useApi()
const { canViewWorkers } = useStaff()
const { t } = useI18n()
const waiting = ref<number | null>(null)

onMounted(async () => {
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
      <UiCard v-else>
        <UiEmptyState
          :title="t('admin.emptyTitle')"
          :description="t('admin.emptyBody')"
        />
      </UiCard>
    </div>
  </div>
</template>
