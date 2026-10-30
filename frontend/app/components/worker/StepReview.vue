<script setup lang="ts">
import { ref } from 'vue'
import { ApiError } from '~/utils/api-error'

const { profile, submit } = useWorkerProfile()
const { t } = useI18n()
const busy = ref(false)
const error = ref<string | null>(null)

async function send() {
  busy.value = true
  error.value = null
  try {
    await submit()
    await navigateTo('/verification')
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
  <div class="flex flex-col gap-4">
    <template v-if="profile?.missing.length">
      <p>{{ t('onboarding.stillMissing') }}</p>
      <ul class="list-disc pl-6 text-sm text-ink-muted">
        <li
          v-for="m in profile.missing"
          :key="m"
        >
          {{ t(`missing.${m}`) }}
        </li>
      </ul>
    </template>
    <p v-else>
      {{ t('onboarding.readyToSubmit') }}
    </p>
    <p
      v-if="error"
      class="text-sm text-danger"
      role="alert"
    >
      {{ error }}
    </p>
    <div>
      <UiButton
        :disabled="!!profile?.missing.length"
        :loading="busy"
        @click="send"
      >
        {{ t('onboarding.submit') }}
      </UiButton>
    </div>
  </div>
</template>
