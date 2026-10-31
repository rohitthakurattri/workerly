<script setup lang="ts">
import { computed } from 'vue'
import type { Quotation } from '~/types/models'
import { formatMoney } from '~/utils/money'
import { bestWarranty, quoteStatusTone } from '~/utils/quotes'

const props = defineProps<{ quote: Quotation, requestId: string }>()
const { t } = useI18n()
const duration = useDuration()
const warranty = computed(() => bestWarranty(props.quote))
</script>

<template>
  <NuxtLink
    :to="`/requests/${requestId}/quotes/${quote.id}`"
    class="flex flex-col gap-3 rounded-[var(--radius-card)] border bg-surface p-4 hover:border-brand-600"
    :class="quote.status === 'accepted' ? 'border-success' : 'border-border'"
    data-testid="quote-card"
  >
    <CustomerWorkerSummary
      :worker="quote.worker"
      :distance-band="quote.distance_band"
    />
    <div class="flex items-end justify-between gap-3">
      <div class="flex flex-wrap gap-1">
        <UiBadge :tone="quote.kind === 'inspection' ? 'warning' : 'info'">
          {{ t(`compare.${quote.kind}`) }}
        </UiBadge>
        <UiBadge
          v-if="quote.status !== 'submitted'"
          :tone="quoteStatusTone(quote.status)"
        >
          {{ t(`quoteStatus.${quote.status}`) }}
        </UiBadge>
        <UiBadge v-if="quote.revised">
          {{ t('compare.revised') }}
        </UiBadge>
      </div>
      <strong
        class="text-2xl"
        data-testid="quote-price"
      >{{ formatMoney(quote.revision.total) }}</strong>
    </div>
    <p class="text-sm text-ink-muted">
      <template v-if="quote.kind === 'fixed'">
        {{ t('compare.lines', { count: quote.revision.items.length }, quote.revision.items.length) }}
      </template>
      <template v-else>
        {{ t('compare.inspectionNote') }}
      </template>
      <template v-if="quote.revision.estimated_minutes">
        · {{ t('compare.estimate', { time: duration(quote.revision.estimated_minutes) }) }}
      </template>
      <template v-if="warranty">
        · {{ t('compare.warranty', { days: warranty }) }}
      </template>
    </p>
  </NuxtLink>
</template>
