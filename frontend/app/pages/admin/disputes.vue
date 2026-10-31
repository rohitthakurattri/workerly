<script setup lang="ts">
import { onMounted, ref } from 'vue'
import type { AdminDispute } from '~/types/models'
import { ApiError } from '~/utils/api-error'
import { formatMoney } from '~/utils/money'

definePageMeta({ middleware: ['role'], roles: ['admin', 'support'] })

const api = useApi()
const toast = useToast()
const { t } = useI18n()
const disputes = ref<AdminDispute[] | null>(null)
const resolving = ref<AdminDispute | null>(null)
const resolution = ref('')
const busy = ref(false)

const load = async () => {
  disputes.value = (await api<{ data: AdminDispute[] }>('/admin/disputes')).data
}
onMounted(load)

async function resolve() {
  busy.value = true
  try {
    await api(`/admin/disputes/${resolving.value!.id}/resolve`, { method: 'POST', body: { resolution: resolution.value.trim() } })
    toast.success(t('admin.resolved'))
    resolving.value = null
    resolution.value = ''
    await load()
  }
  catch (e) {
    toast.error(ApiError.from(e).message)
  }
  finally {
    busy.value = false
  }
}

const fmt = (iso: string) => new Date(iso).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' })
</script>

<template>
  <div class="flex flex-col gap-4">
    <h1 class="text-2xl font-semibold">
      {{ t('admin.disputes') }}
    </h1>
    <UiSkeleton
      v-if="disputes === null"
      :lines="4"
    />
    <UiEmptyState
      v-else-if="!disputes.length"
      :title="t('admin.noDisputes')"
    />
    <ul
      v-else
      class="flex flex-col gap-3"
    >
      <li
        v-for="d in disputes"
        :key="d.id"
      >
        <UiCard>
          <div class="flex flex-wrap items-start justify-between gap-2">
            <div>
              <p class="font-medium">
                {{ d.category }} · {{ d.customer_name }} → {{ d.worker_name }}
              </p>
              <p class="text-sm text-ink-muted">
                {{ fmt(d.created_at) }} · {{ d.approved_total ? formatMoney(d.approved_total) : '' }}
              </p>
              <p class="mt-1 whitespace-pre-line">
                {{ d.description }}
              </p>
            </div>
            <div class="flex gap-2">
              <NuxtLink
                :to="`/bookings/${d.booking_id}`"
                class="inline-flex h-9 items-center rounded-[var(--radius-control)] border border-border px-3 text-sm"
              >
                {{ t('admin.bookings') }}
              </NuxtLink>
              <UiButton
                size="sm"
                @click="resolving = d"
              >
                {{ t('admin.resolve') }}
              </UiButton>
            </div>
          </div>
        </UiCard>
      </li>
    </ul>
    <UiModal
      :open="!!resolving"
      :title="t('admin.resolve')"
      @update:open="v => { if (!v) resolving = null }"
    >
      <form
        class="flex flex-col gap-4"
        @submit.prevent="resolve"
      >
        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium">{{ t('admin.resolution') }}</span>
          <textarea
            v-model="resolution"
            rows="4"
            maxlength="2000"
            required
            class="rounded-[var(--radius-control)] border border-border bg-surface p-3"
          />
        </label>
        <div class="flex justify-end gap-2">
          <UiButton
            variant="ghost"
            @click="resolving = null"
          >
            {{ t('common.cancel') }}
          </UiButton>
          <UiButton
            type="submit"
            :disabled="!resolution.trim()"
            :loading="busy"
          >
            {{ t('admin.resolve') }}
          </UiButton>
        </div>
      </form>
    </UiModal>
  </div>
</template>
