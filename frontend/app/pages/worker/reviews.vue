<script setup lang="ts">
import { onMounted, ref } from 'vue'

definePageMeta({ middleware: ['worker-profile'] })

interface WorkerReview { rating: number, body: string | null, customer_name: string | null, category: string, created_at: string }
const api = useApi()
const { t, locale } = useI18n()
const reviews = ref<WorkerReview[] | null>(null)
const summary = ref<{ rating_avg: number | null, rating_count: number } | null>(null)

onMounted(async () => {
  const res = await api<{ data: WorkerReview[], meta: { rating_avg: number | null, rating_count: number } }>('/worker/reviews')
  reviews.value = res.data
  summary.value = res.meta
})

const fmt = (iso: string) => new Intl.DateTimeFormat(locale.value, { day: 'numeric', month: 'short', year: 'numeric' }).format(new Date(iso))
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
      {{ t('reviews.title') }}
    </h1>
    <p
      v-if="summary?.rating_count"
      class="text-lg"
    >
      {{ t('reviews.summary', { rating: summary.rating_avg?.toFixed(1), count: summary.rating_count }) }}
    </p>
    <UiSkeleton
      v-if="reviews === null"
      :lines="4"
    />
    <UiEmptyState
      v-else-if="!reviews.length"
      :title="t('reviews.none')"
    />
    <ul
      v-else
      class="flex flex-col gap-2"
    >
      <li
        v-for="(r, i) in reviews"
        :key="i"
        class="rounded-[var(--radius-card)] border border-border bg-surface p-3"
      >
        <p class="flex justify-between">
          <span class="text-warning">{{ '★'.repeat(r.rating) }}<span class="text-border">{{ '★'.repeat(5 - r.rating) }}</span></span>
          <span class="text-xs text-ink-muted">{{ r.category }} · {{ fmt(r.created_at) }}</span>
        </p>
        <p
          v-if="r.body"
          class="mt-1"
        >
          “{{ r.body }}”
        </p>
        <p class="text-xs text-ink-muted">
          {{ r.customer_name }}
        </p>
      </li>
    </ul>
  </div>
</template>
