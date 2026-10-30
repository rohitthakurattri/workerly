<script setup lang="ts">
import type { RequestStatus } from '~/types/models'
import { statusTone } from '~/utils/requests'

defineProps<{ status: RequestStatus }>()
const { t } = useI18n()
</script>

<template>
  <UiBadge :tone="statusTone(status)">
    {{ t(`requestStatus.${status}`) }}
  </UiBadge>
</template>
