<script setup lang="ts">
import { computed } from 'vue'
import type { BookingStatus, QuotationKind } from '~/types/models'
import { bookingSteps, bookingTone, stepIndex } from '~/utils/bookings'

const props = defineProps<{ kind: QuotationKind, status: BookingStatus }>()
const { t } = useI18n()
const steps = computed(() => bookingSteps(props.kind))
const current = computed(() => stepIndex(props.kind, props.status))
</script>

<template>
  <div class="flex flex-col gap-2">
    <p class="flex items-center gap-2">
      <UiBadge
        :tone="bookingTone(status)"
        data-testid="booking-status"
      >
        {{ t(`bookingStatus.${status}`) }}
      </UiBadge>
    </p>
    <ol
      v-if="current >= 0"
      class="flex gap-1"
      :aria-label="t('booking.progress')"
    >
      <li
        v-for="(s, i) in steps"
        :key="s"
        class="h-1.5 flex-1 rounded-full"
        :class="i <= current ? 'bg-brand-600' : 'bg-border'"
        :aria-current="i === current ? 'step' : undefined"
      >
        <span class="sr-only">{{ t(`bookingStatus.${s}`) }}</span>
      </li>
    </ol>
  </div>
</template>
