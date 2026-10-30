<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { ApiError } from '~/utils/api-error'

definePageMeta({ middleware: ['role'], roles: ['customer'] })

const route = useRoute()
const { request, load, cancel } = useServiceRequest()
const toast = useToast()
const { t, locale } = useI18n()

const loading = ref(true)
const notFound = ref(false)
const cancelling = ref(false)
const confirmCancel = ref(false)
const reason = ref('')

onMounted(async () => {
  try {
    const r = await load(String(route.params.id))
    if (r.status === 'draft') return navigateTo({ path: '/requests/new', query: { id: r.id } }, { replace: true })
  }
  catch (e) {
    if (ApiError.from(e).status === 404) notFound.value = true
    else throw e
  }
  finally {
    loading.value = false
  }
})

async function doCancel() {
  cancelling.value = true
  try {
    await cancel(reason.value.trim() || undefined)
    confirmCancel.value = false
    toast.success(t('requests.cancelled'))
  }
  catch (e) {
    toast.error(ApiError.from(e).message)
  }
  finally {
    cancelling.value = false
  }
}

const fmt = (iso?: string | null) => iso ? new Intl.DateTimeFormat(locale.value, { dateStyle: 'medium', timeStyle: 'short', timeZone: 'Asia/Kolkata' }).format(new Date(iso)) : ''
</script>

<template>
  <div class="mx-auto flex max-w-xl flex-col gap-4">
    <NuxtLink
      to="/"
      class="text-sm text-brand-700"
    >
      ← {{ t('requests.backToRequests') }}
    </NuxtLink>
    <UiSkeleton
      v-if="loading"
      :lines="6"
    />
    <UiEmptyState
      v-else-if="notFound || !request"
      :title="t('requests.notFound')"
    />
    <template v-else>
      <div class="flex items-center justify-between gap-2">
        <h1 class="text-2xl font-semibold">
          {{ request.category?.name }}
        </h1>
        <CustomerRequestStatusBadge :status="request.status" />
      </div>
      <UiCard v-if="request.status === 'open' || request.status === 'quoting'">
        <p class="font-medium">
          {{ t('requests.waitingTitle') }}
        </p>
        <p class="mt-1 text-sm text-ink-muted">
          {{ t('requests.waitingBody', { time: fmt(request.expires_at) }) }}
        </p>
      </UiCard>
      <p
        v-else-if="request.status === 'cancelled'"
        class="text-sm text-ink-muted"
      >
        {{ t('requests.cancelledOn', { time: fmt(request.cancelled_at) }) }}
      </p>
      <CustomerSafetyNotice v-if="request.safety_flag && request.cancellable" />
      <CustomerRequestDetails :request="request" />
      <p class="text-xs text-ink-muted">
        {{ t('requests.sentOn', { time: fmt(request.submitted_at) }) }}
      </p>
      <div v-if="request.cancellable">
        <UiButton
          variant="secondary"
          @click="confirmCancel = true"
        >
          {{ t('requests.cancel') }}
        </UiButton>
      </div>
    </template>

    <UiModal
      v-model:open="confirmCancel"
      :title="t('requests.cancelTitle')"
    >
      <form
        class="flex flex-col gap-4"
        @submit.prevent="doCancel"
      >
        <p class="text-sm text-ink-muted">
          {{ t('requests.cancelBody') }}
        </p>
        <UiInput
          v-model="reason"
          :label="t('requests.cancelReason')"
          maxlength="500"
        />
        <div class="flex justify-end gap-2">
          <UiButton
            variant="ghost"
            @click="confirmCancel = false"
          >
            {{ t('requests.keep') }}
          </UiButton>
          <UiButton
            type="submit"
            variant="danger"
            :loading="cancelling"
          >
            {{ t('requests.cancel') }}
          </UiButton>
        </div>
      </form>
    </UiModal>
  </div>
</template>
