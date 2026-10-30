<script setup lang="ts">
import type { ServiceRequestSummary } from '~/types/models'

const props = defineProps<{ request: ServiceRequestSummary }>()
const { t, locale } = useI18n()
const to = props.request.status === 'draft' ? { path: '/requests/new', query: { id: props.request.id } } : `/requests/${props.request.id}`
const date = new Intl.DateTimeFormat(locale.value, { day: 'numeric', month: 'short', timeZone: 'Asia/Kolkata' })
  .format(new Date(props.request.submitted_at ?? props.request.created_at))
</script>

<template>
  <NuxtLink
    :to="to"
    class="flex items-center gap-3 rounded-[var(--radius-card)] border border-border bg-surface p-3 hover:border-brand-600"
  >
    <img
      v-if="request.cover"
      :src="request.cover.url"
      alt=""
      class="size-14 shrink-0 rounded-[var(--radius-control)] object-cover"
    >
    <span
      v-else
      class="flex size-14 shrink-0 items-center justify-center rounded-[var(--radius-control)] bg-surface-muted text-xl"
      aria-hidden="true"
    >🛠️</span>
    <span class="min-w-0 flex-1">
      <span class="flex items-center justify-between gap-2">
        <strong class="truncate">{{ request.category?.name ?? t('requests.untitled') }}</strong>
        <CustomerRequestStatusBadge :status="request.status" />
      </span>
      <span class="block truncate text-sm text-ink-muted">{{ request.title }}</span>
      <span class="block text-xs text-ink-subtle">{{ [request.locality, date].filter(Boolean).join(' · ') }}</span>
    </span>
  </NuxtLink>
</template>
