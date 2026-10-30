<script setup lang="ts">
import { useId } from 'vue'

defineProps<{
  label: string
  options: { value: string, label: string }[]
  error?: string | null
}>()
const model = defineModel<string>({ default: '' })
const id = useId()
</script>

<template>
  <div class="flex flex-col gap-1.5">
    <label
      :for="id"
      class="text-sm font-medium text-ink"
    >{{ label }}</label>
    <select
      :id="id"
      v-model="model"
      :aria-invalid="!!error || undefined"
      class="h-11 rounded-[var(--radius-control)] border border-border bg-surface px-3 text-base text-ink focus:border-brand-600 focus:outline-none aria-invalid:border-danger"
    >
      <option
        v-for="o in options"
        :key="o.value"
        :value="o.value"
      >
        {{ o.label }}
      </option>
    </select>
    <p
      v-if="error"
      class="text-sm text-danger"
      role="alert"
    >
      {{ error }}
    </p>
  </div>
</template>
