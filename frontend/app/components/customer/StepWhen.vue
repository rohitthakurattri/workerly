<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import type { Urgency } from '~/types/models'
import { ApiError } from '~/utils/api-error'
import { localDate, SLOTS, slotWindow, URGENCIES, type Slot } from '~/utils/requests'

const emit = defineEmits<{ done: [] }>()
const { request, triage, save } = useServiceRequest()
const { cities, load: loadCatalog } = useCatalog()
const { t } = useI18n()

// The AI's urgency guess pre-selects a chip only while the customer hasn't chosen one.
const initial = request.value?.urgency !== 'flexible' ? request.value?.urgency : triage.value?.urgency
const urgency = ref<Urgency>(initial ?? 'flexible')
const pickTime = ref(!!request.value?.preferred_from)
const busy = ref(false)
const error = ref<string | null>(null)

onMounted(loadCatalog)
const timeZone = computed(() => cities.value.find(c => c.slug === request.value?.address?.city)?.time_zone ?? 'Asia/Kolkata')
const days = computed(() => [0, 1, 2, 3, 4, 5, 6].map(d => localDate(timeZone.value, d)))
const date = ref('')
const slot = ref<Slot>('morning')

function dayLabel(d: string, i: number) {
  if (i === 0) return t('requests.today')
  if (i === 1) return t('requests.tomorrow')
  return new Intl.DateTimeFormat(undefined, { weekday: 'short', day: 'numeric', timeZone: 'UTC' }).format(new Date(`${d}T00:00:00Z`))
}

async function next() {
  busy.value = true
  error.value = null
  try {
    const window = pickTime.value && date.value
      ? slotWindow(date.value, slot.value, timeZone.value)
      : { preferred_from: null, preferred_to: null }
    await save({ urgency: urgency.value, ...window })
    emit('done')
  }
  catch (e) {
    const err = ApiError.from(e)
    error.value = Object.values(err.fieldErrors)[0]?.[0] ?? err.message
  }
  finally {
    busy.value = false
  }
}
</script>

<template>
  <form
    class="flex flex-col gap-4"
    @submit.prevent="next"
  >
    <fieldset class="grid grid-cols-2 gap-2">
      <legend class="mb-2 text-sm font-medium">
        {{ t('requests.howSoon') }}
      </legend>
      <label
        v-for="u in URGENCIES"
        :key="u"
        class="cursor-pointer rounded-[var(--radius-control)] border border-border bg-surface p-3 text-sm has-[:checked]:border-brand-700 has-[:checked]:bg-brand-50"
      >
        <input
          v-model="urgency"
          type="radio"
          name="urgency"
          :value="u"
          class="sr-only"
        >
        <span class="font-medium">{{ t(`urgency.${u}`) }}</span>
      </label>
    </fieldset>

    <label class="flex items-center gap-2 text-sm">
      <input
        v-model="pickTime"
        type="checkbox"
        class="size-4 accent-brand-700"
      >
      {{ t('requests.pickTime') }}
    </label>
    <div
      v-if="pickTime"
      class="flex flex-col gap-3"
    >
      <div
        class="flex gap-2 overflow-x-auto pb-1"
        role="radiogroup"
        :aria-label="t('requests.day')"
      >
        <label
          v-for="(d, i) in days"
          :key="d"
          class="shrink-0 cursor-pointer rounded-full border border-border bg-surface px-3 py-1.5 text-sm has-[:checked]:border-brand-700 has-[:checked]:bg-brand-50"
        >
          <input
            v-model="date"
            type="radio"
            name="day"
            :value="d"
            class="sr-only"
          >
          {{ dayLabel(d, i) }}
        </label>
      </div>
      <UiSelect
        v-model="slot"
        :label="t('requests.timeOfDay')"
        :options="(Object.keys(SLOTS) as Slot[]).map(s => ({ value: s, label: t(`slots.${s}`) }))"
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
      :disabled="pickTime && !date"
    >
      {{ t('requests.continue') }}
    </UiButton>
  </form>
</template>
