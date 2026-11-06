<script setup lang="ts">
import { computed } from 'vue'
import type { Invoice } from '~/types/models'
import { formatMoney } from '~/utils/money'

/** A printable invoice. Lines and parties are snapshots taken when it was issued. */
const props = defineProps<{ invoice: Invoice }>()
const { t, locale } = useI18n()

interface Parties {
  worker?: { name?: string | null }
  customer?: { name?: string | null }
  address?: Record<string, string | null>
  service?: string
  payments?: { method: string, amount_minor: number, at?: string | null }[]
}
const parties = computed(() => props.invoice.parties as Parties)
const currency = computed(() => props.invoice.total.currency)
const money = (minor: number) => formatMoney({ minor, currency: currency.value })
const address = computed(() => {
  const a = parties.value.address ?? {}
  return [a.line1, a.line2, a.locality, a.pincode].filter(Boolean).join(', ')
})
const date = (iso: string) => new Intl.DateTimeFormat(locale.value, { dateStyle: 'medium', timeZone: 'Asia/Kolkata' }).format(new Date(iso))
</script>

<template>
  <article
    class="invoice flex flex-col gap-5 rounded-[var(--radius-card)] border border-border bg-surface p-5"
    data-testid="invoice"
  >
    <header class="flex flex-wrap items-start justify-between gap-3">
      <div>
        <p class="text-lg font-semibold">
          Workerly
        </p>
        <p class="text-sm text-ink-muted">
          {{ parties.service }}
        </p>
      </div>
      <div class="text-right text-sm">
        <p class="font-medium">
          {{ t('invoice.title') }} {{ invoice.number }}
        </p>
        <p class="text-ink-muted">
          {{ date(invoice.issued_at) }}
        </p>
      </div>
    </header>

    <dl class="grid gap-3 text-sm sm:grid-cols-2">
      <div>
        <dt class="text-ink-muted">
          {{ t('invoice.billedTo') }}
        </dt>
        <dd>{{ parties.customer?.name || '–' }}</dd>
        <dd class="text-ink-muted">
          {{ address }}
        </dd>
      </div>
      <div>
        <dt class="text-ink-muted">
          {{ t('invoice.workDoneBy') }}
        </dt>
        <dd>{{ parties.worker?.name || '–' }}</dd>
      </div>
    </dl>

    <div class="overflow-x-auto">
      <table class="w-full text-sm">
        <thead class="text-left text-ink-muted">
          <tr>
            <th
              scope="col"
              class="py-2 font-medium"
            >
              {{ t('invoice.item') }}
            </th>
            <th
              scope="col"
              class="py-2 text-right font-medium"
            >
              {{ t('invoice.qty') }}
            </th>
            <th
              scope="col"
              class="py-2 text-right font-medium"
            >
              {{ t('invoice.rate') }}
            </th>
            <th
              scope="col"
              class="py-2 text-right font-medium"
            >
              {{ t('invoice.amount') }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="(l, i) in invoice.lines"
            :key="i"
            class="border-t border-border"
          >
            <td class="py-2">
              {{ l.description }}
              <span class="block text-xs text-ink-muted">{{ t(`quote.stages.${l.stage}`) }}</span>
            </td>
            <td class="py-2 text-right tabular-nums">
              {{ l.quantity }} {{ l.unit }}
            </td>
            <td class="py-2 text-right tabular-nums">
              {{ money(l.unit_price_minor ?? 0) }}
            </td>
            <td class="py-2 text-right tabular-nums">
              {{ money(l.amount_minor ?? 0) }}
            </td>
          </tr>
        </tbody>
        <tfoot class="tabular-nums">
          <tr class="border-t border-border">
            <td
              colspan="3"
              class="py-1 text-right text-ink-muted"
            >
              {{ t('invoice.subtotal') }}
            </td>
            <td class="py-1 text-right">
              {{ formatMoney(invoice.subtotal) }}
            </td>
          </tr>
          <tr>
            <td
              colspan="3"
              class="py-1 text-right text-ink-muted"
            >
              {{ t('invoice.tax') }}
            </td>
            <td class="py-1 text-right">
              {{ formatMoney(invoice.tax) }}
            </td>
          </tr>
          <tr class="font-semibold">
            <td
              colspan="3"
              class="py-1 text-right"
            >
              {{ t('invoice.total') }}
            </td>
            <td
              class="py-1 text-right"
              data-testid="invoice-total"
            >
              {{ formatMoney(invoice.total) }}
            </td>
          </tr>
        </tfoot>
      </table>
    </div>

    <div
      v-if="parties.payments?.length"
      class="text-sm"
    >
      <p class="font-medium">
        {{ t('invoice.paidBy') }}
      </p>
      <ul>
        <li
          v-for="(p, i) in parties.payments"
          :key="i"
          class="flex justify-between text-ink-muted"
        >
          <span>{{ t(`pay.method.${p.method}`) }}<template v-if="p.at"> · {{ date(p.at) }}</template></span>
          <span class="tabular-nums">{{ money(p.amount_minor) }}</span>
        </li>
      </ul>
    </div>
  </article>
</template>

<style scoped>
@media print {
  .invoice { border: 0; padding: 0; }
}
</style>
