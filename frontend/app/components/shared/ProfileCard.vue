<script setup lang="ts">
import { ref, watchEffect } from 'vue'
import { useAuthStore } from '~/stores/auth'
import { ApiError } from '~/utils/api-error'
import { formatIndianMobile } from '~/utils/phone'

const auth = useAuthStore()
const { updateProfile } = useAuth()
const toast = useToast()
const { t } = useI18n()

const name = ref('')
const error = ref<string | null>(null)
const saving = ref(false)
watchEffect(() => {
  name.value = auth.user?.name ?? ''
})

async function save() {
  saving.value = true
  error.value = null
  try {
    await updateProfile({ name: name.value.trim() })
    toast.success(t('profile.saved'))
  }
  catch (e) {
    const err = ApiError.from(e)
    error.value = err.fieldErrors.name?.[0] ?? err.message
  }
  finally {
    saving.value = false
  }
}
</script>

<template>
  <UiCard>
    <template #title>
      {{ t('profile.title') }}
    </template>
    <form
      class="flex flex-col gap-4"
      @submit.prevent="save"
    >
      <UiInput
        v-model="name"
        :label="t('profile.name')"
        :error="error"
        autocomplete="name"
        maxlength="100"
      />
      <p class="text-sm text-ink-muted">
        {{ t('profile.phone') }}: {{ auth.user ? formatIndianMobile(auth.user.phone) : '' }}
      </p>
      <div>
        <UiButton
          type="submit"
          :loading="saving"
        >
          {{ t('common.save') }}
        </UiButton>
      </div>
    </form>
  </UiCard>
</template>
