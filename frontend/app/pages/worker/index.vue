<script setup lang="ts">
import { useAuthStore } from '~/stores/auth'

const auth = useAuthStore()
const { t } = useI18n()
</script>

<template>
  <div class="flex flex-col gap-6">
    <h1 class="text-2xl font-semibold">
      {{ t('home.greeting', { name: auth.user?.name || t('home.there') }) }}
    </h1>
    <UiCard v-if="auth.activeRole === 'worker'">
      <UiEmptyState
        :title="t('worker.noLeads')"
        :description="t('worker.noLeadsHint')"
      />
    </UiCard>
    <UiCard v-else>
      <template #title>
        {{ t('worker.becomeTitle') }}
      </template>
      <p class="text-ink-muted">
        {{ t('worker.becomeBody') }}
      </p>
      <UiBadge
        class="mt-3"
        tone="info"
      >
        {{ t('common.comingSoon') }}
      </UiBadge>
    </UiCard>
    <SharedProfileCard />
  </div>
</template>
