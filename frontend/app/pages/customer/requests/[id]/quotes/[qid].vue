<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import type { Quotation } from '~/types/models'
import { ApiError } from '~/utils/api-error'
import { formatMoney } from '~/utils/money'
import { randomKey } from '~/utils/id'
import { quoteStatusTone } from '~/utils/quotes'

definePageMeta({ middleware: ['role'], roles: ['customer'] })

const route = useRoute()
const requestId = String(route.params.id)
const { find, accept, decline, live } = useQuotations()
const toast = useToast()
const { t, locale } = useI18n()
const duration = useDuration()

const quote = ref<Quotation | null>(null)
const gone = ref(false)
const confirmAccept = ref(false)
const accepting = ref(false)
const confirmDecline = ref(false)
const declining = ref(false)
const reason = ref('')
// One key per decision: a retry of the same tap can't book twice. A new decision gets a new key.
let acceptKey = ''
// What the customer agreed to in the dialog. Live updates may change `quote` while the dialog is
// open; the accept still sends this version, so a changed price fails with quotation_changed.
const pending = ref<{ id: string, current_version: number, total: string, kind: Quotation['kind'] } | null>(null)

async function load() {
  try {
    quote.value = await find(String(route.params.qid))
  }
  catch (e) {
    if (ApiError.from(e).status === 404) gone.value = true
    else throw e
  }
}

let stopLive = () => {}
onMounted(async () => {
  await load()
  // If the worker changes the price while the customer is reading, show the new one.
  stopLive = live(requestId, (msg) => {
    if (msg.id === quote.value?.id || msg.type === 'request.booked') void load()
  })
})
onBeforeUnmount(() => stopLive())

const canDecide = computed(() => quote.value?.status === 'submitted')
const name = computed(() => quote.value?.worker.name ?? '')
const total = computed(() => (quote.value ? formatMoney(quote.value.revision.total) : ''))

function openAccept() {
  if (!quote.value) return
  acceptKey = randomKey()
  pending.value = { id: quote.value.id, current_version: quote.value.current_version, total: total.value, kind: quote.value.kind }
  confirmAccept.value = true
}

async function doAccept() {
  if (!pending.value) return
  accepting.value = true
  try {
    const booking = await accept(pending.value, acceptKey)
    toast.success(t('compare.booked', { name: name.value }))
    await navigateTo(`/bookings/${booking.id}`)
  }
  catch (e) {
    const err = ApiError.from(e)
    confirmAccept.value = false
    if (err.code === 'quotation_changed') {
      toast.error(t('compare.changed'))
      await load()
    }
    else {
      toast.error(err.message)
      await load()
    }
  }
  finally {
    accepting.value = false
  }
}

async function doDecline() {
  if (!quote.value) return
  declining.value = true
  try {
    quote.value = { ...quote.value, ...(await decline(quote.value.id, reason.value.trim() || undefined)) }
    confirmDecline.value = false
    toast.success(t('compare.declined'))
  }
  catch (e) {
    toast.error(ApiError.from(e).message)
  }
  finally {
    declining.value = false
  }
}

const fmt = (iso: string) => new Intl.DateTimeFormat(locale.value, { dateStyle: 'medium', timeStyle: 'short', timeZone: 'Asia/Kolkata' }).format(new Date(iso))
</script>

<template>
  <div class="mx-auto flex max-w-xl flex-col gap-4">
    <NuxtLink
      :to="`/requests/${requestId}`"
      class="text-sm text-brand-700"
    >
      ← {{ t('compare.backToRequest') }}
    </NuxtLink>
    <UiEmptyState
      v-if="gone"
      :title="t('compare.notFound')"
    />
    <UiSkeleton
      v-else-if="!quote"
      :lines="6"
    />
    <template v-else>
      <UiCard>
        <CustomerWorkerSummary
          :worker="quote.worker"
          :distance-band="quote.distance_band"
        />
      </UiCard>
      <div class="flex items-end justify-between gap-2">
        <div class="flex flex-wrap gap-1">
          <UiBadge :tone="quote.kind === 'inspection' ? 'warning' : 'info'">
            {{ t(`compare.${quote.kind}`) }}
          </UiBadge>
          <UiBadge :tone="quoteStatusTone(quote.status)">
            {{ t(`quoteStatus.${quote.status}`) }}
          </UiBadge>
        </div>
        <strong
          class="text-3xl"
          data-testid="quote-detail-price"
        >{{ total }}</strong>
      </div>
      <p
        v-if="quote.kind === 'inspection'"
        class="rounded-[var(--radius-card)] bg-warning-soft p-3 text-sm text-warning"
      >
        {{ t('compare.inspectionNote') }}
      </p>
      <UiCard>
        <template #title>
          {{ t('compare.breakdown') }}
        </template>
        <SharedQuoteBreakdown :revision="quote.revision" />
        <p class="mt-3 text-sm text-ink-muted">
          <template v-if="quote.revision.estimated_minutes">
            {{ t('compare.estimate', { time: duration(quote.revision.estimated_minutes) }) }} ·
          </template>
          {{ t('compare.validUntil', { time: fmt(quote.valid_until) }) }}
        </p>
      </UiCard>
      <UiCard v-if="quote.revisions && quote.revisions.length > 1">
        <template #title>
          {{ t('compare.history') }}
        </template>
        <ol class="flex flex-col gap-1 text-sm">
          <li
            v-for="r in quote.revisions"
            :key="r.version"
            class="flex justify-between"
            :class="r.version === quote.current_version ? 'font-semibold' : 'text-ink-muted line-through'"
          >
            <span>{{ t('compare.version', { n: r.version }) }} · {{ fmt(r.created_at) }}</span>
            <span>{{ formatMoney(r.total) }}</span>
          </li>
        </ol>
      </UiCard>
      <NuxtLink
        v-if="quote.booking_id"
        :to="`/bookings/${quote.booking_id}`"
        class="inline-flex h-11 items-center justify-center rounded-[var(--radius-control)] bg-brand-700 px-4 font-medium text-white"
      >
        {{ t('booking.view') }}
      </NuxtLink>
      <div
        v-if="canDecide"
        class="flex flex-col gap-2 sm:flex-row"
      >
        <UiButton
          size="lg"
          data-testid="accept-quote"
          @click="openAccept"
        >
          {{ t('compare.accept') }} · {{ total }}
        </UiButton>
        <UiButton
          variant="secondary"
          size="lg"
          @click="confirmDecline = true"
        >
          {{ t('compare.decline') }}
        </UiButton>
      </div>
    </template>

    <UiConfirmDialog
      v-model:open="confirmAccept"
      :title="t('compare.acceptTitle', { name })"
      :message="pending?.kind === 'inspection' ? t('compare.acceptInspection', { total: pending.total, name }) : t('compare.acceptBody', { total: pending?.total ?? '', name })"
      :confirm-label="t('compare.accept')"
      :cancel-label="t('common.cancel')"
      :loading="accepting"
      @confirm="doAccept"
    />
    <UiModal
      v-model:open="confirmDecline"
      :title="t('compare.declineTitle')"
    >
      <form
        class="flex flex-col gap-4"
        @submit.prevent="doDecline"
      >
        <UiInput
          v-model="reason"
          :label="t('compare.declineReason')"
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
            {{ t('compare.decline') }}
          </UiButton>
        </div>
      </form>
    </UiModal>
  </div>
</template>
