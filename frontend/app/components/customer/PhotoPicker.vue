<script setup lang="ts">
import { computed, ref } from 'vue'
import { ApiError } from '~/utils/api-error'
import { MAX_PHOTOS } from '~/utils/requests'

const { request, addPhoto, removePhoto } = useServiceRequest()
const { t } = useI18n()
const input = ref<HTMLInputElement | null>(null)
const uploading = ref(0)
const error = ref<string | null>(null)

const photos = computed(() => request.value?.photos ?? [])
const room = computed(() => MAX_PHOTOS - photos.value.length - uploading.value)

// Uploads run in parallel; each photo is shrunk on the phone first (see utils/image).
async function pick(e: Event) {
  const files = Array.from((e.target as HTMLInputElement).files ?? []).slice(0, Math.max(room.value, 0))
  if (input.value) input.value.value = ''
  error.value = null
  uploading.value += files.length
  await Promise.all(files.map(async (file) => {
    try {
      await addPhoto(file)
    }
    catch (err) {
      const apiErr = ApiError.from(err)
      error.value = Object.values(apiErr.fieldErrors)[0]?.[0] ?? apiErr.message
    }
    finally {
      uploading.value -= 1
    }
  }))
}
</script>

<template>
  <div class="flex flex-col gap-2">
    <span class="text-sm font-medium">{{ t('requests.photos') }} <span class="font-normal text-ink-muted">({{ t('common.optional') }})</span></span>
    <ul class="grid grid-cols-3 gap-2 sm:grid-cols-6">
      <li
        v-for="p in photos"
        :key="p.id"
        class="relative aspect-square overflow-hidden rounded-[var(--radius-control)] border border-border bg-surface-muted"
      >
        <img
          :src="p.file?.url"
          :alt="t('requests.photoAlt')"
          class="size-full object-cover"
        >
        <button
          type="button"
          class="absolute right-1 top-1 flex size-7 items-center justify-center rounded-full bg-ink/70 text-sm text-white"
          :aria-label="t('requests.removePhoto')"
          @click="removePhoto(p.id)"
        >
          ✕
        </button>
      </li>
      <li
        v-for="n in uploading"
        :key="`up-${n}`"
        class="flex aspect-square items-center justify-center rounded-[var(--radius-control)] border border-border bg-surface-muted text-xs text-ink-muted"
      >
        {{ t('requests.uploading') }}
      </li>
      <li v-if="room > 0">
        <label class="flex aspect-square cursor-pointer flex-col items-center justify-center gap-1 rounded-[var(--radius-control)] border border-dashed border-brand-600 bg-brand-50 text-center text-sm text-brand-700">
          <span
            class="text-2xl"
            aria-hidden="true"
          >📷</span>
          {{ t('requests.addPhoto') }}
          <input
            ref="input"
            type="file"
            accept="image/*"
            multiple
            class="sr-only"
            data-testid="photo-input"
            @change="pick"
          >
        </label>
      </li>
    </ul>
    <p class="text-xs text-ink-muted">
      {{ t('requests.photosHint', { max: MAX_PHOTOS }) }}
    </p>
    <p
      v-if="error"
      class="text-sm text-danger"
      role="alert"
    >
      {{ error }}
    </p>
  </div>
</template>
