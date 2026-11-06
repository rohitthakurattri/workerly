<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import type { QuotationInput } from '~/types/models'
import { ApiError } from '~/utils/api-error'
import { fromLocalInput, toLocalInput } from '~/utils/bookings'
import { randomKey } from '~/utils/id'
import { formatMoney } from '~/utils/money'
import { paymentTone } from '~/utils/payments'

definePageMeta({ middleware: ['worker-profile'] })

const TZ = 'Asia/Kolkata'
const route = useRoute()
const { booking: job, messages, load, loadMessages, send, live, schedule, checkIn, start, complete, finalQuotation, changeOrder, cashReceived, cancel } = useBooking('worker')
const toast = useToast()
const { t, locale } = useI18n()

const gone = ref(false)
const busy = ref(false)
const when = ref('')
const priceForm = ref<'final' | 'change' | null>(null)
const confirmComplete = ref(false)
const confirmCancel = ref(false)
const cancelReason = ref('')
const confirmCash = ref(false)
// Kept after a failure so a retried tap records the cash once.
let cashKey = ''
const form = ref<{ showServerErrors: (e: unknown) => void } | null>(null)
let stopLive = () => {}

onMounted(async () => {
  try {
    await load(String(route.params.id))
    when.value = toLocalInput(job.value!.scheduled_at, TZ)
    await loadMessages()
    stopLive = live(() => {
      when.value = toLocalInput(job.value?.scheduled_at, TZ)
    })
  }
  catch (e) {
    if ([403, 404].includes(ApiError.from(e).status)) gone.value = true
    else throw e
  }
})
onBeforeUnmount(() => stopLive())

const can = (action: string) => !!job.value?.actions.includes(action as never)
const mapUrl = computed(() => {
  const loc = job.value?.address?.location
  return loc ? `https://www.google.com/maps/search/?api=1&query=${loc.lat},${loc.lng}` : null
})
const minWhen = computed(() => toLocalInput(new Date(Date.now() + 5 * 60_000).toISOString(), TZ))

async function run(fn: () => Promise<unknown>, done: string) {
  busy.value = true
  try {
    await fn()
    toast.success(done)
    return true
  }
  catch (e) {
    const err = ApiError.from(e)
    if (err.code === 'validation_failed' && priceForm.value) form.value?.showServerErrors(e)
    toast.error(err.message)
    return false
  }
  finally {
    busy.value = false
  }
}

const saveTime = () => when.value && run(() => schedule(fromLocalInput(when.value, TZ)), t('jobs.timeSet'))
async function sendPrice(body: QuotationInput) {
  const ok = await run(() => (priceForm.value === 'final' ? finalQuotation(body) : changeOrder(body)), t('quote.sent'))
  if (ok) priceForm.value = null
}
async function doComplete() {
  if (await run(complete, t('jobs.completed'))) confirmComplete.value = false
}
async function doCash() {
  cashKey ||= randomKey()
  if (await run(() => cashReceived(job.value!.outstanding.minor, cashKey), t('jobs.cashRecorded'))) {
    cashKey = ''
    confirmCash.value = false
  }
}
async function doCancel() {
  if (await run(() => cancel(cancelReason.value.trim() || undefined), t('jobs.cancelled'))) confirmCancel.value = false
}

