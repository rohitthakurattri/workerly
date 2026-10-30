<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import type { DocKind } from '~/types/models'
import { ApiError } from '~/utils/api-error'
import { ACCEPTED_DOCUMENT_TYPES, DOC_TYPES, MAX_DOCUMENT_BYTES, lastRejection, liveDocument } from '~/utils/onboarding'

const props = defineProps<{ kind: DocKind, required: boolean }>()
const { profile, uploadDocument, removeDocument } = useWorkerProfile()
const { t } = useI18n()

const live = computed(() => (profile.value ? liveDocument(profile.value, props.kind) : undefined))
const rejected = computed(() => (profile.value && !live.value ? lastRejection(profile.value, props.kind) : undefined))
const editable = computed(() => profile.value?.editable ?? false)

const docType = ref(DOC_TYPES[props.kind][0]!)
const last4 = ref('')
const file = ref<File | null>(null)
const error = ref<string | null>(null)
const busy = ref(false)
watch(() => props.kind, () => { docType.value = DOC_TYPES[props.kind][0]! })

function pick(e: Event) {
  const f = (e.target as HTMLInputElement).files?.[0] ?? null
  error.value = f && f.size > MAX_DOCUMENT_BYTES ? t('onboarding.fileTooBig', { mb: 10 }) : null
  file.value = error.value ? null : f
}

async function upload() {
  if (!file.value) return
  busy.value = true
  error.value = null
  try {
    await uploadDocument({ kind: props.kind, doc_type: docType.value, number_last4: last4.value || undefined, file: file.value })
    file.value = null
    last4.value = ''
  }
  catch (e) {
    const err = ApiError.from(e)
    error.value = Object.values(err.fieldErrors)[0]?.[0] ?? err.message
  }
  finally {
    busy.value = false
  }
}

async function remove() {
  if (!live.value) return
  busy.value = true
  try {
    await removeDocument(live.value.id)
  }
  finally {
    busy.value = false
  }
}

const tone = (status: string) => ({ approved: 'success', pending: 'info', rejected: 'danger' } as const)[status as 'approved'] ?? 'neutral'
</script>

<template>
  <section
    class="rounded-[var(--radius-card)] border border-border bg-surface p-4"
    :data-testid="`doc-${kind}`"
  >
    <header class="mb-2 flex items-center justify-between gap-2">
      <h3 class="font-semibold">
        {{ t(`docKinds.${kind}`) }}
        <span
          v-if="!required"
          class="text-sm font-normal text-ink-muted"
        >({{ t('common.optional') }})</span>
      </h3>
      <UiBadge
        v-if="live"
        :tone="tone(live.status)"
      >
        {{ t(`docStatus.${live.status}`) }}
      </UiBadge>
    </header>

    <div
      v-if="live"
      class="flex items-center justify-between gap-2 text-sm"
    >
      <span>
        {{ t(`docTypes.${live.doc_type}`) }}<template v-if="live.number_last4"> · ••••{{ live.number_last4 }}</template>
      </span>
      <UiButton
        v-if="editable && live.status === 'pending'"
        variant="ghost"
        size="sm"
        :disabled="busy"
        @click="remove"
      >
        {{ t('common.remove') }}
      </UiButton>
    </div>

    <form
      v-else-if="editable"
      class="flex flex-col gap-3"
      @submit.prevent="upload"
    >
      <p
        v-if="rejected"
        class="rounded-[var(--radius-control)] bg-danger-soft px-3 py-2 text-sm text-danger"
      >
        {{ t('onboarding.docRejected', { reason: rejected.rejection_reason }) }}
      </p>
      <UiSelect
        v-model="docType"
        :label="t('onboarding.docType')"
        :options="DOC_TYPES[kind].map(d => ({ value: d, label: t(`docTypes.${d}`) }))"
      />
      <p
        v-if="docType === 'aadhaar_masked'"
        class="text-xs text-warning"
      >
        {{ t('onboarding.maskedAadhaar') }}
      </p>
      <UiInput
        v-model="last4"
        :label="t('onboarding.last4')"
        :hint="t('onboarding.last4Hint')"
        maxlength="4"
        autocomplete="off"
      />
      <label class="flex flex-col gap-1.5 text-sm">
        <span class="font-medium">{{ t('onboarding.file') }}</span>
        <input
          type="file"
          :accept="ACCEPTED_DOCUMENT_TYPES"
          class="text-sm file:mr-3 file:rounded-[var(--radius-control)] file:border file:border-border file:bg-surface-muted file:px-3 file:py-2"
          :data-testid="`file-${kind}`"
          @change="pick"
        >
        <span class="text-xs text-ink-muted">{{ t('onboarding.fileHint') }}</span>
      </label>
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
          variant="secondary"
          :loading="busy"
          :disabled="!file"
        >
          {{ t('onboarding.upload') }}
        </UiButton>
      </div>
    </form>
  </section>
</template>
