<script setup lang="ts">
import { computed } from 'vue'
import type { QuotationRevision } from '~/types/models'
import { formatMoney } from '~/utils/money'

const props = defineProps<{ revision: QuotationRevision }>()
const { t } = useI18n()
const fmt = (m: { minor: number, currency: string }) => formatMoney(m)
const qty = (n: number) => (Number.isInteger(n) ? String(n) : String(Number(n.toFixed(3))))
const hasTax = computed(() => props.revision.tax_rate_bps > 0)
</script>

<template>
  <div class="flex flex-col gap-3">
    <ul
      class="flex flex-col divide-y divide-border"
      data-testid="quote-items"
    >
      <li
        v-for="(item, i) in revision.items"
        :key="i"
        class="flex justify-between gap-3 py-2"
      >
        <div class="min-w-0">
          <p class="break-words font-medium">
            {{ item.description }}
          </p>
          <p class="text-xs text-ink-muted">
            {{ t(`quote.itemTypes.${item.type}`) }}
            · {{ qty(item.quantity) }} {{ t(`quote.units.${item.unit}`) }} × {{ fmt(item.unit_price) }}
            <template v-if="item.brand">
              · {{ item.brand }}
            </template>
            <template v-if="item.condition">
              · {{ t(`quote.conditions.${item.condition}`) }}
            </template>
            <template v-if="item.warranty_days">
              · {{ t('compare.warranty', { days: item.warranty_days }) }}
            </template>
          </p>
        </div>
        <span class="shrink-0 font-medium">{{ fmt(item.amount) }}</span>
      </li>
    </ul>
    <dl class="flex flex-col gap-1 border-t border-border pt-2">
      <div
        v-if="hasTax"
        class="flex justify-between text-sm"
      >
        <dt>{{ t('quote.subtotal') }}</dt>
        <dd>{{ fmt(revision.subtotal) }}</dd>
      </div>
      <div
        v-if="hasTax"
        class="flex justify-between text-sm"
      >
        <dt>{{ t('quote.tax', { rate: revision.tax_rate_bps / 100 }) }}</dt>
        <dd>{{ fmt(revision.tax) }}</dd>
      </div>
      <div class="flex justify-between text-lg font-semibold">
        <dt>{{ t('quote.total') }}</dt>
        <dd>{{ fmt(revision.total) }}</dd>
      </div>
    </dl>
    <div
      v-if="revision.notes"
      class="rounded-[var(--radius-control)] bg-surface-muted p-3 text-sm"
    >
      <p class="text-xs uppercase tracking-wide text-ink-muted">
        {{ t('compare.notes') }}
      </p>
      <p class="whitespace-pre-line break-words">
        {{ revision.notes }}
      </p>
    </div>
  </div>
</template>
