<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import type { CommissionRule, Reconciliation, WorkerBalance } from '~/types/models'
import { ApiError } from '~/utils/api-error'
import { randomKey } from '~/utils/id'
import { formatMoney } from '~/utils/money'
import { bpsToPercent, percentToBps, toMinor } from '~/utils/payments'

definePageMeta({ middleware: ['role'], roles: ['admin', 'finance'] })

const TABS = ['balances', 'reconciliation', 'commission'] as const
type Tab = typeof TABS[number]

const api = useApi()
const toast = useToast()
const route = useRoute()
const router = useRouter()
const { t } = useI18n()
const { cities, categories, load: loadCatalog, leaves } = useCatalog()

const tab = ref<Tab>(TABS.includes(route.query.tab as Tab) ? (route.query.tab as Tab) : 'balances')
const busy = ref(false)
const inr = (minor: number) => formatMoney({ minor, currency: 'INR' })

async function attempt(fn: () => Promise<unknown>, done: string) {
  busy.value = true
  try {
    await fn()
    toast.success(done)
    return true
  }
  catch (e) {
    toast.error(ApiError.from(e).message)
    return false
  }
  finally {
    busy.value = false
  }
}

// --- Balances and payouts -------------------------------------------------
const balances = ref<WorkerBalance[] | null>(null)
const paying = ref<WorkerBalance | null>(null)
const payoutAmount = ref('')
const payoutRef = ref('')
let payoutKey = ''

const loadBalances = async () => {
  balances.value = (await api<{ data: WorkerBalance[] }>('/admin/finance/balances')).data
}
function openPayout(b: WorkerBalance) {
  paying.value = b
  payoutAmount.value = String(Math.max(b.net.minor, 0) / 100)
  payoutRef.value = ''
  payoutKey = randomKey()
}
const payoutMinor = computed(() => toMinor(payoutAmount.value))
const payoutError = computed(() => {
  if (!paying.value || !payoutAmount.value) return null
  if (payoutMinor.value === null) return t('finance.invalidAmount')
  if (payoutMinor.value > paying.value.net.minor) return t('finance.payoutTooMuch', { amount: formatMoney(paying.value.net) })
  return null
})
async function payout() {
  if (!paying.value || payoutMinor.value === null || payoutError.value) return
  const ok = await attempt(() => api('/admin/finance/payouts', {
    method: 'POST',
    body: { worker_id: paying.value!.worker_id, amount_minor: payoutMinor.value, reference: payoutRef.value.trim() },
    headers: { 'Idempotency-Key': payoutKey },
  }), t('finance.payoutRecorded'))
  if (ok) {
    paying.value = null
    await loadBalances()
  }
}

// --- Reconciliation --------------------------------------------------------
const today = () => new Date().toISOString().slice(0, 10)
const recFrom = ref(new Date(Date.now() - 86_400_000).toISOString().slice(0, 10))
const recTo = ref(today())
const rec = ref<Reconciliation | null>(null)
async function loadReconciliation() {
  try {
    rec.value = (await api<{ data: Reconciliation }>('/admin/finance/reconciliation', {
      query: { from: `${recFrom.value}T00:00:00+05:30`, to: `${recTo.value}T23:59:59+05:30` },
    })).data
  }
  catch (e) {
    toast.error(ApiError.from(e).message)
  }
}
const issueCount = computed(() => {
  const i = rec.value?.issues
  if (!i) return 0
  return i.payments_without_ledger.length + i.amount_mismatches.length + i.pending_refunds.length + i.stale_orders
})

