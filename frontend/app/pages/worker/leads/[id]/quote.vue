<script setup lang="ts">
import { onMounted, ref } from 'vue'
import type { Lead, QuotationInput } from '~/types/models'
import { ApiError } from '~/utils/api-error'

definePageMeta({ middleware: ['worker-profile'] })

const route = useRoute()
const { find } = useLeads()
const { create, revise } = useQuotes()
const toast = useToast()
const { t } = useI18n()

const lead = ref<Lead | null>(null)
const gone = ref(false)
const saving = ref(false)
const form = ref<{ showServerErrors: (e: unknown) => void } | null>(null)

onMounted(async () => {
  try {
    lead.value = await find(String(route.params.id))
    if (lead.value.quotation && !lead.value.quotation.editable) await navigateTo(`/leads/${lead.value.id}`, { replace: true })
  }
  catch (e) {
    if ([403, 404].includes(ApiError.from(e).status)) gone.value = true
    else throw e
  }
})

async function save(body: QuotationInput) {
  saving.value = true
  try {
    const existing = lead.value!.quotation
    if (existing) await revise(existing.id, body)
    else await create(lead.value!.id, body)
    toast.success(existing ? t('quote.updated') : t('quote.sent'))
    await navigateTo(`/leads/${lead.value!.id}`)
  }
  catch (e) {
    const err = ApiError.from(e)
    if (err.code === 'validation_failed') {
      form.value?.showServerErrors(e)
      toast.error(t('quote.fixErrors'))
    }
    else {
      toast.error(err.message)
    }
  }
  finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="mx-auto flex max-w-xl flex-col gap-4">
    <NuxtLink
      :to="`/leads/${route.params.id}`"
      class="text-sm text-brand-700"
    >
      ← {{ lead?.category.name ?? t('worker.leads') }}
    </NuxtLink>
    <UiEmptyState
      v-if="gone"
      :title="t('leads.gone')"
      :description="t('leads.goneHint')"
    />
    <UiSkeleton
      v-else-if="!lead"
      :lines="8"
    />
    <template v-else>
      <div>
        <h1 class="text-2xl font-semibold">
          {{ lead.quotation ? t('quote.editTitle') : t('quote.title', { category: lead.category.name }) }}
        </h1>
        <p class="text-ink-muted">
          {{ lead.locality }} · {{ t(`distance.${lead.distance_band}`) }}
        </p>
      </div>
      <WorkerQuoteForm
        ref="form"
        :lead="lead"
        :initial="lead.quotation"
        :loading="saving"
        @submit="save"
      />
    </template>
  </div>
</template>
