<script setup lang="ts">
import { ref, watch } from 'vue'
import type { AdminWorkerSummary, VerificationStatus } from '~/types/models'
import { ApiError } from '~/utils/api-error'
import { formatIndianMobile } from '~/utils/phone'

definePageMeta({ middleware: ['role'], roles: ['admin', 'verifier', 'support'] })

const api = useApi()
const route = useRoute()
const router = useRouter()
const { t, locale } = useI18n()

const TABS: (VerificationStatus | 'all')[] = ['pending_review', 'changes_requested', 'approved', 'rejected', 'draft', 'all']
const status = ref<VerificationStatus | 'all'>((route.query.status as VerificationStatus) || 'pending_review')
const q = ref((route.query.q as string) || '')
const rows = ref<AdminWorkerSummary[]>([])
const cursor = ref<string | null>(null)
const loading = ref(false)
const error = ref<string | null>(null)

async function load(reset = true) {
  loading.value = true
  error.value = null
  try {
    const res = await api<{ data: AdminWorkerSummary[], meta: { next_cursor: string | null } }>('/admin/workers', {
      query: {
        ...(status.value !== 'all' ? { 'filter[status]': status.value } : {}),
        ...(q.value.trim() ? { q: q.value.trim() } : {}),
        ...(reset ? {} : { cursor: cursor.value }),
      },
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

watch(status, () => {
  router.replace({ query: { ...route.query, status: status.value } })
  load()
}, { immediate: true })

const fmt = (iso?: string | null) => (iso ? new Date(iso).toLocaleString(locale.value === 'en' ? 'en-IN' : `${locale.value}-IN`, { dateStyle: 'medium', timeStyle: 'short' }) : '–')
</script>

<template>
  <div class="flex flex-col gap-4">
    <h1 class="text-2xl font-semibold">
      {{ t('admin.workers') }}
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
        :aria-selected="status === s"
        class="rounded-full border px-3 py-1 text-sm"
        :class="status === s ? 'border-brand-700 bg-brand-700 text-white' : 'border-border bg-surface text-ink-muted'"
        @click="status = s"
      >
        {{ t(`admin.status.${s}`) }}
      </button>
    </div>
    <form
      class="flex gap-2"
      @submit.prevent="load()"
    >
      <div class="grow">
        <UiInput
          v-model="q"
          :label="t('admin.search')"
          type="search"
          :placeholder="t('admin.searchPlaceholder')"
        />
      </div>
      <UiButton
        type="submit"
        variant="secondary"
        class="self-end"
      >
        {{ t('admin.searchButton') }}
      </UiButton>
    </form>
    <p
      v-if="error"
      class="text-danger"
      role="alert"
    >
      {{ error }}
    </p>
    <UiTable
      :columns="[
        { key: 'name', label: t('profile.name') },
        { key: 'phone', label: t('profile.phone') },
        { key: 'skills', label: t('admin.skills') },
        { key: 'verification_status', label: t('admin.statusLabel') },
        { key: 'submitted_at', label: t('admin.submitted') },
      ]"
      :rows="rows"
      row-key="id"
      :caption="t('admin.workers')"
    >
      <template #cell-name="{ row }">
        <NuxtLink
          :to="`/workers/${row.id}`"
          class="font-medium text-brand-700 underline"
        >
          {{ row.name || '—' }}
        </NuxtLink>
      </template>
      <template #cell-phone="{ row }">
        {{ formatIndianMobile(row.phone ?? '') }}
      </template>
      <template #cell-skills="{ row }">
        {{ (row.skills ?? []).join(', ') }}
      </template>
      <template #cell-verification_status="{ row }">
        <AdminStatusBadge
          :status="row.verification_status!"
          :suspended="row.suspended"
        />
      </template>
      <template #cell-submitted_at="{ row }">
        {{ fmt(row.submitted_at) }}
      </template>
      <template #empty>
        <UiEmptyState
          v-if="!loading"
          :title="t('admin.noWorkers')"
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
