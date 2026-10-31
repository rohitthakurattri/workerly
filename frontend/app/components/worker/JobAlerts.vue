<script setup lang="ts">
import { onMounted, ref } from 'vue'

const { state, refresh, enable, disable } = usePush()
const { t } = useI18n()
const busy = ref(false)

onMounted(() => refresh().catch(() => {}))

async function toggle() {
  busy.value = true
  try {
    await (state.value === 'on' ? disable() : enable())
  }
  finally {
    busy.value = false
  }
}
</script>

<template>
  <UiCard v-if="state !== 'unsupported' && state !== 'unavailable'">
    <div class="flex items-center justify-between gap-4">
    <div>
      <p class="font-semibold">
        {{ t('leads.alerts') }}
      </p>
      <p class="text-sm text-ink-muted">
        {{ state === 'denied' ? t('leads.alertsBlocked') : state === 'on' ? t('leads.alertsOn') : t('leads.alertsOff') }}
      </p>
    </div>
    <UiButton
      v-if="state !== 'denied'"
      :variant="state === 'on' ? 'secondary' : 'primary'"
      size="sm"
      :loading="busy"
      @click="toggle"
    >
      {{ state === 'on' ? t('leads.turnOff') : t('leads.turnOn') }}
    </UiButton>
    </div>
  </UiCard>
</template>
