<script setup lang="ts">
import { useToast } from '~/composables/useToast'

const { toasts, dismiss } = useToast()
const tones = {
  info: 'border-info/30 bg-info-soft text-info',
  success: 'border-success/30 bg-success-soft text-success',
  warning: 'border-warning/30 bg-warning-soft text-warning',
  danger: 'border-danger/30 bg-danger-soft text-danger',
}
</script>

<template>
  <div
    class="pointer-events-none fixed inset-x-0 bottom-4 z-50 flex flex-col items-center gap-2 px-4"
    aria-live="polite"
  >
    <div
      v-for="t in toasts"
      :key="t.id"
      class="pointer-events-auto flex w-full max-w-md items-start justify-between gap-3 rounded-[var(--radius-control)] border px-4 py-3 text-sm shadow-md"
      :class="tones[t.tone]"
      :role="t.tone === 'danger' ? 'alert' : 'status'"
    >
      <span>{{ t.message }}</span>
      <button
        type="button"
        class="shrink-0 opacity-70 hover:opacity-100"
        aria-label="Dismiss"
        @click="dismiss(t.id)"
      >
        ✕
      </button>
    </div>
  </div>
</template>
