<script setup lang="ts">
import { onMounted, ref } from 'vue'
import type { AdminBooking } from '~/types/models'
import { ApiError } from '~/utils/api-error'
import { formatMoney } from '~/utils/money'
import { formatIndianMobile } from '~/utils/phone'

definePageMeta({ middleware: ['role'], roles: ['admin', 'support'] })

const route = useRoute()
const api = useApi()
const toast = useToast()
const { t } = useI18n()
const b = ref<AdminBooking | null>(null)
const confirmCancel = ref(false)
const reason = ref('')
const busy = ref(false)

const load = async () => {
  b.value = (await api<{ data: AdminBooking }>(`/admin/bookings/${route.params.id}`)).data
}
onMounted(load)

async function doCancel() {
  busy.value = true
  try {
    b.value = (await api<{ data: AdminBooking }>(`/admin/bookings/${b.value!.id}/cancel`, { method: 'POST', body: { reason: reason.value.trim() } })).data
    toast.success(t('admin.bookingCancelled'))
    confirmCancel.value = false
  }
  catch (e) {
    toast.error(ApiError.from(e).message)
  }
  finally {
    busy.value = false
  }
}

const fmt = (iso?: string | null) => (iso ? new Date(iso).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }) : '–')
</script>

<template>
  <div class="flex flex-col gap-4">
    <NuxtLink
      to="/bookings"
      class="text-sm text-brand-700"
    >
      ← {{ t('admin.bookings') }}
    </NuxtLink>
    <UiSkeleton
      v-if="!b"
      :lines="8"
    />
    <template v-else>
      <div class="flex flex-wrap items-center justify-between gap-2">
        <h1 class="text-2xl font-semibold">
          {{ b.category.name }} · {{ b.locality }}
        </h1>
        <UiButton
          v-if="b.actions.includes('admin_cancel')"
          variant="danger"
          @click="confirmCancel = true"
        >
          {{ t('admin.cancelBooking') }}
        </UiButton>
      </div>
      <div class="grid gap-4 md:grid-cols-2">
        <UiCard>
          <dl class="grid grid-cols-2 gap-2 text-sm">
            <dt class="text-ink-muted">
              {{ t('admin.statusLabel') }}
            </dt><dd>{{ t(`bookingStatus.${b.status}`) }} · {{ b.kind }}</dd>
            <dt class="text-ink-muted">
              {{ t('admin.amountDue') }}
            </dt><dd>{{ formatMoney(b.approved_total) }}</dd>
            <dt class="text-ink-muted">
              {{ t('admin.customerCol') }}
            </dt><dd>{{ b.customer.name }} · {{ formatIndianMobile(b.customer.phone ?? '') }}</dd>
            <dt class="text-ink-muted">
              {{ t('admin.worker') }}
            </dt><dd>
              <NuxtLink
                :to="`/workers/${b.worker.id}`"
                class="text-brand-700 underline"
              >{{ b.worker.name }}</NuxtLink> · {{ formatIndianMobile(b.worker.phone ?? '') }}
            </dd>
            <dt class="text-ink-muted">
              {{ t('admin.scheduled') }}
            </dt><dd>{{ fmt(b.scheduled_at) }}</dd>
            <dt class="text-ink-muted">
              {{ t('admin.requests') }}
            </dt><dd>
              <NuxtLink
                :to="`/requests/${b.request_id}`"
                class="text-brand-700 underline"
              >{{ b.request_id.slice(0, 8) }}</NuxtLink>
            </dd>
          </dl>
          <p
            v-if="b.cancel_reason"
            class="mt-2 text-sm text-ink-muted"
          >
            {{ b.cancelled_by }}: {{ b.cancel_reason }}
          </p>
          <p
            v-if="b.dispute"
            class="mt-2 rounded-[var(--radius-control)] bg-warning-soft p-2 text-sm text-warning"
          >
            {{ t('admin.disputeOpen') }}: {{ b.dispute.category }} — {{ b.dispute.description }}
            <template v-if="b.dispute.resolution">
              → {{ b.dispute.resolution }}
            </template>
          </p>
        </UiCard>
        <UiCard>
          <template #title>
            {{ t('admin.approvals') }}
          </template>
          <ul class="flex flex-col gap-1 text-sm">
            <li
              v-for="a in b.approvals"
              :key="a.revision_id"
              class="flex justify-between gap-2"
            >
              <span>v{{ a.version }} {{ a.stage }} · {{ a.decision }} · {{ fmt(a.decided_at) }}</span>
              <span>{{ formatMoney(a.total) }}</span>
            </li>
          </ul>
          <p
            v-if="b.pending_revision"
            class="mt-2 text-sm text-warning"
          >
            v{{ b.pending_revision.version }} {{ b.pending_revision.stage }} · {{ formatMoney(b.pending_revision.total) }} …
          </p>
        </UiCard>
      </div>
      <UiCard>
        <template #title>
          {{ t('admin.history') }}
        </template>
        <ol class="flex flex-col gap-1 text-sm">
          <li
            v-for="(h, i) in b.history"
            :key="i"
          >
            {{ fmt(h.at) }} · {{ h.by }} · {{ h.event }} → <strong>{{ h.to }}</strong>
          </li>
        </ol>
      </UiCard>
      <UiCard>
        <template #title>
          {{ t('admin.messages') }}
        </template>
        <p
          v-if="!b.messages.length"
          class="text-sm text-ink-muted"
        >
          {{ t('admin.noMessages') }}
        </p>
        <ul class="flex flex-col gap-1 text-sm">
          <li
            v-for="m in b.messages"
            :key="m.id"
          >
            <span class="text-ink-muted">{{ fmt(m.created_at) }} · {{ m.sender_role }}:</span> {{ m.body }}
          </li>
        </ul>
      </UiCard>
    </template>
    <UiModal
      v-model:open="confirmCancel"
      :title="t('admin.cancelBooking')"
    >
      <form
        class="flex flex-col gap-4"
        @submit.prevent="doCancel"
      >
        <UiInput
          v-model="reason"
          :label="t('admin.cancelReason')"
          maxlength="500"
          required
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
            :disabled="!reason.trim()"
            :loading="busy"
          >
            {{ t('admin.cancelBooking') }}
          </UiButton>
        </div>
      </form>
    </UiModal>
  </div>
</template>
