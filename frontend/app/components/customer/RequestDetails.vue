<script setup lang="ts">
import type { RequestStepId } from '~/utils/requests'
import type { ServiceRequest } from '~/types/models'

/** Read-only summary of a request, used on the review step and the request page. */
defineProps<{ request: ServiceRequest, editable?: boolean }>()
const emit = defineEmits<{ edit: [RequestStepId] }>()
const { t, locale } = useI18n()

function when(r: ServiceRequest) {
  if (!r.preferred_from || !r.preferred_to) return t(`urgency.${r.urgency}`)
  const fmt = new Intl.DateTimeFormat(locale.value, { weekday: 'short', day: 'numeric', month: 'short', hour: 'numeric', timeZone: 'Asia/Kolkata' })
  const to = new Intl.DateTimeFormat(locale.value, { hour: 'numeric', timeZone: 'Asia/Kolkata' })
  return `${t(`urgency.${r.urgency}`)} · ${fmt.format(new Date(r.preferred_from))} – ${to.format(new Date(r.preferred_to))}`
}
</script>

<template>
  <dl class="flex flex-col divide-y divide-border rounded-[var(--radius-card)] border border-border bg-surface">
    <div class="flex items-start justify-between gap-3 p-4">
      <div>
        <dt class="text-xs uppercase tracking-wide text-ink-muted">
          {{ t('requests.service') }}
        </dt>
        <dd class="font-semibold">
          {{ request.category?.name ?? '—' }}
        </dd>
      </div>
      <UiButton
        v-if="editable"
        variant="ghost"
        size="sm"
        @click="emit('edit', 'category')"
      >
        {{ t('requests.edit') }}
      </UiButton>
    </div>
    <div class="flex items-start justify-between gap-3 p-4">
      <div class="min-w-0">
        <dt class="text-xs uppercase tracking-wide text-ink-muted">
          {{ t('requests.problem') }}
        </dt>
        <dd class="whitespace-pre-line break-words">
          {{ request.description }}
        </dd>
        <dd
          v-if="request.ai_summary"
          class="mt-2 rounded-[var(--radius-control)] bg-surface-muted p-2 text-sm text-ink-muted"
        >
          <span class="font-medium">{{ t('requests.aiSummary') }}</span> {{ request.ai_summary }}
        </dd>
        <dd
          v-if="request.answers.length"
          class="mt-2 text-sm"
        >
          <p
            v-for="a in request.answers"
            :key="a.question"
          >
            <span class="text-ink-muted">{{ a.question }}</span> {{ a.answer }}
          </p>
        </dd>
        <dd
          v-if="request.photos.length"
          class="mt-2 flex gap-2 overflow-x-auto"
        >
          <img
            v-for="p in request.photos"
            :key="p.id"
            :src="p.file?.url"
            :alt="t('requests.photoAlt')"
            class="size-16 shrink-0 rounded-[var(--radius-control)] object-cover"
          >
        </dd>
      </div>
      <UiButton
        v-if="editable"
        variant="ghost"
        size="sm"
        @click="emit('edit', 'describe')"
      >
        {{ t('requests.edit') }}
      </UiButton>
    </div>
    <div class="flex items-start justify-between gap-3 p-4">
      <div>
        <dt class="text-xs uppercase tracking-wide text-ink-muted">
          {{ t('requests.address') }}
        </dt>
        <dd v-if="request.address">
          {{ request.address.line1 }}, {{ request.address.locality }} {{ request.address.pincode }}
        </dd>
      </div>
      <UiButton
        v-if="editable"
        variant="ghost"
        size="sm"
        @click="emit('edit', 'address')"
      >
        {{ t('requests.edit') }}
      </UiButton>
    </div>
    <div class="flex items-start justify-between gap-3 p-4">
      <div>
        <dt class="text-xs uppercase tracking-wide text-ink-muted">
          {{ t('requests.when') }}
        </dt>
        <dd>{{ when(request) }}</dd>
      </div>
      <UiButton
        v-if="editable"
        variant="ghost"
        size="sm"
        @click="emit('edit', 'when')"
      >
        {{ t('requests.edit') }}
      </UiButton>
    </div>
  </dl>
</template>
