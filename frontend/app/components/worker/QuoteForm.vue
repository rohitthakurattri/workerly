<script setup lang="ts">
import { computed, ref } from 'vue'
import type { QuotationInput, QuotationKind, WorkerQuotation } from '~/types/models'
import { ApiError } from '~/utils/api-error'
import { formatMoney } from '~/utils/money'
import {
  blankLine, CONDITIONS, fromMinor, ITEM_TYPES, lineAmount, linesFromQuote, linesToInput,
  MAX_ITEMS, MAX_TOTAL_MINOR, quoteTotals, taxFor, toMinor, UNITS, type QuoteLine,
} from '~/utils/quotes'

// mode "quote": a first quote or a change (fixed or inspection). "final" and "change": during a
// booking, the price after an inspection or extra charges; always itemised, never an inspection.
const props = withDefaults(defineProps<{
  currency: string
  taxRateBps: number
  inspectionAllowed?: boolean
  initial?: WorkerQuotation | null
  loading?: boolean
  mode?: 'quote' | 'final' | 'change'
}>(), { inspectionAllowed: false, initial: null, loading: false, mode: 'quote' })
const emit = defineEmits<{ submit: [body: QuotationInput] }>()
defineExpose({ showServerErrors })

const { t } = useI18n()
const currency = computed(() => props.currency)
const money = (minor: number) => formatMoney({ minor, currency: currency.value })

const kind = ref<QuotationKind>(props.initial?.kind ?? 'fixed')
const lines = ref<QuoteLine[]>(props.initial && props.initial.kind === 'fixed' ? linesFromQuote(props.initial) : [blankLine()])
const fee = ref(props.initial?.kind === 'inspection' ? fromMinor(props.initial.revision.total.minor) : '')
const notes = ref(props.initial?.revision.notes ?? '')
const est = props.initial?.revision.estimated_minutes ?? 60
const hours = ref(String(Math.floor(est / 60)))
const minutes = ref(String(est % 60))
const serverErrors = ref<Record<string, string[]>>({})

const taxBps = computed(() => props.taxRateBps)
const totals = computed(() => {
  if (kind.value === 'fixed') return quoteTotals(lines.value, taxBps.value)
  const subtotal = toMinor(fee.value) ?? 0
  const tax = taxFor(subtotal, taxBps.value)
  return { subtotal, tax, total: subtotal + tax }
})
const estimatedMinutes = computed(() => (Number(hours.value) || 0) * 60 + (Number(minutes.value) || 0))

const typeOptions = computed(() => ITEM_TYPES.map(v => ({ value: v, label: t(`quote.itemTypes.${v}`) })))
const unitOptions = computed(() => UNITS.map(v => ({ value: v, label: t(`quote.units.${v}`) })))
const conditionOptions = computed(() => [{ value: '', label: '—' }, ...CONDITIONS.map(v => ({ value: v, label: t(`quote.conditions.${v}`) }))])
const minuteOptions = ['0', '15', '30', '45'].map(v => ({ value: v, label: v }))

function err(key: string) {
  return serverErrors.value[key]?.[0] ?? null
}
function priceError(line: QuoteLine, i: number) {
  if (line.price && toMinor(line.price) == null) return t('quote.invalidPrice')
  return err(`items.${i}.unit_price_minor`)
}

const clientValid = computed(() => {
  if (totals.value.total > MAX_TOTAL_MINOR) return false
  if (kind.value === 'inspection') return toMinor(fee.value) != null
  return lines.value.length > 0 && lines.value.every(l => l.description.trim() && toMinor(l.price) != null && Number(l.quantity) > 0)
    && totals.value.total > 0
})

function addLine() {
  if (lines.value.length < MAX_ITEMS) lines.value.push(blankLine(lines.value.length ? 'material' : 'labour'))
}

function onTypeChange(line: QuoteLine) {
  if (line.type === 'labour' && line.unit === 'item') line.unit = 'job'
  if (line.type !== 'material') line.condition = ''
}

/** Maps the server's field_errors ("items.0.description") onto the form. */
function showServerErrors(e: unknown) {
  serverErrors.value = ApiError.from(e).fieldErrors
}

function submit() {
  if (!clientValid.value || props.loading) return
  const body: QuotationInput = {
    kind: kind.value,
    notes: notes.value.trim() || undefined,
    estimated_minutes: estimatedMinutes.value > 0 ? estimatedMinutes.value : undefined,
    ...(kind.value === 'fixed' ? { items: linesToInput(lines.value) } : { inspection_fee_minor: toMinor(fee.value) ?? 0 }),
  }
  emit('submit', body)
}
</script>

