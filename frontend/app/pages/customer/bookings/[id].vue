<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { ApiError } from '~/utils/api-error'
import { formatMoney } from '~/utils/money'
import { randomKey } from '~/utils/id'

definePageMeta({ middleware: ['role'], roles: ['customer'] })

const DISPUTE_CATEGORIES = ['no_show', 'quality', 'overcharge', 'damage', 'behaviour', 'other'] as const

const route = useRoute()
const { booking, messages, load, loadMessages, send, live, decide, cancel, review, dispute } = useBooking('customer')
const toast = useToast()
const { t, locale } = useI18n()

const gone = ref(false)
const busy = ref(false)
const confirmReject = ref(false)
const confirmCancel = ref(false)
const cancelReason = ref('')
const rating = ref(0)
const reviewText = ref('')
const disputeCategory = ref<string>('quality')
const disputeText = ref('')
const showDispute = ref(false)
// One key per decision on a pending price (a retried tap can't decide twice).
let decisionKey = ''
let stopLive = () => {}

onMounted(async () => {
  try {
    await load(String(route.params.id))
    await loadMessages()
    stopLive = live()
  }
  catch (e) {
    if (ApiError.from(e).status === 404) gone.value = true
    else throw e
  }
})
onBeforeUnmount(() => stopLive())

const name = computed(() => booking.value?.worker.name ?? '')
const pending = computed(() => booking.value?.pending_revision ?? null)
const isFinal = computed(() => booking.value?.status === 'awaiting_final_approval')
const visitFee = computed(() => {
  const fee = booking.value?.approvals.find(a => a.stage === 'inspection_fee' && a.decision === 'approved')
  return fee ? formatMoney(fee.total) : ''
})
const can = (action: string) => !!booking.value?.actions.includes(action as never)

async function run(fn: () => Promise<unknown>, done: string) {
  busy.value = true
  try {
    await fn()
    toast.success(done)
    return true
  }
  catch (e) {
    toast.error(ApiError.from(e).message)
    await load(booking.value!.id)
    return false
  }
  finally {
    busy.value = false
  }
}

// The key is kept after a failure, so retrying the same decision replays instead of deciding twice.
async function approve() {
  decisionKey ||= randomKey()
  if (await run(() => decide(pending.value!.id, 'approved', decisionKey), t('booking.approved'))) decisionKey = ''
}
async function reject() {
  decisionKey ||= randomKey()
  if (await run(() => decide(pending.value!.id, 'rejected', decisionKey), t('booking.rejected'))) decisionKey = ''
  confirmReject.value = false
}
async function doCancel() {
  if (await run(() => cancel(cancelReason.value.trim() || undefined), t('booking.cancelled'))) confirmCancel.value = false
}
const sendReview = () => rating.value && run(() => review(rating.value, reviewText.value.trim() || undefined), t('booking.reviewed'))
async function sendDispute() {
  if (await run(() => dispute(disputeCategory.value, disputeText.value.trim()), t('booking.disputed'))) showDispute.value = false
}

