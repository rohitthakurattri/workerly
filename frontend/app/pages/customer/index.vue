<script setup lang="ts">
import { useAuthStore } from '~/stores/auth'

// Public landing page (SSR); shows the dashboard once the session is restored on the client.
definePageMeta({ public: true })
const auth = useAuthStore()
const { t } = useI18n()
</script>

<template>
  <div class="flex flex-col gap-6">
    <template v-if="auth.isLoggedIn">
      <h1 class="text-2xl font-semibold">
        {{ t('home.greeting', { name: auth.user?.name || t('home.there') }) }}
      </h1>
      <UiCard>
        <UiEmptyState
          :title="t('customer.noRequests')"
          :description="t('customer.noRequestsHint')"
        >
          <UiBadge tone="info">
            {{ t('common.comingSoon') }}
          </UiBadge>
        </UiEmptyState>
      </UiCard>
      <SharedProfileCard />
    </template>
    <template v-else>
      <section class="py-10 text-center">
        <h1 class="text-3xl font-bold">
          {{ t('customer.heroTitle') }}
        </h1>
        <p class="mx-auto mt-3 max-w-md text-ink-muted">
          {{ t('customer.heroBody') }}
        </p>
        <UiButton
          class="mt-6"
          size="lg"
          @click="navigateTo('/login')"
        >
          {{ t('auth.getStarted') }}
        </UiButton>
      </section>
    </template>
  </div>
</template>
