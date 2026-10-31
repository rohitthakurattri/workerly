<script setup lang="ts">
import { ref, watch } from 'vue'
import type { AdminBookingSummary } from '~/types/models'
import { ApiError } from '~/utils/api-error'
import { bookingTone } from '~/utils/bookings'
import { formatMoney } from '~/utils/money'

definePageMeta({ middleware: ['role'], roles: ['admin', 'support'] })

const api = useApi()
const route = useRoute()
const router = useRouter()
const { t } = useI18n()

// attention: unscheduled after a day, visit missed, price waiting a day, or disputed.
const TABS = ['attention', 'all'] as const
type Tab = typeof TABS[number]
const tab = ref<Tab>((route.query.tab as Tab) || 'attention')
const rows = ref<AdminBookingSummary[]>([])
const cursor = ref<string | null>(null)
const loading = ref(false)
const error = ref<string | null>(null)

async function load(reset = true) {
  loading.value = true
  error.value = null
  try {
    const res = await api<{ data: AdminBookingSummary[], meta: { next_cursor: string | null } }>('/admin/bookings', {
      query: { ...(tab.value === 'attention' ? { 'filter[attention]': 'true' } : {}), ...(reset ? {} : { cursor: cursor.value }) },
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
      {{ t('admin.bookings') }}
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
        {{ t(`admin.bookingTabs.${s}`) }}
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
        { key: 'customer_name', label: t('admin.customerCol') },
        { key: 'worker_name', label: t('admin.worker') },
        { key: 'status', label: t('admin.statusLabel') },
        { key: 'approved_total', label: t('admin.amountDue'), align: 'right' },
        { key: 'scheduled_at', label: t('admin.scheduled') },
      ]"
      :rows="rows"
      row-key="id"
      :caption="t('admin.bookings')"
    >
      <template #cell-category="{ row }">
        <NuxtLink
          :to="`/bookings/${row.id}`"
          class="font-medium text-brand-700 underline"
        >
          {{ row.category }}
        </NuxtLink>
        <span class="block text-xs text-ink-muted">{{ row.locality }}</span>
      </template>
      <template #cell-status="{ row }">
        <UiBadge :tone="bookingTone(row.status)">
          {{ t(`bookingStatus.${row.status}`) }}
        </UiBadge>
      </template>
      <template #cell-approved_total="{ row }">
        {{ formatMoney(row.approved_total) }}
      </template>
      <template #cell-scheduled_at="{ row }">
        {{ fmt(row.scheduled_at) }}
      </template>
      <template #empty>
        <UiEmptyState
          v-if="!loading"
          :title="t('admin.noBookings')"
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
