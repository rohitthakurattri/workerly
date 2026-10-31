<script setup lang="ts">
import type { Lead } from '~/types/models'

defineProps<{ lead: Lead }>()
const { t } = useI18n()
</script>

<template>
  <NuxtLink
    :to="`/leads/${lead.id}`"
    class="flex items-center gap-3 rounded-[var(--radius-card)] border bg-surface p-3 hover:border-brand-600"
    :class="lead.status === 'new' ? 'border-brand-600' : 'border-border'"
    data-testid="lead-card"
  >
    <img
      v-if="lead.photos[0]?.file"
      :src="lead.photos[0].file.url"
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
        <strong class="truncate">{{ lead.category.name }}</strong>
        <UiBadge
          v-if="lead.status === 'new'"
          tone="info"
        >{{ t('leads.new') }}</UiBadge>
      </span>
      <span class="block truncate text-sm text-ink-muted">{{ lead.description }}</span>
      <span class="block text-xs text-ink-subtle">
        {{ lead.locality }} · {{ t(`distance.${lead.distance_band}`) }} · {{ t(`urgency.${lead.urgency}`) }}
      </span>
    </span>
  </NuxtLink>
</template>
