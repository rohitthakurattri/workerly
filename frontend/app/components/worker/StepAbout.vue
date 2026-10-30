<script setup lang="ts">
import { computed, ref, watchEffect } from 'vue'
import { ApiError } from '~/utils/api-error'
import { MAX_PHOTO_BYTES } from '~/utils/onboarding'
import { useAuthStore } from '~/stores/auth'

const emit = defineEmits<{ saved: [] }>()
const { profile, updateAbout } = useWorkerProfile()
const { updateProfile } = useAuth()
const auth = useAuthStore()
const { t } = useI18n()

const name = ref('')
const bio = ref('')
const experience = ref('')
const photo = ref<File | null>(null)
const preview = ref<string | null>(null)
const errors = ref<Record<string, string>>({})
const saving = ref(false)

watchEffect(() => {
  name.value = auth.user?.name ?? ''
  bio.value = profile.value?.bio ?? ''
  experience.value = profile.value?.experience_years?.toString() ?? ''
})

const photoUrl = computed(() => preview.value ?? profile.value?.photo?.url ?? null)

function pickPhoto(e: Event) {
  const file = (e.target as HTMLInputElement).files?.[0]
  if (!file) return
  if (file.size > MAX_PHOTO_BYTES) {
    errors.value = { ...errors.value, photo: t('onboarding.fileTooBig', { mb: 5 }) }
    return
  }
  photo.value = file
  preview.value = URL.createObjectURL(file)
  errors.value = { ...errors.value, photo: '' }
}

async function save() {
  saving.value = true
  errors.value = {}
  try {
    if (name.value.trim() !== (auth.user?.name ?? '')) await updateProfile({ name: name.value.trim() })
    await updateAbout({
      bio: bio.value.trim(),
      experience_years: experience.value === '' ? null : Number(experience.value),
      ...(photo.value ? { photo: photo.value } : {}),
    })
    photo.value = null
    emit('saved')
  }
  catch (e) {
    const err = ApiError.from(e)
    errors.value = Object.fromEntries(Object.entries(err.fieldErrors).map(([k, v]) => [k, v[0] ?? ''])) || {}
    if (!Object.keys(errors.value).length) errors.value = { form: err.message }
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
    <div class="flex items-center gap-4">
      <img
        v-if="photoUrl"
        :src="photoUrl"
        :alt="t('onboarding.photo')"
        class="size-20 rounded-full border border-border object-cover"
      >
      <div
        v-else
        class="flex size-20 items-center justify-center rounded-full border border-dashed border-border text-ink-subtle"
        aria-hidden="true"
      >
        📷
      </div>
      <div>
        <label class="inline-flex cursor-pointer items-center rounded-[var(--radius-control)] border border-border bg-surface px-3 py-2 text-sm font-medium hover:bg-surface-muted">
          {{ photoUrl ? t('onboarding.changePhoto') : t('onboarding.addPhoto') }}
          <input
            type="file"
            accept="image/jpeg,image/png,image/webp,image/heic"
            capture="user"
            class="sr-only"
            data-testid="photo-input"
            @change="pickPhoto"
          >
        </label>
        <p class="mt-1 text-xs text-ink-muted">
          {{ t('onboarding.photoHint') }}
        </p>
        <p
          v-if="errors.photo"
          class="text-sm text-danger"
          role="alert"
        >
          {{ errors.photo }}
        </p>
      </div>
    </div>
    <UiInput
      v-model="name"
      :label="t('profile.name')"
      :error="errors.name"
      autocomplete="name"
      maxlength="100"
      required
    />
    <UiInput
      v-model="experience"
      :label="t('onboarding.experience')"
      :error="errors.experience_years"
      type="number"
      inputmode="numeric"
      min="0"
      max="60"
    />
    <div class="flex flex-col gap-1.5">
      <label
        for="bio"
        class="text-sm font-medium"
      >{{ t('onboarding.bio') }}</label>
      <textarea
        id="bio"
        v-model="bio"
        rows="3"
        maxlength="1000"
        :placeholder="t('onboarding.bioPlaceholder')"
        class="rounded-[var(--radius-control)] border border-border bg-surface px-3 py-2 focus:border-brand-600 focus:outline-none"
      />
    </div>
    <p
      v-if="errors.form"
      class="text-sm text-danger"
      role="alert"
    >
      {{ errors.form }}
    </p>
    <div>
      <UiButton
        type="submit"
        :loading="saving"
      >
        {{ t('onboarding.saveContinue') }}
      </UiButton>
    </div>
  </form>
</template>
