<script setup lang="ts">
import type { WorkerCard } from '~/types/models'

defineProps<{ worker: WorkerCard, distanceBand?: string }>()
const { t } = useI18n()
</script>

<template>
  <div class="flex items-center gap-3">
    <img
      v-if="worker.photo"
      :src="worker.photo.url"
      alt=""
      class="size-12 shrink-0 rounded-full object-cover"
    >
    <span
      v-else
      class="flex size-12 shrink-0 items-center justify-center rounded-full bg-surface-muted"
      aria-hidden="true"
    >👷</span>
    <div class="min-w-0">
      <p class="flex items-center gap-2 font-semibold">
        <span class="truncate">{{ worker.name }}</span>
        <UiBadge
          v-if="worker.verified"
          tone="success"
        >✓ {{ t('compare.verified') }}</UiBadge>
      </p>
      <p class="text-sm text-ink-muted">
        <template v-if="worker.rating_avg != null">
          {{ t('compare.rating', { rating: worker.rating_avg.toFixed(1), count: worker.rating_count }) }}
        </template>
        <template v-else>
          {{ t('compare.newWorker') }}
        </template>
        · {{ t('compare.jobsDone', { count: worker.jobs_done }, worker.jobs_done) }}
        <template v-if="worker.experience_years">
          · {{ t('compare.years', { count: worker.experience_years }) }}
        </template>
        <template v-if="distanceBand">
          · {{ t(`distance.${distanceBand}`) }}
        </template>
      </p>
    </div>
  </div>
</template>
