<script setup lang="ts">
import { computed, ref, watchEffect } from 'vue'
import { ApiError } from '~/utils/api-error'

const emit = defineEmits<{ saved: [] }>()
const { profile, categories, saveSkills } = useWorkerProfile()
const { t } = useI18n()

// slug -> years ('' = not given); presence in the map means selected.
const selected = ref<Record<string, string>>({})
const error = ref<string | null>(null)
const saving = ref(false)

watchEffect(() => {
  selected.value = Object.fromEntries((profile.value?.skills ?? []).map(s => [s.category, s.experience_years?.toString() ?? '']))
})

// Leaf categories are what workers actually do; show children under their parent.
const options = computed(() => categories.value.flatMap(c => (c.children.length ? c.children : [c])))

function toggle(slug: string) {
  selected.value = slug in selected.value
    ? Object.fromEntries(Object.entries(selected.value).filter(([k]) => k !== slug))
    : { ...selected.value, [slug]: '' }
}

async function save() {
  error.value = null
  saving.value = true
  try {
    await saveSkills(Object.entries(selected.value).map(([category, years]) => ({ category, experience_years: years === '' ? null : Number(years) })))
    emit('saved')
  }
  catch (e) {
    error.value = ApiError.from(e).message
  }
  finally {
    saving.value = false
  }
}
</script>

<template>
  <form
    class="flex flex-col gap-4"
    @submit.prevent="save"
  >
    <p class="text-sm text-ink-muted">
      {{ t('onboarding.skillsHint') }}
    </p>
    <ul class="grid gap-2 sm:grid-cols-2">
      <li
        v-for="c in options"
        :key="c.slug"
        class="rounded-[var(--radius-control)] border p-3"
        :class="c.slug in selected ? 'border-brand-600 bg-brand-50' : 'border-border bg-surface'"
      >
        <label class="flex cursor-pointer items-center gap-3">
          <input
            type="checkbox"
            class="size-5 accent-brand-700"
            :checked="c.slug in selected"
            @change="toggle(c.slug)"
          >
          <span class="font-medium">{{ c.name }}</span>
        </label>
        <div
          v-if="c.slug in selected"
          class="mt-2 flex items-center gap-2 pl-8 text-sm"
        >
          <label :for="`years-${c.slug}`">{{ t('onboarding.years') }}</label>
          <input
            :id="`years-${c.slug}`"
            v-model="selected[c.slug]"
            type="number"
            min="0"
            max="60"
            inputmode="numeric"
            class="h-9 w-20 rounded-[var(--radius-control)] border border-border bg-surface px-2"
          >
        </div>
      </li>
    </ul>
    <p
      v-if="error"
      class="text-sm text-danger"
      role="alert"
    >
      {{ error }}
    </p>
    <div>
      <UiButton
        type="submit"
        :loading="saving"
        :disabled="!Object.keys(selected).length"
      >
        {{ t('onboarding.saveContinue') }}
      </UiButton>
    </div>
  </form>
</template>
