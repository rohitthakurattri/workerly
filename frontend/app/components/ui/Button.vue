<script setup lang="ts">
import { computed } from 'vue'

const props = withDefaults(defineProps<{
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger'
  size?: 'sm' | 'md' | 'lg'
  type?: 'button' | 'submit' | 'reset'
  loading?: boolean
  disabled?: boolean
  block?: boolean
}>(), { variant: 'primary', size: 'md', type: 'button', loading: false, disabled: false, block: false })

const classes = computed(() => [
  'inline-flex items-center justify-center gap-2 rounded-[var(--radius-control)] font-medium transition-colors disabled:cursor-not-allowed disabled:opacity-60',
  {
    sm: 'h-9 px-3 text-sm',
    md: 'h-11 px-4 text-base',
    lg: 'h-12 px-5 text-lg',
  }[props.size],
  {
    primary: 'bg-brand-700 text-white hover:bg-brand-800',
    secondary: 'border border-border bg-surface text-ink hover:bg-surface-muted',
    ghost: 'text-brand-700 hover:bg-brand-50',
    danger: 'bg-danger text-white hover:opacity-90',
  }[props.variant],
  props.block && 'w-full',
])
</script>

<template>
  <button
    :type="type"
    :class="classes"
    :disabled="disabled || loading"
    :aria-busy="loading || undefined"
  >
    <span
      v-if="loading"
      class="size-4 animate-spin rounded-full border-2 border-current border-t-transparent"
      aria-hidden="true"
    />
    <slot />
  </button>
</template>