const fmt = (iso: string) => new Intl.DateTimeFormat(locale.value, { weekday: 'short', day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit', timeZone: TZ }).format(new Date(iso))
</script>

<template>
  <div class="mx-auto flex max-w-xl flex-col gap-4">
    <NuxtLink
      to="/"
      class="text-sm text-brand-700"
    >
      ← {{ t('jobs.title') }}
    </NuxtLink>
    <UiEmptyState
      v-if="gone"
      :title="t('jobs.gone')"
    />
    <UiSkeleton
      v-else-if="!job"
      :lines="6"
    />
    <template v-else>
      <div class="flex flex-col gap-2">
        <h1 class="text-2xl font-semibold">
          {{ job.category.name }}
        </h1>
        <SharedBookingProgress
          :kind="job.kind"
          :status="job.status"
        />
      </div>

      <!-- What the worker can do now -->
      <UiCard data-testid="job-actions">
        <div class="flex flex-col gap-3">
          <p
            v-if="job.pending_revision"
            class="rounded-[var(--radius-control)] bg-warning-soft p-3 text-sm text-warning"
          >
            {{ t('jobs.waitingApproval', { amount: formatMoney(job.pending_revision.total) }) }}
          </p>
          <form
            v-if="can('schedule')"
            class="flex flex-wrap items-end gap-2"
            @submit.prevent="saveTime"
          >
            <label class="flex flex-col gap-1">
              <span class="text-sm font-medium">{{ t('jobs.visitTime') }}</span>
              <input
                v-model="when"
                type="datetime-local"
                :min="minWhen"
                required
                class="h-11 rounded-[var(--radius-control)] border border-border bg-surface px-3"
                data-testid="visit-time"
              >
            </label>
            <UiButton
              type="submit"
              :loading="busy"
              :variant="job.scheduled_at ? 'secondary' : 'primary'"
            >
              {{ job.scheduled_at ? t('jobs.changeTime') : t('jobs.setTime') }}
            </UiButton>
          </form>
          <p
            v-else-if="job.scheduled_at"
            class="text-sm"
          >
            {{ t('booking.visitAt', { time: fmt(job.scheduled_at) }) }}
          </p>
          <div class="flex flex-wrap gap-2">
            <UiButton
              v-if="can('check_in')"
              :loading="busy"
              @click="run(checkIn, t('jobs.checkedIn'))"
            >
              {{ t('jobs.checkIn') }}
            </UiButton>
            <UiButton
              v-if="can('final_quotation')"
              @click="priceForm = 'final'"
            >
              {{ t('jobs.sendFinal') }}
            </UiButton>
            <UiButton
              v-if="can('start')"
              :loading="busy"
              @click="run(start, t('jobs.started'))"
            >
              {{ t('jobs.start') }}
            </UiButton>
            <UiButton
              v-if="can('complete')"
              @click="confirmComplete = true"
            >
              {{ t('jobs.complete') }}
            </UiButton>
            <UiButton
              v-if="can('change_order')"
              variant="secondary"
              @click="priceForm = 'change'"
            >
              {{ t('jobs.sendChange') }}
            </UiButton>
            <UiButton
              v-if="can('cancel')"
              variant="ghost"
              @click="confirmCancel = true"
            >
              {{ t('jobs.cancel') }}
            </UiButton>
          </div>
          <p
            v-if="!job.actions.length && !job.pending_revision"
            class="text-sm text-ink-muted"
          >
            {{ t('jobs.noActions') }}
          </p>
        </div>
      </UiCard>

      <UiCard v-if="priceForm">
        <template #title>
          {{ priceForm === 'final' ? t('jobs.finalTitle') : t('jobs.changeTitle') }}
        </template>
        <p class="mb-3 text-sm text-ink-muted">
          {{ priceForm === 'final' ? t('jobs.finalHint') : t('jobs.changeHint') }}
        </p>
        <WorkerQuoteForm
          ref="form"
          :currency="job.currency"
          :tax-rate-bps="job.tax_rate_bps"
          :mode="priceForm"
          :loading="busy"
          @submit="sendPrice"
        />
        <UiButton
          class="mt-2"
          variant="ghost"
          @click="priceForm = null"
        >
          {{ t('common.cancel') }}
        </UiButton>
      </UiCard>

      <UiCard>
        <dl class="flex flex-col gap-3">
          <div v-if="job.customer">
            <dt class="text-xs uppercase tracking-wide text-ink-muted">
              {{ t('jobs.customer') }}
            </dt>
            <dd class="font-medium">
              {{ job.customer.name }}
            </dd>
            <dd class="mt-1">
              <a
                :href="`tel:${job.customer.phone}`"
                class="inline-flex h-11 items-center rounded-[var(--radius-control)] bg-brand-700 px-4 font-medium text-white"
                data-testid="call-customer"
              >📞 {{ t('jobs.call', { name: job.customer.name || job.customer.phone }) }}</a>
            </dd>
          </div>
          <p
            v-else
            class="text-sm text-ink-muted"
          >
            {{ t('jobs.contactHidden') }}
          </p>
          <div v-if="job.address">
            <dt class="text-xs uppercase tracking-wide text-ink-muted">
              {{ t('jobs.address') }}
            </dt>
            <dd data-testid="job-address">
              {{ job.address.line1 }}<template v-if="job.address.line2">
                , {{ job.address.line2 }}
              </template><br>
              <template v-if="job.address.landmark">
                {{ job.address.landmark }},
              </template>{{ job.address.locality }} {{ job.address.pincode }}
            </dd>
            <dd v-if="mapUrl">
              <a
                :href="mapUrl"
                target="_blank"
                rel="noopener"
                class="text-sm text-brand-700"
              >{{ t('jobs.openMap') }} ↗</a>
            </dd>
          </div>
          <div>
            <dt class="text-xs uppercase tracking-wide text-ink-muted">
              {{ t('requests.when') }}
            </dt>
            <dd>
              {{ t(`urgency.${job.urgency}`) }}<template v-if="job.preferred_from">
                · {{ fmt(job.preferred_from) }}
              </template>
            </dd>
          </div>
          <div>
            <dt class="text-xs uppercase tracking-wide text-ink-muted">
              {{ t('jobs.problem') }}
            </dt>
            <dd class="whitespace-pre-line break-words">
              {{ job.description }}
            </dd>
          </div>
          <div v-if="job.photos.length">
            <dd class="grid grid-cols-3 gap-2">
              <a
                v-for="p in job.photos"
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

      <UiCard>
        <template #title>
          {{ t('jobs.owed') }}: <span data-testid="amount-due">{{ formatMoney(job.approved_total) }}</span>
        </template>
        <p class="mb-2 text-xs text-ink-muted">
          {{ t('jobs.owedHint') }}
        </p>
        <SharedQuoteBreakdown :revision="job.revision" />
        <ul
          v-if="job.approvals.length > 1"
          class="mt-3 flex flex-col gap-1 text-sm"
        >
          <li
            v-for="a in job.approvals"
            :key="a.revision_id"
            class="flex justify-between"
            :class="a.decision === 'rejected' && 'text-ink-muted line-through'"
          >
            <span>{{ t(`quote.stages.${a.stage}`) }} · {{ t('quote.version', { n: a.version }) }}</span>
            <span>{{ formatMoney(a.total) }}</span>
          </li>
        </ul>
        <p
          v-if="job.review"
          class="mt-3 text-sm font-medium"
        >
          {{ t('jobs.rating', { rating: job.review.rating }) }}<template v-if="job.review.body">
            · “{{ job.review.body }}”
          </template>
        </p>
      </UiCard>

      <UiCard
        v-if="job.payable || job.payments.length"
        :class="job.payable && 'border-warning'"
        data-testid="payment-card"
      >
        <template #title>
          <template v-if="job.payable">
            {{ t('jobs.toCollect') }}: <span data-testid="outstanding">{{ formatMoney(job.outstanding) }}</span>
          </template>
          <template v-else>
            ✓ {{ t('pay.paidInFull') }}
          </template>
        </template>
        <div
          v-if="job.payable"
          class="flex flex-col gap-2"
        >
          <p class="text-sm text-ink-muted">
            {{ t('jobs.collectHint') }}
          </p>
          <div>
            <UiButton
              variant="secondary"
              data-testid="cash-received"
              @click="confirmCash = true"
            >
              {{ t('jobs.cashReceived') }}
            </UiButton>
          </div>
        </div>
        <ul
          v-if="job.payments.length"
          class="mt-3 flex flex-col gap-1 text-sm"
        >
          <li
            v-for="p in job.payments"
            :key="p.id"
            class="flex items-center justify-between gap-2"
          >
            <span>{{ t(`pay.method.${p.method}`) }}</span>
            <span class="flex items-center gap-2">
              <UiBadge :tone="paymentTone(p.status)">{{ t(`paymentStatus.${p.status}`) }}</UiBadge>
              {{ formatMoney(p.amount) }}
            </span>
          </li>
        </ul>
        <NuxtLink
          v-if="job.invoice_number"
          :to="`/jobs/${job.id}/invoice`"
          class="mt-3 inline-block text-sm text-brand-700"
        >
          {{ t('invoice.view', { number: job.invoice_number }) }} →
        </NuxtLink>
      </UiCard>

      <SharedBookingChat
        :messages="messages"
        me="worker"
        :open="job.chat_open"
        :send="send"
      />
      <p class="text-sm text-ink-muted">
        {{ t('jobs.nextSteps') }}
      </p>
    </template>

    <UiConfirmDialog
      v-model:open="confirmComplete"
      :title="t('jobs.completeTitle')"
      :message="t('jobs.completeBody')"
      :confirm-label="t('jobs.complete')"
      :cancel-label="t('common.cancel')"
      :loading="busy"
      @confirm="doComplete"
    />
    <UiModal
      v-model:open="confirmCancel"
      :title="t('jobs.cancelTitle')"
    >
      <form
        class="flex flex-col gap-4"
        @submit.prevent="doCancel"
      >
        <p class="text-sm text-ink-muted">
          {{ t('jobs.cancelBody') }}
        </p>
        <UiInput
          v-model="cancelReason"
          :label="t('leads.declineReason')"
          maxlength="500"
        />
        <div class="flex justify-end gap-2">
          <UiButton
            variant="ghost"
            @click="confirmCancel = false"
          >
            {{ t('common.cancel') }}
          </UiButton>
          <UiButton
            type="submit"
            variant="danger"
            :loading="busy"
          >
            {{ t('jobs.cancel') }}
          </UiButton>
        </div>
      </form>
    </UiModal>
    <UiConfirmDialog
      v-model:open="confirmCash"
      :title="t('jobs.cashTitle')"
      :message="job ? t('jobs.cashBody', { amount: formatMoney(job.outstanding) }) : ''"
      :confirm-label="t('jobs.cashConfirm')"
      :cancel-label="t('common.cancel')"
      :loading="busy"
      @confirm="doCash"
    />
  </div>
</template>
