<script setup lang="ts">
import { ref, watch } from 'vue'
import type { ServiceRequestSummary } from '~/types/models'
import { useAuthStore } from '~/stores/auth'

// Public landing page (SSR); shows the dashboard once the session is restored on the client.
definePageMeta({ public: true })
const auth = useAuthStore()
const { list } = useServiceRequest()
const { t } = useI18n()

const drafts = ref<ServiceRequestSummary[]>([])
const active = ref<ServiceRequestSummary[]>([])
const past = ref<ServiceRequestSummary[] | null>(null)
const loading = ref(true)

watch(() => auth.isLoggedIn && auth.activeRole === 'customer', async (ready) => {
  if (!ready) return
  const [d, a] = await Promise.all([list('draft'), list('active')])
  drafts.value = d.data
  active.value = a.data
  loading.value = false
}, { immediate: true })

async function showPast() {
  past.value = (await list('past')).data
}
</script>

<template>
  <div class="flex flex-col gap-6">
    <template v-if="auth.isLoggedIn">
      <section class="flex flex-col gap-3 rounded-[var(--radius-card)] bg-brand-700 p-5 text-white">
        <h1 class="text-2xl font-semibold">
          {{ t('home.greeting', { name: auth.user?.name || t('home.there') }) }}
        </h1>
        <p class="text-brand-50">
          {{ t('customer.ctaBody') }}
        </p>
        <UiButton
          size="lg"
          variant="secondary"
          class="self-start"
          @click="navigateTo('/requests/new')"
        >
          {{ t('customer.newRequest') }}
        </UiButton>
      </section>

      <UiSkeleton
        v-if="loading"
        :lines="3"
      />
      <template v-else>
        <section
          v-if="drafts.length"
          class="flex flex-col gap-2"
        >
          <h2 class="font-semibold">
            {{ t('customer.unfinished') }}
          </h2>
          <CustomerRequestCard
            v-for="r in drafts"
            :key="r.id"
            :request="r"
          />
        </section>
        <section class="flex flex-col gap-2">
          <h2 class="font-semibold">
            {{ t('customer.activeRequests') }}
          </h2>
          <UiCard v-if="!active.length">
            <UiEmptyState
              :title="t('customer.noRequests')"
              :description="t('customer.noRequestsHint')"
            />
          </UiCard>
          <CustomerRequestCard
            v-for="r in active"
            :key="r.id"
            :request="r"
          />
        </section>
        <section class="flex flex-col gap-2">
          <UiButton
            v-if="!past"
            variant="ghost"
            class="self-start"
            @click="showPast"
          >
            {{ t('customer.showPast') }}
          </UiButton>
          <template v-else>
            <h2 class="font-semibold">
              {{ t('customer.pastRequests') }}
            </h2>
            <p
              v-if="!past.length"
              class="text-sm text-ink-muted"
            >
              {{ t('customer.noPast') }}
            </p>
            <CustomerRequestCard
              v-for="r in past"
              :key="r.id"
              :request="r"
            />
          </template>
        </section>
      </template>
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