// --- Commission rules ------------------------------------------------------
const rules = ref<CommissionRule[] | null>(null)
const ruleCity = ref('')
const ruleCategory = ref('')
const rulePercent = ref('')
const ruleFixed = ref('')
const ruleFrom = ref('')
const loadRules = async () => {
  rules.value = (await api<{ data: CommissionRule[] }>('/admin/finance/commission_rules')).data
}
const ruleBps = computed(() => percentToBps(rulePercent.value))
const ruleFixedMinor = computed(() => (ruleFixed.value.trim() ? toMinor(ruleFixed.value) : 0))
async function addRule() {
  if (ruleBps.value === null || ruleFixedMinor.value === null) return
  const ok = await attempt(() => api('/admin/finance/commission_rules', {
    method: 'POST',
    body: {
      city: ruleCity.value || undefined,
      category: ruleCategory.value || undefined,
      percent_bps: ruleBps.value,
      fixed_minor: ruleFixedMinor.value,
      effective_from: ruleFrom.value ? `${ruleFrom.value}T00:00:00+05:30` : undefined,
    },
  }), t('finance.ruleAdded'))
  if (ok) {
    rulePercent.value = ''
    ruleFixed.value = ''
    await loadRules()
  }
}
const cityName = (slug?: string | null) => (slug ? cities.value.find(c => c.slug === slug)?.name ?? slug : t('finance.allCities'))
const categoryName = (slug?: string | null) => (slug ? leaves(categories.value).find(c => c.slug === slug)?.name ?? slug : t('finance.allCategories'))
const isFuture = (iso: string) => new Date(iso).getTime() > Date.now()

// --- Tabs ------------------------------------------------------------------
async function show(which: Tab) {
  try {
    if (which === 'balances') await loadBalances()
    else if (which === 'reconciliation') await loadReconciliation()
    else await Promise.all([loadRules(), loadCatalog()])
  }
  catch (e) {
    toast.error(ApiError.from(e).message)
  }
}
watch(tab, (v) => {
  router.replace({ query: { ...route.query, tab: v } })
  void show(v)
})
onMounted(() => show(tab.value))

const fmt = (iso: string) => new Date(iso).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' })
</script>

