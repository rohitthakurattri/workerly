<script setup lang="ts">
import type { WorkerDocument } from '~/types/models'

/** One document with a large preview and an approve/reject choice. */
const props = defineProps<{ doc: WorkerDocument, decidable: boolean }>()
const verdict = defineModel<{ status: 'approved' | 'rejected' | '', reason: string }>({ required: true })
const { t } = useI18n()

const isPdf = () => props.doc.file?.content_type === 'application/pdf'
</script>

<template>
  <article
    class="flex flex-col gap-3 rounded-[var(--radius-card)] border border-border bg-surface p-4"
    :data-testid="`review-${doc.kind}`"
  >
    <header class="flex items-start justify-between gap-2">
      <div>
        <h3 class="font-semibold">
          {{ t(`docKinds.${doc.kind}`) }} · {{ t(`docTypes.${doc.doc_type}`) }}
        </h3>
        <p
          v-if="doc.number_last4"
          class="text-sm text-ink-muted"
        >
          {{ t('admin.endsWith', { last4: doc.number_last4 }) }}
        </p>
      </div>
      <UiBadge :tone="doc.status === 'approved' ? 'success' : doc.status === 'rejected' ? 'danger' : 'info'">
        {{ t(`docStatus.${doc.status}`) }}
      </UiBadge>
    </header>

    <!-- Signed URLs expire after 5 minutes; reload the page to get fresh ones. -->
    <a
      v-if="doc.file"
      :href="doc.file.url"
      target="_blank"
      rel="noopener noreferrer"
      class="block overflow-hidden rounded-[var(--radius-control)] border border-border bg-surface-muted"
    >
      <img
        v-if="!isPdf()"
        :src="doc.file.url"
        :alt="t(`docTypes.${doc.doc_type}`)"
        class="max-h-80 w-full object-contain"
      >
      <span
        v-else
        class="flex h-32 items-center justify-center text-sm text-brand-700 underline"
      >{{ t('admin.openPdf', { name: doc.file.filename }) }}</span>
    </a>
    <p
      v-if="doc.rejection_reason"
      class="text-sm text-danger"
    >
      {{ doc.rejection_reason }}
    </p>

    <fieldset
      v-if="decidable && doc.status === 'pending'"
      class="flex flex-col gap-2"
    >
      <legend class="sr-only">
        {{ t('admin.documentDecision') }}
      </legend>
      <div class="flex gap-2">
        <UiButton
          size="sm"
          :variant="verdict.status === 'approved' ? 'primary' : 'secondary'"
          :aria-pressed="verdict.status === 'approved'"
          @click="verdict = { status: 'approved', reason: '' }"
        >
          {{ t('admin.approveDoc') }}
        </UiButton>
        <UiButton
          size="sm"
          :variant="verdict.status === 'rejected' ? 'danger' : 'secondary'"
          :aria-pressed="verdict.status === 'rejected'"
          @click="verdict = { status: 'rejected', reason: verdict.reason }"
        >
          {{ t('admin.rejectDoc') }}
        </UiButton>
      </div>
      <UiInput
        v-if="verdict.status === 'rejected'"
        :model-value="verdict.reason"
        :label="t('admin.rejectReason')"
        :placeholder="t('admin.rejectReasonPlaceholder')"
        @update:model-value="verdict = { status: 'rejected', reason: $event }"
      />
    </fieldset>
  </article>
</template>