<template>
  <form
    class="flex flex-col gap-4"
    novalidate
    @submit.prevent="submit"
  >
    <fieldset
      v-if="mode === 'quote'"
      class="flex flex-col gap-2"
    >
      <legend class="mb-1 text-sm font-medium">
        {{ t('quote.kind') }}
      </legend>
      <label
        v-for="k in (['fixed', 'inspection'] as const)"
        :key="k"
        class="flex cursor-pointer gap-3 rounded-[var(--radius-control)] border p-3"
        :class="[kind === k ? 'border-brand-600 bg-brand-50' : 'border-border', k === 'inspection' && !inspectionAllowed ? 'hidden' : '']"
      >
        <input
          v-model="kind"
          type="radio"
          name="kind"
          :value="k"
          class="mt-1"
          :data-testid="`kind-${k}`"
        >
        <span>
          <span class="block font-medium">{{ t(`quote.${k}`) }}</span>
          <span class="block text-sm text-ink-muted">{{ t(`quote.${k}Hint`) }}</span>
        </span>
      </label>
    </fieldset>

    <UiInput
      v-if="kind === 'inspection'"
      v-model="fee"
      :label="t('quote.inspectionFee')"
      :hint="t('quote.inspectionFeeHint')"
      :error="(fee && toMinor(fee) == null ? t('quote.invalidPrice') : null) ?? err('inspection_fee_minor')"
      inputmode="decimal"
      data-testid="inspection-fee"
    />

    <fieldset
      v-else
      class="flex flex-col gap-3"
    >
      <legend class="mb-1 text-sm font-medium">
        {{ t('quote.lines') }}
      </legend>
      <div
        v-for="(line, i) in lines"
        :key="i"
        class="flex flex-col gap-2 rounded-[var(--radius-card)] border border-border p-3"
        data-testid="quote-line"
      >
        <div class="flex items-center justify-between">
          <span class="text-sm font-medium">{{ t('quote.line', { n: i + 1 }) }}</span>
          <UiButton
            v-if="lines.length > 1"
            variant="ghost"
            size="sm"
            :aria-label="t('quote.removeLine', { n: i + 1 })"
            @click="lines.splice(i, 1)"
          >
            ✕
          </UiButton>
        </div>
        <div class="grid gap-2 sm:grid-cols-2">
          <UiSelect
            v-model="line.type"
            :label="t('quote.lineType')"
            :options="typeOptions"
            :error="err(`items.${i}.type`)"
            @update:model-value="onTypeChange(line)"
          />
          <UiInput
            v-model="line.description"
            :label="t('quote.description')"
            :placeholder="t('quote.descriptionPlaceholder')"
            :error="err(`items.${i}.description`)"
            maxlength="200"
          />
        </div>
        <div class="grid grid-cols-3 gap-2">
          <UiInput
            v-model="line.quantity"
            :label="t('quote.quantity')"
            :error="err(`items.${i}.quantity`)"
            inputmode="decimal"
          />
          <UiSelect
            v-model="line.unit"
            :label="t('quote.unit')"
            :options="unitOptions"
          />
          <UiInput
            v-model="line.price"
            :label="t('quote.unitPrice')"
            :error="priceError(line, i)"
            inputmode="decimal"
          />
        </div>
        <div
          v-if="line.type === 'material'"
          class="grid grid-cols-3 gap-2"
        >
          <UiInput
            v-model="line.brand"
            :label="t('quote.brand')"
            maxlength="60"
          />
          <UiSelect
            v-model="line.condition"
            :label="t('quote.condition')"
            :options="conditionOptions"
          />
          <UiInput
            v-model="line.warrantyDays"
            :label="t('quote.warranty')"
            :error="err(`items.${i}.warranty_days`)"
            inputmode="numeric"
          />
        </div>
        <p class="text-right text-sm text-ink-muted">
          {{ t('quote.amount') }}: <strong class="text-ink">{{ money(lineAmount(line.quantity, toMinor(line.price))) }}</strong>
        </p>
      </div>
      <div>
        <UiButton
          variant="secondary"
          size="sm"
          :disabled="lines.length >= MAX_ITEMS"
          @click="addLine"
        >
          + {{ t('quote.addLine') }}
        </UiButton>
      </div>
      <p
        v-if="err('items')"
        class="text-sm text-danger"
      >
        {{ err('items') }}
      </p>
    </fieldset>

    <fieldset>
      <legend class="mb-1 text-sm font-medium">
        {{ t('quote.estimate') }}
      </legend>
      <div class="grid grid-cols-2 gap-2">
        <UiInput
          v-model="hours"
          :label="t('quote.hours')"
          inputmode="numeric"
          :error="err('estimated_minutes')"
        />
        <UiSelect
          v-model="minutes"
          :label="t('quote.minutes')"
          :options="minuteOptions"
        />
      </div>
    </fieldset>

    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium">{{ t('quote.notes') }} <span class="text-ink-subtle">({{ t('common.optional') }})</span></span>
      <textarea
        v-model="notes"
        rows="3"
        maxlength="1000"
        :placeholder="t('quote.notesPlaceholder')"
        class="rounded-[var(--radius-control)] border border-border bg-surface p-3"
      />
      <span class="text-xs text-ink-muted">{{ t('quote.privacyNote') }}</span>
    </label>

    <UiCard>
      <dl
        class="flex flex-col gap-1"
        data-testid="quote-totals"
      >
        <div class="flex justify-between text-sm">
          <dt>{{ t('quote.subtotal') }}</dt>
          <dd>{{ money(totals.subtotal) }}</dd>
        </div>
        <div
          v-if="taxBps"
          class="flex justify-between text-sm"
        >
          <dt>{{ t('quote.tax', { rate: taxBps / 100 }) }}</dt>
          <dd>{{ money(totals.tax) }}</dd>
        </div>
        <div class="flex justify-between text-lg font-semibold">
          <dt>{{ t('quote.total') }}</dt>
          <dd data-testid="quote-total">
            {{ money(totals.total) }}
          </dd>
        </div>
      </dl>
      <p class="mt-2 text-xs text-ink-muted">
        {{ t('quote.priceNote') }}
      </p>
      <p
        v-if="totals.total > MAX_TOTAL_MINOR"
        class="mt-2 text-sm text-danger"
      >
        {{ t('quote.tooLarge', { max: money(MAX_TOTAL_MINOR) }) }}
      </p>
      <p
        v-if="err('total')"
        class="mt-2 text-sm text-danger"
      >
        {{ err('total') }}
      </p>
    </UiCard>

    <UiButton
      type="submit"
      size="lg"
      :disabled="!clientValid"
      :loading="loading"
      data-testid="send-quote"
    >
      {{ mode === 'final' ? t('jobs.sendFinal') : mode === 'change' ? t('jobs.sendChange') : initial ? t('quote.update') : t('quote.send') }}
    </UiButton>
  </form>
</template>
