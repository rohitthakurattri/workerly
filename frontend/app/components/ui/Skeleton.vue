<script setup lang="ts">
withDefaults(defineProps<{ lines?: number }>(), { lines: 1 })
</script>

<template>
  <div
    class="flex flex-col gap-2"
    role="status"
    aria-live="polite"
  >
    <span class="sr-only">Loading…</span>
    <div
      v-for="n in lines"
      :key="n"
      class="h-4 animate-pulse rounded bg-border"
      :class="n === lines && lines > 1 ? 'w-2/3' : 'w-full'"
    />
  </div>
</template>
