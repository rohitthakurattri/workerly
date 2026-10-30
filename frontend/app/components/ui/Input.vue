<script setup lang="ts">
import { computed, useId } from 'vue'

const props = withDefaults(defineProps<{
  label: string
  error?: string | null
  hint?: string
  id?: string
}>(), { error: null, hint: undefined, id: undefined })

const model = defineModel<string>({ default: '' })
defineOptions({ inheritAttrs: false })

const autoId = useId()
const inputId = computed(() => props.id ?? autoId)
const describedBy = computed(() => (props.error ? `${inputId.value}-error` : props.hint ? `${inputId.value}-hint` : undefined))
</script>

<template>
  <div class="flex flex-col gap-1.5">
    <label
      :for="inputId"
      class="text-sm font-medium text-ink"
    >{{ label }}</label>
    <div class="flex items-stretch">
      <span
        v-if="$slots.prefix"
        class="flex items-center rounded-l-[var(--radius-control)] border border-r-0 border-border bg-surface-muted px-3 text-ink-muted"
      ><slot name="prefix" /></span>
      <input
        :id="inputId"
        v-model="model"
        v-bind="$attrs"
        :aria-invalid="!!error || undefined"
        :aria-describedby="describedBy"
        class="h-11 w-full border border-border bg-surface px-3 text-base text-ink placeholder:text-ink-subtle focus:border-brand-600 focus:outline-none aria-invalid:border-danger"
        :class="$slots.prefix ? 'rounded-r-[var(--radius-control)]' : 'rounded-[var(--radius-control)]'"
      >
    </div>
    <p
      v-if="error"
      :id="`${inputId}-error`"
      class="text-sm text-danger"
      role="alert"
    >
      {{ error }}
    </p>
    <p
      v-else-if="hint"
      :id="`${inputId}-hint`"
      class="text-sm text-ink-muted"
    >
      {{ hint }}
    </p>
  </div>
</template>
