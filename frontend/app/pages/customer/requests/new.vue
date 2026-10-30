<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { ApiError } from '~/utils/api-error'
import { firstOpenRequestStep, REQUEST_STEPS, type RequestStepId } from '~/utils/requests'

// Five short steps, each saved as it's completed, so a dropped connection or a reload resumes
// the draft (?id=…) instead of starting over.
definePageMeta({ middleware: ['role'], roles: ['customer'] })

const route = useRoute()
const router = useRouter()
const { request, load, submit, discard, reset } = useServiceRequest()
const toast = useToast()
const { t } = useI18n()

const step = ref<RequestStepId>('describe')
const loading = ref(true)
const submitting = ref(false)
const confirmDiscard = ref(false)
const index = computed(() => REQUEST_STEPS.indexOf(step.value))

onMounted(async () => {
  reset()
  const id = route.query.id
  if (typeof id === 'string') {
    try {
      const r = await load(id)
      if (r.status !== 'draft') return navigateTo(`/requests/${r.id}`, { replace: true })
      step.value = firstOpenRequestStep(r)
    }
    catch {
      await router.replace({ query: {} })
    }
  }
  loading.value = false
})

function go(to: RequestStepId) {
  step.value = to
  if (request.value && route.query.id !== request.value.id) router.replace({ query: { id: request.value.id } })
  window.scrollTo({ top: 0 })
}

function next() {
  go(REQUEST_STEPS[index.value + 1] ?? 'review')
}

async function send() {
  submitting.value = true
  try {
    const r = await submit()
    toast.success(t('requests.sent'))
    await navigateTo(`/requests/${r.id}`, { replace: true })
  }
  catch (e) {
    const err = ApiError.from(e)
    toast.error(err.message)
    const missing = err.details.missing as string[] | undefined
    if (missing?.length && request.value) step.value = firstOpenRequestStep({ missing: missing as typeof request.value.missing })
  }
  finally {
    submitting.value = false
  }
}

async function doDiscard() {
  await discard()
  confirmDiscard.value = false
  await navigateTo('/', { replace: true })
}
</script>

<template>
  <div class="mx-auto flex max-w-xl flex-col gap-4">
    <div class="flex items-center justify-between gap-2">
      <h1 class="text-2xl font-semibold">
        {{ t('requests.newTitle') }}
      </h1>
      <UiButton
        v-if="request"
        variant="ghost"
        size="sm"
        @click="confirmDiscard = true"
      >
        {{ t('requests.discard') }}
      </UiButton>
    </div>

    <div
      class="flex gap-1"
      role="progressbar"
      :aria-valuenow="index + 1"
      aria-valuemin="1"
      :aria-valuemax="REQUEST_STEPS.length"
      :aria-label="t('requests.progress', { step: index + 1, total: REQUEST_STEPS.length })"
    >
      <span
        v-for="(s, i) in REQUEST_STEPS"
        :key="s"
        class="h-1.5 flex-1 rounded-full"
        :class="i <= index ? 'bg-brand-700' : 'bg-border'"
      />
    </div>
    <div class="flex items-center gap-2">
      <UiButton
        v-if="index > 0"
        variant="ghost"
        size="sm"
        :aria-label="t('requests.back')"
        @click="go(REQUEST_STEPS[index - 1]!)"
      >
        ←
      </UiButton>
      <h2 class="text-lg font-semibold">
        {{ t(`requests.steps.${step}`) }}
      </h2>
    </div>

    <UiSkeleton
      v-if="loading"
      :lines="5"
    />
    <template v-else>
      <CustomerStepDescribe
        v-if="step === 'describe'"
        @done="next"
      />
      <CustomerStepCategory
        v-else-if="step === 'category'"
        @done="next"
      />
      <CustomerStepAddress
        v-else-if="step === 'address'"
        @done="next"
      />
      <CustomerStepWhen
        v-else-if="step === 'when'"
        @done="next"
      />
      <div
        v-else-if="request"
        class="flex flex-col gap-4"
      >
        <CustomerSafetyNotice v-if="request.safety_flag" />
        <CustomerRequestDetails
          :request="request"
          editable
          @edit="go"
        />
        <p class="text-sm text-ink-muted">
          {{ t('requests.whatNext') }}
        </p>
        <UiButton
          size="lg"
          block
          :loading="submitting"
          @click="send"
        >
          {{ t('requests.send') }}
        </UiButton>
      </div>
    </template>

    <UiConfirmDialog
      v-model:open="confirmDiscard"
      :title="t('requests.discardTitle')"
      :message="t('requests.discardBody')"
      :confirm-label="t('requests.discard')"
      :cancel-label="t('common.cancel')"
      danger
      @confirm="doDiscard"
    />
  </div>
</template>
