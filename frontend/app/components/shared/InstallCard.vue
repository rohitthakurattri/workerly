<script setup lang="ts">
import { ref } from 'vue'

/** Offers to install the app (home-screen icon, works like an app; on iPhone it's also what makes notifications possible). */
defineProps<{ reason: string }>()
const { visible, canPrompt, showIosHint, install } = useInstallPrompt()
const { t } = useI18n()
const dismissed = ref(false)
</script>

<template>
  <UiCard
    v-if="visible && !dismissed"
    data-testid="install-card"
  >
    <div class="flex items-start gap-3">
      <span
        class="text-2xl"
        aria-hidden="true"
      >📲</span>
      <div class="flex flex-1 flex-col gap-2">
        <p class="font-medium">
          {{ t('pwa.title') }}
        </p>
        <p class="text-sm text-ink-muted">
          {{ reason }}
        </p>
        <p
          v-if="showIosHint && !canPrompt"
          class="text-sm"
        >
          {{ t('pwa.iosSteps') }}
        </p>
        <div class="flex gap-2">
          <UiButton
            v-if="canPrompt"
            size="sm"
            @click="install"
          >
            {{ t('pwa.install') }}
          </UiButton>
          <UiButton
            variant="ghost"
            size="sm"
            @click="dismissed = true"
          >
            {{ t('pwa.later') }}
          </UiButton>
        </div>
      </div>
    </div>
  </UiCard>
</template>
