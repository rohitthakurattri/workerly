<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { ApiError } from '~/utils/api-error'

definePageMeta({ middleware: ['role'], roles: ['admin'] })

interface Entry { id: number, action: string, admin_role: string, target_type: string, target_id: string | number, reason: string | null, changes: Record<string, unknown>, admin: { name: string | null, phone: string }, ip: string | null, at: string }

const api = useApi()
const { t } = useI18n()
const rows = ref<Entry[]>([])
const cursor = ref<string | null>(null)
const loading = ref(false)
const error = ref<string | null>(null)

async function load(more = false) {
  loading.value = true
  try {
    const res = await api<{ data: Entry[], meta: { next_cursor: string | null } }>('/admin/audit_logs', { query: more ? { cursor: cursor.value } : {} })
    rows.value = more ? [...rows.value, ...res.data] : res.data
    cursor.value = res.meta.next_cursor
  }
  catch (e) {
    error.value = ApiError.from(e).message
  }
  finally {
    loading.value = false
  }
}
onMounted(() => load())
</script>

<template>
  <div class="flex flex-col gap-4">
    <h1 class="text-2xl font-semibold">
      {{ t('admin.auditLog') }}
    </h1>
    <p
      v-if="error"
      class="text-danger"
    >
      {{ error }}
    </p>
    <UiTable
      :columns="[
        { key: 'at', label: t('admin.when') },
        { key: 'admin', label: t('admin.who') },
        { key: 'action', label: t('admin.action') },
        { key: 'target_id', label: t('admin.target') },
        { key: 'reason', label: t('admin.reason') },
      ]"
      :rows="rows as unknown as Record<string, unknown>[]"
      row-key="id"
      :caption="t('admin.auditLog')"
    >
      <template #cell-at="{ row }">
        {{ new Date(row.at as string).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }) }}
      </template>
      <template #cell-admin="{ row }">
        {{ (row as unknown as Entry).admin.name || (row as unknown as Entry).admin.phone }} <span class="text-ink-muted">({{ row.admin_role }})</span>
      </template>
      <template #cell-action="{ row }">
        <code class="text-xs">{{ row.action }}</code>
      </template>
      <template #cell-target_id="{ row }">
        <NuxtLink
          v-if="row.target_type === 'WorkerProfile'"
          :to="`/workers/${row.target_id}`"
          class="text-brand-700 underline"
        >
          {{ t('admin.workerTarget') }}
        </NuxtLink>
        <span v-else>{{ row.target_type }} {{ row.target_id }}</span>
      </template>
      <template #empty>
        <UiEmptyState
          v-if="!loading"
          :title="t('admin.noAudit')"
        />
      </template>
    </UiTable>
    <div v-if="cursor">
      <UiButton
        variant="secondary"
        :loading="loading"
        @click="load(true)"
      >
        {{ t('admin.loadMore') }}
      </UiButton>
    </div>
  </div>
</template>
