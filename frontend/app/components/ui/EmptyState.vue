<script setup lang="ts">
defineProps<{ title: string, description?: string }>()
</script>

<template>
  <div class="flex flex-col items-center gap-2 px-4 py-10 text-center">
    <slot name="icon" />
    <h3 class="text-base font-semibold text-ink">
      {{ title }}
    </h3>
    <p
      v-if="description"
      class="max-w-sm text-sm text-ink-muted"
    >
      {{ description }}
    </p>
    <div
      v-if="$slots.default"
      class="mt-2"
    >
      <slot />
    </div>
  </div>
</template>
