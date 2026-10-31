<script setup lang="ts">
import type { Quotation } from '~/types/models'
import { formatMoney } from '~/utils/money'
import { bestWarranty } from '~/utils/quotes'

// Side by side, one column per quote (at most 5), scrolls sideways on a phone.
defineProps<{ quotes: Quotation[], requestId: string }>()
const { t } = useI18n()
const duration = useDuration()
</script>

<template>
  <div class="overflow-x-auto">
    <table
      class="w-full min-w-[32rem] border-collapse text-sm"
      data-testid="quote-compare"
    >
      <caption class="sr-only">
        {{ t('compare.table') }}
      </caption>
      <thead>
        <tr>
          <th
            scope="col"
            class="w-28 p-2 text-left text-ink-muted"
          >
            {{ t('compare.worker') }}
          </th>
          <th
            v-for="q in quotes"
            :key="q.id"
            scope="col"
            class="p-2 text-left align-top"
          >
            <NuxtLink
              :to="`/requests/${requestId}/quotes/${q.id}`"
              class="font-semibold text-brand-700"
            >
              {{ q.worker.name }}
            </NuxtLink>
          </th>
        </tr>
      </thead>
      <tbody class="divide-y divide-border">
        <tr>
          <th
            scope="row"
            class="p-2 text-left font-normal text-ink-muted"
          >
            {{ t('compare.price') }}
          </th>
          <td
            v-for="q in quotes"
            :key="q.id"
            class="p-2 text-base font-semibold"
          >
            {{ formatMoney(q.revision.total) }}
          </td>
        </tr>
        <tr>
          <th
            scope="row"
            class="p-2 text-left font-normal text-ink-muted"
          >
            {{ t('compare.type') }}
          </th>
          <td
            v-for="q in quotes"
            :key="q.id"
            class="p-2"
          >
            {{ t(`compare.${q.kind}`) }}
          </td>
        </tr>
        <tr>
          <th
            scope="row"
            class="p-2 text-left font-normal text-ink-muted"
          >
            {{ t('compare.time') }}
          </th>
          <td
            v-for="q in quotes"
            :key="q.id"
            class="p-2"
          >
            {{ duration(q.revision.estimated_minutes) || '—' }}
          </td>
        </tr>
        <tr>
          <th
            scope="row"
            class="p-2 text-left font-normal text-ink-muted"
          >
            {{ t('compare.warrantyRow') }}
          </th>
          <td
            v-for="q in quotes"
            :key="q.id"
            class="p-2"
          >
            {{ bestWarranty(q) ? t('compare.warranty', { days: bestWarranty(q) }) : t('compare.noWarranty') }}
          </td>
        </tr>
        <tr>
          <th
            scope="row"
            class="p-2 text-left font-normal text-ink-muted"
          >
            {{ t('compare.ratingRow') }}
          </th>
          <td
            v-for="q in quotes"
            :key="q.id"
            class="p-2"
          >
            {{ q.worker.rating_avg != null ? t('compare.rating', { rating: q.worker.rating_avg.toFixed(1), count: q.worker.rating_count }) : t('compare.newWorker') }}
          </td>
        </tr>
        <tr>
          <th
            scope="row"
            class="p-2 text-left font-normal text-ink-muted"
          >
            {{ t('compare.jobsRow') }}
          </th>
          <td
            v-for="q in quotes"
            :key="q.id"
            class="p-2"
          >
            {{ q.worker.jobs_done }}
          </td>
        </tr>
        <tr>
          <th
            scope="row"
            class="p-2 text-left font-normal text-ink-muted"
          >
            {{ t('compare.distanceRow') }}
          </th>
          <td
            v-for="q in quotes"
            :key="q.id"
            class="p-2"
          >
            {{ t(`distance.${q.distance_band}`) }}
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
