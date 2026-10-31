<script setup lang="ts">
import { ref, watch } from 'vue'
import type { AdminServiceRequestSummary } from '~/types/models'
import { ApiError } from '~/utils/api-error'
import { formatIndianMobile } from '~/utils/phone'

definePageMeta({ middleware: ['role'], roles: ['admin', 'support'] })

const api = useApi()
const route = useRoute()
const router = useRouter()
const { t } = useI18n()

// "attention": open with nobody invited, or still without quotes after 30 minutes.
const TABS = ['attention', 'open', 'cancelled', 'expired', 'all'] as const
type Tab = typeof TABS[number]
const tab = ref<Tab>((route.query.tab as Tab) || 'attention')
const rows = ref<AdminServiceRequestSummary[]>([])
const cursor = ref<string | null>(null)
const loading = ref(false)
const error = ref<string | null>(null)

async function load(reset = true) {
  loading.value = true
  error.value = null
  try {
    const filter = tab.value === 'attention' ? { 'filter[attention]': 'true' } : tab.value === 'all' ? {} : { 'filter[status]': tab.value }
    const res = await api<{ data: AdminServiceRequestSummary[], meta: { next_cursor: string | null } }>('/admin/service_requests', {
      query: { ...filter, ...(reset ? {} : { cursor: cursor.value }) },
    })
    rows.value = reset ? res.data : [...rows.value, ...res.data]
    cursor.value = res.meta.next_cursor
  }
  catch (e) {
    error.value = ApiError.from(e).message
  }
  finally {
    loading.value = false
  }
}

watch(tab, () => {
  router.replace({ query: { ...route.query, tab: tab.value } })
  load()
}, { immediate: true })

const fmt = (iso?: string | null) => (iso ? new Date(iso).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }) : '–')
</script>

<template>
  <div class="flex flex-col gap-4">
    <h1 class="text-2xl font-semibold">
      {{ t('admin.requests') }}
    </h1>
    <div
      class="flex flex-wrap gap-2"
      role="tablist"
    >
      <button
        v-for="s in TABS"
        :key="s"
        type="button"
        role="tab"
        :aria-selected="tab === s"
        class="rounded-full border px-3 py-1 text-sm"
        :class="tab === s ? 'border-brand-700 bg-brand-700 text-white' : 'border-border bg-surface text-ink-muted'"
        @click="tab = s"
      >
        {{ t(`admin.requestTabs.${s}`) }}
      </button>
    </div>
    <p
      v-if="error"
      class="text-danger"
      role="alert"
    >
      {{ error }}
    </p>
    <UiTable
      :columns="[
        { key: 'category', label: t('requests.service') },
        { key: 'locality', label: t('admin.area') },
        { key: 'customer', label: t('admin.customer') },
        { key: 'invited_count', label: t('admin.invited'), align: 'right' },
        { key: 'quotes_count', label: t('admin.quotes'), align: 'right' },
        { key: 'status', label: t('admin.statusLabel') },
        { key: 'submitted_at', label: t('admin.submitted') },
      ]"
      :rows="rows"
      row-key="id"
      :caption="t('admin.requests')"
    >
      <template #cell-category="{ row }">
        <NuxtLink
          :to="`/requests/${row.id}`"
          class="font-medium text-brand-700 underline"
        >
          {{ row.category }}
        </NuxtLink>
        <span
          v-if="row.safety_flag"
          :title="t('admin.safetyFlag')"
        > ⚠️</span>
      </template>
      <template #cell-locality="{ row }">
        {{ row.locality }}, {{ row.city }}
      </template>
      <template #cell-customer="{ row }">
        {{ row.customer?.name || '—' }}<br>
        <span class="text-ink-muted">{{ formatIndianMobile(row.customer?.phone ?? '') }}</span>
      </template>
      <template #cell-invited_count="{ row }">
        <span :class="row.invited_count === 0 && 'font-semibold text-danger'">{{ row.invited_count }}</span>
      </template>
      <template #cell-status="{ row }">
        <CustomerRequestStatusBadge :status="row.status!" />
      </template>
      <template #cell-submitted_at="{ row }">
        {{ fmt(row.submitted_at) }}
      </template>
      <template #empty>
        <UiEmptyState
          v-if="!loading"
          :title="t('admin.noRequests')"
        />
      </template>
    </UiTable>
    <div v-if="cursor">
      <UiButton
        variant="secondary"
        :loading="loading"
        @click="load(false)"
      >
        {{ t('admin.loadMore') }}
      </UiButton>
    </div>
  </div>
</template>
