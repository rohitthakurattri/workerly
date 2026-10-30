<script setup lang="ts">
import { useAuthStore } from '~/stores/auth'

definePageMeta({ middleware: ['role'], roles: ['admin', 'finance', 'support', 'verifier'] })
const auth = useAuthStore()
const { t } = useI18n()
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
    <UiCard>
      <UiEmptyState
        :title="t('admin.emptyTitle')"
        :description="t('admin.emptyBody')"
      />
    </UiCard>
  </div>
</template>
