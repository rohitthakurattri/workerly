<script setup lang="ts">
import { onMounted, ref } from 'vue'
import type { AdminServiceRequestDetail } from '~/types/models'
import { formatMoney } from '~/utils/money'
import { formatIndianMobile } from '~/utils/phone'
import { quoteStatusTone } from '~/utils/quotes'

definePageMeta({ middleware: ['role'], roles: ['admin', 'support'] })

const route = useRoute()
const api = useApi()
const { t } = useI18n()
const r = ref<AdminServiceRequestDetail | null>(null)

onMounted(async () => {
  r.value = (await api<{ data: AdminServiceRequestDetail }>(`/admin/service_requests/${route.params.id}`)).data
})

const fmt = (iso?: string | null) => (iso ? new Date(iso).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }) : '–')
const km = (m: number) => (m / 1000).toFixed(1)
</script>

<template>
  <div class="flex flex-col gap-4">
    <NuxtLink
      to="/requests"
      class="text-sm text-brand-700"
    >
      ← {{ t('admin.requests') }}
    </NuxtLink>
    <UiSkeleton
      v-if="!r"
      :lines="8"
    />
    <template v-else>
      <div class="flex flex-wrap items-center gap-3">
        <h1 class="text-2xl font-semibold">
          {{ r.category }} · {{ r.address_snapshot?.locality }}, {{ r.city }}
        </h1>
        <CustomerRequestStatusBadge :status="r.status" />
        <UiBadge
          v-if="r.safety_flag"
          tone="danger"
        >
          {{ t('admin.safetyFlag') }}
        </UiBadge>
      </div>
      <div class="grid gap-4 md:grid-cols-2">
        <UiCard>
          <template #title>
            {{ t('requests.problem') }}
          </template>
          <p class="whitespace-pre-line">
            {{ r.description }}
          </p>
          <p
            v-if="r.ai_summary"
            class="mt-2 text-sm text-ink-muted"
          >
            {{ t('requests.aiSummary') }} {{ r.ai_summary }} ({{ r.category_source === 'ai' ? t('admin.keptSuggestion') : t('admin.customerPicked') }})
          </p>
          <p
            v-for="a in r.answers"
            :key="a.question"
            class="mt-1 text-sm"
          >
            <span class="text-ink-muted">{{ a.question }}</span> {{ a.answer }}
          </p>
          <div
            v-if="r.photos?.length"
            class="mt-3 flex gap-2 overflow-x-auto"
          >
            <a
              v-for="p in r.photos"
              :key="p.id"
              :href="p.file?.url"
              target="_blank"
              rel="noopener"
            ><img
              :src="p.file?.url"
              alt=""
              class="size-20 rounded-[var(--radius-control)] object-cover"
            ></a>
          </div>
        </UiCard>
        <UiCard>
          <template #title>
            {{ t('admin.customer') }}
          </template>
          <dl class="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 text-sm">
            <dt class="text-ink-muted">
              {{ t('profile.name') }}
            </dt><dd>{{ r.customer?.name || '—' }}</dd>
            <dt class="text-ink-muted">
              {{ t('profile.phone') }}
            </dt><dd>{{ formatIndianMobile(r.customer?.phone ?? '') }}</dd>
            <dt class="text-ink-muted">
              {{ t('requests.address') }}
            </dt><dd>{{ r.address_snapshot?.line1 }}, {{ r.address_snapshot?.locality }} {{ r.address_snapshot?.pincode }}</dd>
            <dt class="text-ink-muted">
              {{ t('requests.when') }}
            </dt><dd>{{ t(`urgency.${r.urgency}`) }}</dd>
            <dt class="text-ink-muted">
              {{ t('admin.submitted') }}
            </dt><dd>{{ fmt(r.submitted_at) }}</dd>
            <dt class="text-ink-muted">
              {{ t('admin.expires') }}
            </dt><dd>{{ fmt(r.expires_at) }}</dd>
          </dl>
        </UiCard>
      </div>
      <UiCard>
        <template #title>
          {{ t('admin.invitations', { count: r.invitations.length }) }}
        </template>
        <p
          v-if="!r.invitations.length"
          class="text-sm text-danger"
        >
          {{ r.matched_at ? t('admin.nobodyMatched') : t('admin.notMatchedYet') }}
        </p>
        <UiTable
          v-else
          :columns="[
            { key: 'rank', label: '#', align: 'right' },
            { key: 'worker_name', label: t('admin.worker') },
            { key: 'distance_m', label: t('admin.distance'), align: 'right' },
            { key: 'score', label: t('admin.score'), align: 'right' },
            { key: 'notified_via', label: t('admin.notified') },
            { key: 'viewed_at', label: t('admin.viewed') },
          ]"
          :rows="r.invitations"
          row-key="worker_id"
        >
          <template #cell-worker_name="{ row }">
            <NuxtLink
              :to="`/workers/${row.worker_id}`"
              class="text-brand-700 underline"
            >
              {{ row.worker_name || '—' }}
            </NuxtLink>
          </template>
          <template #cell-distance_m="{ row }">
            {{ km(row.distance_m) }} km
          </template>
          <template #cell-score="{ row }">
            {{ row.score.toFixed(2) }}
          </template>
          <template #cell-notified_via="{ row }">
            {{ row.notified_via ?? '…' }}
          </template>
          <template #cell-viewed_at="{ row }">
            <span v-if="row.declined_at">{{ t('admin.declined') }}<template v-if="row.decline_reason">: {{ row.decline_reason }}</template></span>
            <span v-else>{{ row.viewed_at ? fmt(row.viewed_at) : '–' }}</span>
          </template>
        </UiTable>
      </UiCard>
      <UiCard v-if="r.booking">
        <template #title>
          {{ t('admin.booking') }}
        </template>
        <dl class="grid grid-cols-2 gap-2 text-sm">
          <dt class="text-ink-muted">
            {{ t('admin.status') }}
          </dt><dd>{{ r.booking.status }} · {{ r.booking.kind }}</dd>
          <dt class="text-ink-muted">
            {{ t('admin.approvedTotal') }}
          </dt><dd>{{ r.booking.approved_total ? formatMoney(r.booking.approved_total) : '–' }}</dd>
          <dt class="text-ink-muted">
            {{ t('admin.confirmedAt') }}
          </dt><dd>{{ fmt(r.booking.confirmed_at) }}</dd>
        </dl>
      </UiCard>
      <UiCard>
        <template #title>
          {{ t('admin.quotes') }} ({{ r.quotations?.length ?? 0 }})
        </template>
        <p
          v-if="!r.quotations?.length"
          class="text-sm text-ink-muted"
        >
          {{ t('admin.noQuotes') }}
        </p>
        <ul
          v-else
          class="flex flex-col divide-y divide-border"
        >
          <li
            v-for="q in r.quotations"
            :key="q.id"
            class="py-3"
          >
            <div class="flex flex-wrap items-center justify-between gap-2">
              <NuxtLink
                :to="`/workers/${q.worker_id}`"
                class="font-medium text-brand-700 underline"
              >
                {{ q.worker_name || '—' }}
              </NuxtLink>
              <span class="flex items-center gap-2">
                <UiBadge>{{ q.kind }}</UiBadge>
                <UiBadge :tone="quoteStatusTone(q.status)">{{ q.status }}<template v-if="q.decline_reason">: {{ q.decline_reason }}</template></UiBadge>
              </span>
            </div>
            <details class="mt-1">
              <summary class="cursor-pointer text-sm text-ink-muted">
                {{ t('admin.versions') }}: {{ q.revisions.map(v => `v${v.version} ${formatMoney(v.total)}`).join(' → ') }}
              </summary>
              <div
                v-for="v in q.revisions"
                :key="v.id"
                class="mt-2 rounded-[var(--radius-control)] border border-border p-2"
              >
                <p class="mb-1 text-xs text-ink-muted">
                  v{{ v.version }} · {{ v.stage }} · {{ fmt(v.created_at) }}
                </p>
                <SharedQuoteBreakdown :revision="v" />
              </div>
            </details>
          </li>
        </ul>
      </UiCard>
    </template>
  </div>
</template>
