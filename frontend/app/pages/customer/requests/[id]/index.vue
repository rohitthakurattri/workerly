<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import type { Quotation } from '~/types/models'
import { ApiError } from '~/utils/api-error'
import { formatMoney } from '~/utils/money'
import { sortQuotes, type QuoteSort } from '~/utils/quotes'

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

// Quotes: loaded with the request, then kept fresh over RequestChannel.
const { list: listQuotes, live } = useQuotations()
const quotes = ref<Quotation[] | null>(null)
const sortBy = ref<QuoteSort>('price')
const view = ref<'cards' | 'table'>('cards')
const sorted = computed(() => sortQuotes(quotes.value ?? [], sortBy.value))
const accepted = computed(() => quotes.value?.find(q => q.status === 'accepted'))
let stopLive = () => {}

async function refreshQuotes(announce?: string) {
  if (!request.value) return
  quotes.value = await listQuotes(request.value.id)
  const q = announce && quotes.value.find(x => x.id === announce)
  if (q) toast.show(t('compare.arrived', { amount: formatMoney(q.revision.total) }), 'info')
}

function watchQuotes() {
  const r = request.value
  if (!r || !['open', 'quoting', 'booked'].includes(r.status)) return
  void refreshQuotes()
  if (r.status === 'booked') return
  stopLive = live(r.id, async (msg) => {
    await load(r.id)
    await refreshQuotes(msg.type === 'quote.new' ? msg.id : undefined)
    if (msg.type === 'request.booked') stopLive()
  }, () => void refreshQuotes())
}
onBeforeUnmount(() => stopLive())

// Matching runs in the background right after submit; poll briefly until it has run.
let poll: ReturnType<typeof setTimeout> | undefined
function pollMatching(tries = 10) {
  if (!request.value || request.value.matched_at || request.value.status !== 'open' || tries <= 0) return
  poll = setTimeout(async () => {
    await load(request.value!.id)
    pollMatching(tries - 1)
  }, 2000)
}
onBeforeUnmount(() => clearTimeout(poll))

onMounted(async () => {
  try {
    const r = await load(String(route.params.id))
    if (r.status === 'draft') return navigateTo({ path: '/requests/new', query: { id: r.id } }, { replace: true })
    pollMatching()
    watchQuotes()
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
      <UiCard
        v-if="request.status === 'booked' && request.booking_id"
        class="border-success"
      >
        <p class="font-medium">
          {{ t('booking.bookedWith', { name: accepted?.worker.name ?? '' }) }}
        </p>
        <NuxtLink
          :to="`/bookings/${request.booking_id}`"
          class="mt-2 inline-flex h-11 items-center rounded-[var(--radius-control)] bg-brand-700 px-4 font-medium text-white"
        >
          {{ t('booking.view') }}
        </NuxtLink>
      </UiCard>
      <UiCard v-if="request.status === 'open' || request.status === 'quoting'">
        <p class="font-medium">
          {{ t('requests.waitingTitle') }}
        </p>
        <p
          class="mt-1 text-sm"
          :class="request.matched_at && !request.invited_count ? 'text-warning' : 'text-ink-muted'"
          data-testid="match-status"
        >
          <template v-if="!request.matched_at">
            {{ t('requests.finding') }}
          </template>
          <template v-else-if="request.invited_count">
            {{ t('requests.sentTo', { count: request.invited_count }, request.invited_count) }}
          </template>
          <template v-else>
            {{ t('requests.nobodyYet') }}
          </template>
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
      <section
        v-if="quotes !== null && (quotes.length || request.status === 'open' || request.status === 'quoting')"
        class="flex flex-col gap-3"
        aria-labelledby="quotes-title"
      >
        <div class="flex flex-wrap items-center justify-between gap-2">
          <h2
            id="quotes-title"
            class="text-lg font-semibold"
          >
            {{ t('compare.title') }} <span
              v-if="quotes.length"
              class="text-ink-muted"
            >({{ quotes.length }})</span>
          </h2>
          <div
            v-if="quotes.length > 1"
            class="flex gap-2"
          >
            <UiSelect
              v-model="sortBy"
              class="w-36"
              :label="t('compare.sortBy')"
              :options="(['price', 'rating', 'distance'] as const).map(v => ({ value: v, label: t(`compare.sort.${v}`) }))"
            />
            <UiSelect
              v-model="view"
              class="w-32"
              :label="t('compare.table')"
              :options="[{ value: 'cards', label: t('compare.cards') }, { value: 'table', label: t('compare.table') }]"
            />
          </div>
        </div>
        <p
          v-if="!quotes.length"
          class="text-sm text-ink-muted"
          data-testid="no-quotes"
        >
          {{ t('compare.none') }}
        </p>
        <CustomerQuoteCompare
          v-else-if="view === 'table'"
          :quotes="sorted"
          :request-id="request.id"
        />
        <template v-else>
          <CustomerQuoteCard
            v-for="q in sorted"
            :key="q.id"
            :quote="q"
            :request-id="request.id"
          />
        </template>
      </section>
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
