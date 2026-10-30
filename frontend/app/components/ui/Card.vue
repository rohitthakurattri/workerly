<script setup lang="ts">
withDefaults(defineProps<{ padded?: boolean, as?: string }>(), { padded: true, as: 'section' })
</script>

<template>
  <component
    :is="as"
    class="rounded-[var(--radius-card)] border border-border bg-surface shadow-sm"
    :class="padded && 'p-5'"
  >
    <header
      v-if="$slots.title"
      class="mb-3 flex items-center justify-between gap-2"
    >
      <h2 class="text-lg font-semibold text-ink">
        <slot name="title" />
      </h2>
      <slot name="actions" />
    </header>
    <slot />
  </component>
</template>
