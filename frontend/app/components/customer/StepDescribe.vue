<script setup lang="ts">
import { computed, ref, useId } from 'vue'
import { ApiError } from '~/utils/api-error'
import { DESCRIPTION_MIN } from '~/utils/requests'

const emit = defineEmits<{ done: [] }>()
const { request, save } = useServiceRequest()
const { t } = useI18n()
const id = useId()

const description = ref(request.value?.description ?? '')
const busy = ref(false)
const error = ref<string | null>(null)
const tooShort = computed(() => description.value.trim().length < DESCRIPTION_MIN)

async function next() {
  busy.value = true
  error.value = null
  try {
    if (description.value.trim() !== (request.value?.description ?? '')) await save({ description: description.value.trim() })
    emit('done')
  }
  catch (e) {
    const err = ApiError.from(e)
    error.value = err.fieldErrors.description?.[0] ?? err.message
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
    <div class="flex flex-col gap-1.5">
      <label
        :for="id"
        class="text-sm font-medium"
      >{{ t('requests.describeLabel') }}</label>
      <textarea
        :id="id"
        v-model="description"
        rows="4"
        maxlength="2000"
        :placeholder="t('requests.describePlaceholder')"
        class="w-full rounded-[var(--radius-control)] border border-border bg-surface px-3 py-2 text-base focus:border-brand-600 focus:outline-none"
      />
      <p class="text-sm text-ink-muted">
        {{ t('requests.describeHint') }}
      </p>
    </div>
    <CustomerPhotoPicker />
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
      :disabled="tooShort"
    >
      {{ t('requests.continue') }}
    </UiButton>
  </form>
</template>
