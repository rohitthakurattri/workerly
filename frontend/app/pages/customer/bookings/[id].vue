<script setup lang="ts">
import { onMounted, ref } from 'vue'
import type { CustomerBooking } from '~/types/models'
import { ApiError } from '~/utils/api-error'
import { formatMoney } from '~/utils/money'

definePageMeta({ middleware: ['role'], roles: ['customer'] })

const route = useRoute()
const { findBooking } = useQuotations()
const { t } = useI18n()
const booking = ref<CustomerBooking | null>(null)
const gone = ref(false)

onMounted(async () => {
  try {
    booking.value = await findBooking(String(route.params.id))
  }
  catch (e) {
    if (ApiError.from(e).status === 404) gone.value = true
    else throw e
  }
})
</script>

<template>
  <div class="mx-auto flex max-w-xl flex-col gap-4">
    <NuxtLink
      :to="booking ? `/requests/${booking.request_id}` : '/'"
      class="text-sm text-brand-700"
    >
      ← {{ t('compare.backToRequest') }}
    </NuxtLink>
    <UiEmptyState
      v-if="gone"
      :title="t('booking.notFound')"
    />
    <UiSkeleton
      v-else-if="!booking"
      :lines="6"
    />
    <template v-else>
      <div>
        <p
          class="text-sm font-medium text-success"
          data-testid="booking-confirmed"
        >
          ✓ {{ t('booking.title') }}
        </p>
        <h1 class="text-2xl font-semibold">
          {{ booking.category.name }}
        </h1>
      </div>
      <UiCard>
        <template #title>
          {{ t('booking.worker') }}
        </template>
        <CustomerWorkerSummary :worker="booking.worker" />
        <a
          v-if="booking.worker.phone"
          :href="`tel:${booking.worker.phone}`"
          class="mt-3 inline-flex h-11 items-center rounded-[var(--radius-control)] bg-brand-700 px-4 font-medium text-white"
        >📞 {{ t('booking.call', { name: booking.worker.name || booking.worker.phone }) }}</a>
      </UiCard>
      <UiCard>
        <template #title>
          {{ booking.kind === 'inspection' ? t('booking.visitFee') : t('booking.agreed') }}: {{ formatMoney(booking.approved_total) }}
        </template>
        <SharedQuoteBreakdown :revision="booking.revision" />
      </UiCard>
      <p class="text-sm text-ink-muted">
        {{ t('booking.whatNext', { name: booking.worker.name }) }}
      </p>
    </template>
  </div>
</template>
