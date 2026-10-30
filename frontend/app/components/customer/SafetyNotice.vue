<script setup lang="ts">
const { t } = useI18n()
</script>

<template>
  <div
    class="rounded-[var(--radius-card)] border border-danger/30 bg-danger-soft p-4 text-sm text-danger"
    role="alert"
  >
    <p class="font-semibold">
      ⚠️ {{ t('requests.safetyTitle') }}
    </p>
    <p class="mt-1">
      {{ t('requests.safetyBody') }}
    </p>
  </div>
</template>
