<script setup lang="ts">
import type { VerificationStatus } from '~/types/models'

defineProps<{ status: VerificationStatus, suspended?: boolean }>()
const { t } = useI18n()
const tones = { draft: 'neutral', pending_review: 'info', changes_requested: 'warning', approved: 'success', rejected: 'danger' } as const
</script>

<template>
  <span class="inline-flex gap-1">
    <UiBadge :tone="tones[status]">{{ t(`admin.status.${status}`) }}</UiBadge>
    <UiBadge
      v-if="suspended"
      tone="danger"
    >{{ t('admin.suspended') }}</UiBadge>
  </span>
</template>
