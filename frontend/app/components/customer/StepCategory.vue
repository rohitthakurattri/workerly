<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { ApiError } from '~/utils/api-error'

const emit = defineEmits<{ done: [] }>()
const { request, triage, runTriage, save } = useServiceRequest()
const { load: loadCatalog, leaves } = useCatalog()
const { t } = useI18n()

const analysing = ref(true)
const aiOff = ref(false)
const selected = ref<string>(request.value?.category?.slug ?? '')
const answers = ref<Record<string, string>>(Object.fromEntries((request.value?.answers ?? []).map(a => [a.question, a.answer])))
const busy = ref(false)
const error = ref<string | null>(null)

// Suggested category and alternatives first, then everything else.
const options = computed(() => {
  const first = [triage.value?.suggested_category?.slug, ...(triage.value?.alternatives ?? []).map(a => a.slug)].filter(Boolean) as string[]
  const all = leaves()
  return [...first.map(s => all.find(c => c.slug === s)).filter(c => !!c), ...all.filter(c => !first.includes(c.slug))]
})
const questions = computed(() => triage.value?.questions ?? [])

onMounted(async () => {
  const catalog = loadCatalog()
  try {
    await runTriage()
    if (!selected.value && triage.value?.suggested_category && !triage.value.needs_confirmation) selected.value = triage.value.suggested_category.slug
  }
  catch {
    // ai_unavailable / budget / network: the customer simply picks the service.
    aiOff.value = true
  }
  finally {
    await catalog
    analysing.value = false
  }
})

async function next() {
  busy.value = true
  error.value = null
  try {
    await save({
      category: selected.value,
      answers: questions.value.map(q => ({ question: q, answer: (answers.value[q] ?? '').trim() })).filter(a => a.answer),
    })
    emit('done')
  }
  catch (e) {
    error.value = ApiError.from(e).message
  }
  finally {
    busy.value = false
  }
}
</script>

<template>
  <div
    v-if="analysing"
    class="flex flex-col gap-3"
    role="status"
  >
    <p class="text-ink-muted">
      {{ t('requests.analysing') }}
    </p>
    <UiSkeleton :lines="4" />
  </div>
  <form
    v-else
    class="flex flex-col gap-4"
    @submit.prevent="next"
  >
    <CustomerSafetyNotice v-if="triage?.safety_flag" />
    <p
      v-if="triage?.suggested_category && !triage.needs_confirmation"
      class="text-sm text-ink-muted"
    >
      {{ t('requests.suggestedHint') }}
    </p>
    <p
      v-else
      class="text-sm text-ink-muted"
    >
      {{ aiOff ? t('requests.pickService') : t('requests.notSure') }}
    </p>

    <fieldset class="grid grid-cols-2 gap-2 sm:grid-cols-3">
      <legend class="sr-only">
        {{ t('requests.service') }}
      </legend>
      <label
        v-for="c in options"
        :key="c.slug"
        class="flex cursor-pointer flex-col gap-1 rounded-[var(--radius-control)] border p-3 text-sm has-[:checked]:border-brand-700 has-[:checked]:bg-brand-50"
        :class="c.slug === triage?.suggested_category?.slug ? 'border-brand-600' : 'border-border bg-surface'"
      >
        <input
          v-model="selected"
          type="radio"
          name="category"
          :value="c.slug"
          class="sr-only"
        >
        <span class="font-medium">{{ c.name }}</span>
        <UiBadge
          v-if="c.slug === triage?.suggested_category?.slug"
          tone="info"
          class="self-start"
        >
          {{ t('requests.suggested') }}
        </UiBadge>
      </label>
    </fieldset>

    <div
      v-if="questions.length"
      class="flex flex-col gap-3"
    >
      <p class="text-sm font-medium">
        {{ t('requests.questionsTitle') }} <span class="font-normal text-ink-muted">({{ t('common.optional') }})</span>
      </p>
      <UiInput
        v-for="q in questions"
        :key="q"
        v-model="answers[q]"
        :label="q"
        maxlength="500"
      />
    </div>

    <p
      v-if="error"
      class="text-sm text-danger"
      role="alert"
    >
      {{ error }}
    </p>
    <UiButton
      type="submit"
      size="lg"
      block
      :loading="busy"
      :disabled="!selected"
    >
      {{ t('requests.continue') }}
    </UiButton>
  </form>
</template>