<template>
  <div class="flex flex-col gap-4">
    <h1 class="text-2xl font-semibold">
      {{ t('admin.finance') }}
    </h1>
    <div
      class="flex flex-wrap gap-2"
      role="tablist"
    >
      <button
        v-for="s in TABS"
        :key="s"
        role="tab"
        :aria-selected="tab === s"
        class="rounded-full border px-3 py-1.5 text-sm"
        :class="tab === s ? 'border-brand-700 bg-brand-700 text-white' : 'border-border'"
        @click="tab = s"
      >
        {{ t(`finance.tabs.${s}`) }}
      </button>
    </div>

    <!-- Balances -->
    <template v-if="tab === 'balances'">
      <p class="text-sm text-ink-muted">
        {{ t('finance.balancesHint') }}
      </p>
      <UiSkeleton
        v-if="balances === null"
        :lines="4"
      />
      <UiTable
        v-else
        :rows="balances"
        row-key="worker_id"
        :caption="t('finance.tabs.balances')"
        :columns="[
          { key: 'name', label: t('admin.worker') },
          { key: 'held', label: t('finance.held'), align: 'right' },
          { key: 'owed', label: t('finance.owed'), align: 'right' },
          { key: 'net', label: t('finance.net'), align: 'right' },
          { key: 'actions', label: '', align: 'right' },
        ]"
      >
        <template #cell-name="{ row }">
          <NuxtLink
            :to="`/workers/${row.worker_id}`"
            class="font-medium text-brand-700"
          >{{ row.name || row.phone }}</NuxtLink>
        </template>
        <template #cell-held="{ row }">
          {{ formatMoney(row.held) }}
        </template>
        <template #cell-owed="{ row }">
          {{ formatMoney(row.owed) }}
        </template>
        <template #cell-net="{ row }">
          <span :class="row.net.minor < 0 && 'text-danger'">{{ formatMoney(row.net) }}</span>
        </template>
        <template #cell-actions="{ row }">
          <UiButton
            v-if="row.net.minor > 0"
            size="sm"
            data-testid="record-payout"
            @click="openPayout(row)"
          >
            {{ t('finance.recordPayout') }}
          </UiButton>
        </template>
        <template #empty>
          <UiEmptyState :title="t('finance.noBalances')" />
        </template>
      </UiTable>
    </template>

    <!-- Reconciliation -->
    <template v-else-if="tab === 'reconciliation'">
      <form
        class="flex flex-wrap items-end gap-3"
        @submit.prevent="loadReconciliation"
      >
        <UiInput
          v-model="recFrom"
          type="date"
          :label="t('finance.from')"
        />
        <UiInput
          v-model="recTo"
          type="date"
          :label="t('finance.to')"
        />
        <UiButton type="submit">
          {{ t('finance.run') }}
        </UiButton>
      </form>
      <UiSkeleton
        v-if="!rec"
        :lines="5"
      />
      <template v-else>
        <UiCard :class="rec.ledger_balanced ? 'border-success' : 'border-danger'">
          <p
            class="font-medium"
            :class="rec.ledger_balanced ? 'text-success' : 'text-danger'"
            data-testid="ledger-balanced"
          >
            {{ rec.ledger_balanced ? `✓ ${t('finance.ledgerBalanced')}` : `✗ ${t('finance.ledgerUnbalanced')}` }}
          </p>
          <p class="text-sm text-ink-muted">
            {{ t('finance.debitsCredits', { debits: inr(rec.ledger_debits_minor), credits: inr(rec.ledger_credits_minor) }) }}
          </p>
        </UiCard>
        <dl class="grid gap-3 sm:grid-cols-3">
          <UiCard
            v-for="[label, minor] in ([
              ['onlineCaptured', rec.online_captured_minor],
              ['cashRecorded', rec.cash_recorded_minor],
              ['commission', rec.commission_minor],
              ['tax', rec.tax_minor],
              ['refunded', rec.refunded_minor],
              ['payouts', rec.payouts_minor],
            ] as const)"
            :key="label"
          >
            <dt class="text-sm text-ink-muted">
              {{ t(`finance.rec.${label}`) }}
            </dt>
            <dd class="text-xl font-semibold tabular-nums">
              {{ inr(minor) }}
            </dd>
          </UiCard>
        </dl>
        <UiCard>
          <template #title>
            {{ t('finance.accountBalances') }}
          </template>
          <ul class="flex flex-col gap-1 text-sm">
            <li
              v-for="(minor, kind) in rec.balances"
              :key="kind"
              class="flex justify-between"
            >
              <span>{{ kind }}</span>
              <span class="tabular-nums">{{ inr(minor) }}</span>
            </li>
          </ul>
        </UiCard>
        <UiCard :class="issueCount && 'border-warning'">
          <template #title>
            {{ t('finance.issues', { n: issueCount }) }}
          </template>
          <p
            v-if="!issueCount"
            class="text-sm text-ink-muted"
          >
            {{ t('finance.noIssues') }}
          </p>
          <ul
            v-else
            class="flex flex-col gap-2 text-sm"
          >
            <li v-if="rec.issues.payments_without_ledger.length">
              <span class="font-medium">{{ t('finance.issue.unposted') }}:</span> {{ rec.issues.payments_without_ledger.join(', ') }}
            </li>
            <li v-if="rec.issues.amount_mismatches.length">
              <span class="font-medium">{{ t('finance.issue.mismatch') }}:</span> {{ rec.issues.amount_mismatches.join(', ') }}
            </li>
            <li v-if="rec.issues.pending_refunds.length">
              <span class="font-medium">{{ t('finance.issue.pendingRefunds') }}:</span> {{ rec.issues.pending_refunds.join(', ') }}
            </li>
            <li v-if="rec.issues.stale_orders">
              <span class="font-medium">{{ t('finance.issue.staleOrders') }}:</span> {{ rec.issues.stale_orders }}
            </li>
          </ul>
        </UiCard>
      </template>
    </template>

    <!-- Commission rules -->
    <template v-else>
      <p class="text-sm text-ink-muted">
        {{ t('finance.rulesHint') }}
      </p>
      <UiCard>
        <template #title>
          {{ t('finance.newRule') }}
        </template>
        <form
          class="grid gap-3 sm:grid-cols-2"
          @submit.prevent="addRule"
        >
          <UiSelect
            v-model="ruleCity"
            :label="t('finance.city')"
            :options="[{ value: '', label: t('finance.allCities') }, ...cities.map(c => ({ value: c.slug, label: c.name }))]"
          />
          <UiSelect
            v-model="ruleCategory"
            :label="t('finance.category')"
            :options="[{ value: '', label: t('finance.allCategories') }, ...leaves(categories).map(c => ({ value: c.slug, label: c.name }))]"
          />
          <UiInput
            v-model="rulePercent"
            :label="t('finance.percent')"
            inputmode="decimal"
            placeholder="10"
            :error="rulePercent && ruleBps === null ? t('finance.invalidPercent') : null"
            required
          />
          <UiInput
            v-model="ruleFixed"
            :label="t('finance.fixed')"
            inputmode="decimal"
            placeholder="0"
            :error="ruleFixedMinor === null ? t('finance.invalidAmount') : null"
          />
          <UiInput
            v-model="ruleFrom"
            type="date"
            :label="t('finance.effectiveFrom')"
            :hint="t('finance.effectiveFromHint')"
          />
          <div class="flex items-end">
            <UiButton
              type="submit"
              :disabled="ruleBps === null || ruleFixedMinor === null"
              :loading="busy"
            >
              {{ t('finance.addRule') }}
            </UiButton>
          </div>
        </form>
      </UiCard>
      <UiSkeleton
        v-if="rules === null"
        :lines="4"
      />
      <UiTable
        v-else
        :rows="rules"
        row-key="id"
        :caption="t('finance.tabs.commission')"
        :columns="[
          { key: 'city', label: t('finance.city') },
          { key: 'category', label: t('finance.category') },
          { key: 'percent_bps', label: t('finance.percent'), align: 'right' },
          { key: 'fixed_minor', label: t('finance.fixed'), align: 'right' },
          { key: 'effective_from', label: t('finance.effectiveFrom') },
        ]"
      >
        <template #cell-city="{ row }">
          {{ cityName(row.city) }}
        </template>
        <template #cell-category="{ row }">
          {{ categoryName(row.category) }}
        </template>
        <template #cell-percent_bps="{ row }">
          {{ bpsToPercent(row.percent_bps) }}
        </template>
        <template #cell-fixed_minor="{ row }">
          {{ inr(row.fixed_minor) }}
        </template>
        <template #cell-effective_from="{ row }">
          {{ fmt(row.effective_from) }}
          <UiBadge
            v-if="isFuture(row.effective_from)"
            tone="info"
          >
            {{ t('finance.scheduled') }}
          </UiBadge>
        </template>
        <template #empty>
          <UiEmptyState :title="t('finance.noRules')" />
        </template>
      </UiTable>
    </template>

    <UiModal
      :open="!!paying"
      :title="t('finance.recordPayout')"
      @update:open="v => { if (!v) paying = null }"
    >
      <form
        v-if="paying"
        class="flex flex-col gap-4"
        @submit.prevent="payout"
      >
        <p class="text-sm text-ink-muted">
          {{ t('finance.payoutHint', { name: paying.name || paying.phone, owed: formatMoney(paying.owed) }) }}
        </p>
        <UiInput
          v-model="payoutAmount"
          :label="t('finance.payoutAmount', { max: formatMoney(paying.net) })"
          inputmode="decimal"
          :error="payoutError"
          required
        />
        <UiInput
          v-model="payoutRef"
          :label="t('finance.reference')"
          :hint="t('finance.referenceHint')"
          maxlength="100"
          required
        />
        <div class="flex justify-end gap-2">
          <UiButton
            variant="ghost"
            @click="paying = null"
          >
            {{ t('common.cancel') }}
          </UiButton>
          <UiButton
            type="submit"
            :disabled="payoutMinor === null || !!payoutError || !payoutRef.trim()"
            :loading="busy"
          >
            {{ t('finance.recordPayout') }}
          </UiButton>
        </div>
      </form>
    </UiModal>
  </div>
</template>
