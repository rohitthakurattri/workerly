<script setup lang="ts">
import { onMounted, ref } from 'vue'
import type { Lead } from '~/types/models'
import { ApiError } from '~/utils/api-error'

definePageMeta({ middleware: ['worker-profile'] })

const route = useRoute()
const { find, decline } = useLeads()
const toast = useToast()
const { t, locale } = useI18n()

const lead = ref<Lead | null>(null)
const gone = ref(false)
const declining = ref(false)
const confirmDecline = ref(false)
const reason = ref('')

onMounted(async () => {
  try {
    lead.value = await find(String(route.params.id))
  }
  catch (e) {
    if ([403, 404].includes(ApiError.from(e).status)) gone.value = true
    else throw e
  }
})

async function doDecline() {
  declining.value = true
  try {
    await decline(lead.value!.id, reason.value.trim() || undefined)
    toast.success(t('leads.declined'))
    await navigateTo('/')
  }
  finally {
    declining.value = false
  }
}

const fmt = (iso: string) => new Intl.DateTimeFormat(locale.value, { weekday: 'short', day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit', timeZone: 'Asia/Kolkata' }).format(new Date(iso))
</script>

<template>
  <div class="mx-auto flex max-w-xl flex-col gap-4">
    <NuxtLink
      to="/"
      class="text-sm text-brand-700"
    >
      ← {{ t('worker.leads') }}
    </NuxtLink>
    <UiEmptyState
      v-if="gone"
      :title="t('leads.gone')"
      :description="t('leads.goneHint')"
    />
    <UiSkeleton
      v-else-if="!lead"
      :lines="6"
    />
    <template v-else>
      <div>
        <h1 class="text-2xl font-semibold">
          {{ lead.category.name }}
        </h1>
        <p class="text-ink-muted">
          {{ lead.locality }} · {{ t(`distance.${lead.distance_band}`) }}
        </p>
      </div>
      <div
        v-if="lead.safety_flag"
        class="rounded-[var(--radius-card)] border border-danger/30 bg-danger-soft p-3 text-sm text-danger"
        role="alert"
      >
        ⚠️ {{ t('leads.safety') }}
      </div>
      <UiCard>
        <dl class="flex flex-col gap-3">
          <div>
            <dt class="text-xs uppercase tracking-wide text-ink-muted">
              {{ t('requests.problem') }}
            </dt>
            <dd class="whitespace-pre-line break-words">
              {{ lead.description }}
            </dd>
            <dd
              v-if="lead.ai_summary"
              class="mt-2 rounded-[var(--radius-control)] bg-surface-muted p-2 text-sm text-ink-muted"
            >
              <span class="font-medium">{{ t('requests.aiSummary') }}</span> {{ lead.ai_summary }}
            </dd>
          </div>
          <div v-if="lead.answers.length">
            <dt class="text-xs uppercase tracking-wide text-ink-muted">
              {{ t('leads.details') }}
            </dt>
            <dd
              v-for="a in lead.answers"
              :key="a.question"
              class="text-sm"
            >
              <span class="text-ink-muted">{{ a.question }}</span> {{ a.answer }}
            </dd>
          </div>
          <div>
            <dt class="text-xs uppercase tracking-wide text-ink-muted">
              {{ t('requests.when') }}
            </dt>
            <dd>
              {{ t(`urgency.${lead.urgency}`) }}<template v-if="lead.preferred_from">
                · {{ fmt(lead.preferred_from) }}
              </template>
            </dd>
          </div>
          <div v-if="lead.photos.length">
            <dt class="mb-1 text-xs uppercase tracking-wide text-ink-muted">
              {{ t('requests.photos') }}
            </dt>
            <dd class="grid grid-cols-3 gap-2">
              <a
                v-for="p in lead.photos"
                :key="p.id"
                :href="p.file?.url"
                target="_blank"
                rel="noopener"
              >
                <img
                  :src="p.file?.url"
                  :alt="t('requests.photoAlt')"
                  class="aspect-square w-full rounded-[var(--radius-control)] object-cover"
                >
              </a>
            </dd>
          </div>
        </dl>
      </UiCard>
      <p class="text-sm text-ink-muted">
        {{ t('leads.privacy') }} {{ t('leads.openUntil', { time: fmt(lead.expires_at) }) }}
      </p>
      <div class="flex flex-wrap gap-2">
        <UiButton
          disabled
          :title="t('common.comingSoon')"
        >
          {{ t('leads.sendQuote') }}
        </UiButton>
        <UiButton
          variant="secondary"
          @click="confirmDecline = true"
        >
          {{ t('leads.decline') }}
        </UiButton>
      </div>
    </template>

    <UiModal
      v-model:open="confirmDecline"
      :title="t('leads.declineTitle')"
    >
      <form
        class="flex flex-col gap-4"
        @submit.prevent="doDecline"
      >
        <UiInput
          v-model="reason"
          :label="t('leads.declineReason')"
          maxlength="300"
        />
        <div class="flex justify-end gap-2">
          <UiButton
            variant="ghost"
            @click="confirmDecline = false"
          >
            {{ t('common.cancel') }}
          </UiButton>
          <UiButton
            type="submit"
            :loading="declining"
          >
            {{ t('leads.decline') }}
          </UiButton>
        </div>
      </form>
    </UiModal>
  </div>
</template>