const fmt = (iso: string) => new Intl.DateTimeFormat(locale.value, { weekday: 'short', day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit', timeZone: 'Asia/Kolkata' }).format(new Date(iso))
</script>

<template>
  <div class="mx-auto flex max-w-xl flex-col gap-4">
    <NuxtLink
      :to="booking ? `/requests/${booking.request_id}` : '/'"
      class="text-sm text-brand-700"
    >
      ← {{ t('compare.backToRequest') }}
    </NuxtLink>
    <UiEmptyState
      v-if="gone"
      :title="t('booking.notFound')"
    />
    <UiSkeleton
      v-else-if="!booking"
      :lines="6"
    />
    <template v-else>
      <div class="flex flex-col gap-2">
        <p
          v-if="booking.status === 'confirmed'"
          class="text-sm font-medium text-success"
          data-testid="booking-confirmed"
        >
          ✓ {{ t('booking.title') }}
        </p>
        <h1 class="text-2xl font-semibold">
          {{ booking.category.name }}
        </h1>
        <SharedBookingProgress
          :kind="booking.kind"
          :status="booking.status"
        />
        <p class="text-sm text-ink-muted">
          <template v-if="booking.scheduled_at">
            {{ t('booking.visitAt', { time: fmt(booking.scheduled_at) }) }}
          </template>
          <template v-else-if="booking.status === 'confirmed'">
            {{ t('booking.notScheduled', { name }) }}
          </template>
        </p>
      </div>

      <!-- A price waiting for the customer -->
      <UiCard
        v-if="pending && can(isFinal ? 'approve_final' : 'approve_change')"
        class="border-warning"
        data-testid="pending-price"
      >
        <template #title>
          {{ t('booking.approveTitle', { name }) }}
        </template>
        <p class="mb-2 text-sm font-medium">
          {{ isFinal ? t('booking.finalLabel') : t('booking.changeLabel') }}
        </p>
        <SharedQuoteBreakdown :revision="pending" />
        <div class="mt-3 flex flex-col gap-2 sm:flex-row">
          <UiButton
            size="lg"
            :loading="busy"
            data-testid="approve-price"
            @click="approve"
          >
            {{ t('booking.approve', { amount: formatMoney(pending.total) }) }}
          </UiButton>
          <UiButton
            variant="secondary"
            size="lg"
            @click="confirmReject = true"
          >
            {{ t('booking.reject') }}
          </UiButton>
        </div>
      </UiCard>

      <UiCard>
        <template #title>
          {{ t('booking.worker') }}
        </template>
        <CustomerWorkerSummary :worker="booking.worker" />
        <a
          v-if="booking.worker.phone"
          :href="`tel:${booking.worker.phone}`"
          class="mt-3 inline-flex h-11 items-center rounded-[var(--radius-control)] bg-brand-700 px-4 font-medium text-white"
        >📞 {{ t('booking.call', { name: booking.worker.name || booking.worker.phone }) }}</a>
      </UiCard>

      <UiCard>
        <template #title>
          {{ t('booking.owed') }}: <span data-testid="amount-due">{{ formatMoney(booking.approved_total) }}</span>
        </template>
        <p class="mb-2 text-xs text-ink-muted">
          {{ t('booking.owedHint') }}
        </p>
        <SharedQuoteBreakdown :revision="booking.revision" />
        <ul
          v-if="booking.approvals.length > 1"
          class="mt-3 flex flex-col gap-1 text-sm"
        >
          <li
            v-for="a in booking.approvals"
            :key="a.revision_id"
            class="flex justify-between"
            :class="a.decision === 'rejected' && 'text-ink-muted line-through'"
          >
            <span>{{ t(`quote.stages.${a.stage}`) }}</span>
            <span>{{ formatMoney(a.total) }}</span>
          </li>
        </ul>
      </UiCard>

      <!-- After the work -->
      <UiCard v-if="booking.can_review">
        <template #title>
          {{ t('booking.reviewTitle', { name }) }}
        </template>
        <form
          class="flex flex-col gap-3"
          @submit.prevent="sendReview"
        >
          <div
            class="flex gap-1"
            role="radiogroup"
            :aria-label="t('booking.reviewTitle', { name })"
          >
            <button
              v-for="n in 5"
              :key="n"
              type="button"
              role="radio"
              :aria-checked="rating === n"
              :aria-label="t('booking.stars', { n })"
              class="text-3xl"
              :class="n <= rating ? 'text-warning' : 'text-border'"
              @click="rating = n"
            >
              ★
            </button>
          </div>
          <UiInput
            v-model="reviewText"
            :label="t('booking.reviewBody')"
            maxlength="1000"
          />
          <div>
            <UiButton
              type="submit"
              :disabled="!rating"
              :loading="busy"
            >
              {{ t('booking.reviewSend') }}
            </UiButton>
          </div>
        </form>
      </UiCard>
      <p
        v-else-if="booking.review"
        class="text-sm font-medium"
      >
        {{ t('booking.yourRating', { rating: booking.review.rating }) }}
      </p>

      <UiCard v-if="booking.dispute">
        <p
          v-if="booking.dispute.status === 'open'"
          class="text-sm"
        >
          {{ t('booking.disputeOpen', { category: t(`disputeCategory.${booking.dispute.category}`) }) }}
        </p>
        <p
          v-else
          class="text-sm"
        >
          {{ t('booking.disputeResolved', { resolution: booking.dispute.resolution }) }}
        </p>
      </UiCard>
      <div v-if="booking.can_dispute && !showDispute">
        <UiButton
          variant="ghost"
          @click="showDispute = true"
        >
          {{ t('booking.disputeTitle') }}
        </UiButton>
      </div>
      <UiCard v-if="showDispute">
        <template #title>
          {{ t('booking.disputeTitle') }}
        </template>
        <form
          class="flex flex-col gap-3"
          @submit.prevent="sendDispute"
        >
          <p class="text-sm text-ink-muted">
            {{ t('booking.disputeHint') }}
          </p>
          <UiSelect
            v-model="disputeCategory"
            :label="t('booking.disputeCategory')"
            :options="DISPUTE_CATEGORIES.map(c => ({ value: c, label: t(`disputeCategory.${c}`) }))"
          />
          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium">{{ t('booking.disputeDescription') }}</span>
            <textarea
              v-model="disputeText"
              rows="3"
              maxlength="2000"
              required
              class="rounded-[var(--radius-control)] border border-border bg-surface p-3"
            />
          </label>
          <div class="flex gap-2">
            <UiButton
              type="submit"
              :disabled="!disputeText.trim()"
              :loading="busy"
            >
              {{ t('booking.disputeSend') }}
            </UiButton>
            <UiButton
              variant="ghost"
              @click="showDispute = false"
            >
              {{ t('common.cancel') }}
            </UiButton>
          </div>
        </form>
      </UiCard>

      <SharedBookingChat
        :messages="messages"
        me="customer"
        :open="booking.chat_open"
        :send="send"
      />

      <div v-if="can('cancel')">
        <UiButton
          variant="ghost"
          @click="confirmCancel = true"
        >
          {{ t('booking.cancel') }}
        </UiButton>
      </div>
    </template>

    <UiConfirmDialog
      v-model:open="confirmReject"
      :title="isFinal ? t('booking.rejectFinalTitle') : t('booking.rejectChangeTitle')"
      :message="isFinal ? t('booking.rejectFinalBody', { fee: visitFee }) : t('booking.rejectChangeBody')"
      :confirm-label="t('booking.reject')"
      :cancel-label="t('common.cancel')"
      :loading="busy"
      @confirm="reject"
    />
    <UiModal
      v-model:open="confirmCancel"
      :title="t('booking.cancelTitle')"
    >
      <form
        class="flex flex-col gap-4"
        @submit.prevent="doCancel"
      >
        <p class="text-sm text-ink-muted">
          {{ booking?.checked_in_at && booking.kind === 'inspection' ? t('booking.cancelFeeBody', { fee: visitFee }) : t('booking.cancelBody') }}
        </p>
        <UiInput
          v-model="cancelReason"
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
            :loading="busy"
          >
            {{ t('booking.cancel') }}
          </UiButton>
        </div>
      </form>
    </UiModal>
  </div>
</template>
