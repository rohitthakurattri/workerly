<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import type { QuotationStatus, WorkerQuotation } from '~/types/models'
import { formatMoney } from '~/utils/money'
import { quoteStatusTone } from '~/utils/quotes'

definePageMeta({ middleware: ['worker-profile'] })

const { list } = useQuotes()
const { t, locale } = useI18n()
const tabs: (QuotationStatus | '')[] = ['', 'submitted', 'accepted', 'declined']
const tab = ref<QuotationStatus | ''>('')
const quotes = ref<WorkerQuotation[] | null>(null)
const failed = ref(false)

async function load() {
  quotes.value = null
  failed.value = false
  try {
    quotes.value = await list(tab.value || undefined)
  }
  catch {
    failed.value = true
  }
}
onMounted(load)
watch(tab, load)

const fmt = (iso: string) => new Intl.DateTimeFormat(locale.value, { day: 'numeric', month: 'short', timeZone: 'Asia/Kolkata' }).format(new Date(iso))
const link = (q: WorkerQuotation) => (q.booking_id ? `/jobs/${q.booking_id}` : `/leads/${q.lead_id}`)
</script>

<template>
  <div class="mx-auto flex max-w-xl flex-col gap-4">
    <NuxtLink
      to="/"
      class="text-sm text-brand-700"
    >
      ← {{ t('worker.leads') }}
    </NuxtLink>
    <h1 class="text-2xl font-semibold">
      {{ t('quotes.title') }}
    </h1>
    <div
      class="flex flex-wrap gap-2"
      role="tablist"
    >
      <button
        v-for="s in tabs"
        :key="s || 'all'"
        type="button"
        role="tab"
        :aria-selected="tab === s"
        class="h-9 rounded-full border px-3 text-sm"
        :class="tab === s ? 'border-brand-700 bg-brand-700 text-white' : 'border-border bg-surface'"
        @click="tab = s"
      >
        {{ s ? t(`quoteStatus.${s}`) : t('quotes.all') }}
      </button>
    </div>
    <UiEmptyState
      v-if="failed"
      :title="t('quotes.loadFailed')"
    />
    <UiSkeleton
      v-else-if="quotes === null"
      :lines="4"
    />
    <UiEmptyState
      v-else-if="!quotes.length"
      :title="t('quotes.empty')"
    />
    <ul
      v-else
      class="flex flex-col gap-2"
    >
      <li
        v-for="q in quotes"
        :key="q.id"
      >
        <NuxtLink
          :to="link(q)"
          class="flex items-center justify-between gap-3 rounded-[var(--radius-card)] border border-border bg-surface p-3 hover:border-brand-600"
        >
          <span class="min-w-0">
            <strong class="block truncate">{{ q.category.name }}</strong>
            <span class="block text-sm text-ink-muted">{{ q.locality }} · {{ fmt(q.submitted_at) }} · {{ t(`quote.${q.kind}`) }}</span>
            <span
              v-if="q.decline_reason"
              class="block text-xs text-ink-muted"
            >{{ t('quotes.declinedReason', { reason: q.decline_reason }) }}</span>
          </span>
          <span class="flex shrink-0 flex-col items-end gap-1">
            <strong>{{ formatMoney(q.revision.total) }}</strong>
            <UiBadge :tone="quoteStatusTone(q.status)">{{ t(`quoteStatus.${q.status}`) }}</UiBadge>
          </span>
        </NuxtLink>
      </li>
    </ul>
  </div>
</template>
