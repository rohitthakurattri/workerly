<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import type { AdminWorkerDetail } from '~/types/models'
import { ApiError } from '~/utils/api-error'
import { formatIndianMobile } from '~/utils/phone'

definePageMeta({ middleware: ['role'], roles: ['admin', 'verifier', 'support'] })

type Verdict = { status: 'approved' | 'rejected' | '', reason: string }

const api = useApi()
const route = useRoute()
const toast = useToast()
const { canDecide, canSuspend } = useStaff()
const { t } = useI18n()

const id = route.params.id as string
const worker = ref<AdminWorkerDetail | null>(null)
const verdicts = ref<Record<string, Verdict>>({})
const reason = ref('')
const busy = ref(false)
const error = ref<string | null>(null)
const confirm = ref<'approved' | 'changes_requested' | 'rejected' | 'suspend' | 'reinstate' | null>(null)

async function load() {
  worker.value = (await api<{ data: AdminWorkerDetail }>(`/admin/workers/${id}`)).data
  verdicts.value = Object.fromEntries((worker.value.documents ?? []).filter(d => d.status === 'pending').map(d => [d.id, { status: '', reason: '' }]))
}
onMounted(load)

const reviewable = computed(() => worker.value?.verification_status === 'pending_review' && canDecide.value)
const visibleDocs = computed(() => (worker.value?.documents ?? []).filter(d => d.status !== 'superseded'))
const decided = computed(() => Object.entries(verdicts.value).filter(([, v]) => v.status))
const allDecided = computed(() => decided.value.length === Object.keys(verdicts.value).length)
const anyRejected = computed(() => decided.value.some(([, v]) => v.status === 'rejected'))

async function act() {
  const action = confirm.value
  if (!action) return
  busy.value = true
  error.value = null
  try {
    if (action === 'suspend' || action === 'reinstate') {
      worker.value = (await api<{ data: AdminWorkerDetail }>(`/admin/workers/${id}/${action}`, { method: 'POST', body: { reason: reason.value } })).data
    }
    else {
      const documents = decided.value.map(([docId, v]) => ({ id: docId, status: v.status, reason: v.reason || undefined }))
      await api(`/admin/workers/${id}/verification`, { method: 'POST', body: { decision: action, reason: reason.value || undefined, documents } })
      await load()
    }
    toast.success(t(`admin.done.${action}`))
    reason.value = ''
    confirm.value = null
  }
  catch (e) {
    error.value = ApiError.from(e).message
  }
  finally {
    busy.value = false
  }
}

const fmt = (iso?: string | null) => (iso ? new Date(iso).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }) : '–')
</script>

<template>
  <div
    v-if="worker"
    class="flex flex-col gap-6"
  >
    <NuxtLink
      to="/workers"
      class="text-sm text-brand-700 underline"
    >
      ← {{ t('admin.workers') }}
    </NuxtLink>

    <header class="flex flex-wrap items-center gap-4">
      <img
        v-if="worker.photo"
        :src="worker.photo.url"
        :alt="worker.user?.name ?? ''"
        class="size-20 rounded-full border border-border object-cover"
      >
      <div>
        <h1 class="text-2xl font-semibold">
          {{ worker.user?.name || '—' }}
        </h1>
        <p class="text-ink-muted">
          {{ formatIndianMobile(worker.user?.phone ?? '') }}
        </p>
        <AdminStatusBadge
          :status="worker.verification_status!"
          :suspended="worker.suspended"
        />
      </div>
    </header>

    <div class="grid gap-4 md:grid-cols-3">
      <UiCard>
        <template #title>
          {{ t('admin.profile') }}
        </template>
        <dl class="grid gap-2 text-sm">
          <div><dt class="text-ink-muted">{{ t('onboarding.experience') }}</dt><dd>{{ worker.experience_years ?? '–' }}</dd></div>
          <div><dt class="text-ink-muted">{{ t('onboarding.bio') }}</dt><dd class="whitespace-pre-line">{{ worker.bio || '–' }}</dd></div>
          <div><dt class="text-ink-muted">{{ t('admin.submitted') }}</dt><dd>{{ fmt(worker.submitted_at) }}</dd></div>
          <div v-if="worker.suspension_reason"><dt class="text-ink-muted">{{ t('admin.suspensionReason') }}</dt><dd>{{ worker.suspension_reason }}</dd></div>
        </dl>
      </UiCard>
      <UiCard>
        <template #title>
          {{ t('admin.skills') }}
        </template>
        <ul class="text-sm">
          <li
            v-for="s in worker.skills"
            :key="s.category"
          >
            {{ s.name }}<span
              v-if="s.experience_years != null"
              class="text-ink-muted"
            > · {{ t('admin.yearsShort', { n: s.experience_years }) }}</span>
          </li>
        </ul>
      </UiCard>
      <UiCard>
        <template #title>
          {{ t('admin.serviceAreas') }}
        </template>
        <ul class="text-sm">
          <li
            v-for="a in worker.service_areas"
            :key="a.id"
          >
            <a
              :href="`https://www.openstreetmap.org/?mlat=${a.center.lat}&mlon=${a.center.lng}#map=13/${a.center.lat}/${a.center.lng}`"
              target="_blank"
              rel="noopener noreferrer"
              class="capitalize text-brand-700 underline"
            >{{ a.label || a.city }}</a> <span class="capitalize text-ink-muted">{{ a.label ? `(${a.city})` : "" }}</span> · {{ a.radius_m / 1000 }} km
          </li>
        </ul>
      </UiCard>
    </div>

    <section>
      <h2 class="mb-3 text-lg font-semibold">
        {{ t('verification.documents') }}
      </h2>
      <div class="grid gap-4 md:grid-cols-2">
        <AdminDocumentReview
          v-for="d in visibleDocs"
          :key="d.id"
          v-model="verdicts[d.id]!"
          :doc="d"
          :decidable="reviewable && d.id in verdicts"
        />
      </div>
    </section>

    <UiCard v-if="reviewable">
      <template #title>
        {{ t('admin.decision') }}
      </template>
      <p class="mb-3 text-sm text-ink-muted">
        {{ allDecided ? t('admin.decisionHint') : t('admin.reviewAllFirst') }}
      </p>
      <div class="flex flex-wrap gap-2">
        <UiButton
          :disabled="!allDecided || anyRejected"
          @click="confirm = 'approved'"
        >
          {{ t('admin.approveWorker') }}
        </UiButton>
        <UiButton
          variant="secondary"
          :disabled="!allDecided"
          @click="confirm = 'changes_requested'"
        >
          {{ t('admin.requestChanges') }}
        </UiButton>
        <UiButton
          variant="danger"
          @click="confirm = 'rejected'"
        >
          {{ t('admin.rejectWorker') }}
        </UiButton>
      </div>
    </UiCard>

    <UiCard v-if="canSuspend && worker.verification_status === 'approved'">
      <template #title>
        {{ t('admin.suspension') }}
      </template>
      <UiButton
        :variant="worker.suspended ? 'secondary' : 'danger'"
        @click="confirm = worker.suspended ? 'reinstate' : 'suspend'"
      >
        {{ worker.suspended ? t('admin.reinstate') : t('admin.suspend') }}
      </UiButton>
    </UiCard>

    <UiCard v-if="worker.history?.length">
      <template #title>
        {{ t('admin.history') }}
      </template>
      <ol class="flex flex-col gap-2 text-sm">
        <li
          v-for="(h, i) in worker.history"
          :key="i"
        >
          <strong>{{ t(`admin.decisions.${h.decision}`) }}</strong> · {{ h.by }} · {{ fmt(h.at) }}
          <span
            v-if="h.reason"
            class="block text-ink-muted"
          >{{ h.reason }}</span>
        </li>
      </ol>
    </UiCard>

    <UiModal
      :open="!!confirm"
      :title="confirm ? t(`admin.confirm.${confirm}`) : ''"
      @update:open="v => { if (!v) confirm = null }"
    >
      <UiInput
        v-model="reason"
        :label="confirm === 'approved' || confirm === 'reinstate' ? t('admin.noteOptional') : t('admin.reasonRequired')"
        :hint="confirm === 'changes_requested' || confirm === 'rejected' ? t('admin.reasonShownToWorker') : undefined"
      />
      <p
        v-if="error"
        class="mt-2 text-sm text-danger"
        role="alert"
      >
        {{ error }}
      </p>
      <template #footer>
        <UiButton
          variant="secondary"
          @click="confirm = null"
        >
          {{ t('common.cancel') }}
        </UiButton>
        <UiButton
          :variant="confirm === 'rejected' || confirm === 'suspend' ? 'danger' : 'primary'"
          :loading="busy"
          :disabled="(confirm === 'changes_requested' || confirm === 'rejected' || confirm === 'suspend') && !reason.trim()"
          @click="act"
        >
          {{ t('common.confirm') }}
        </UiButton>
      </template>
    </UiModal>
  </div>
  <UiSkeleton
    v-else
    :lines="6"
  />
</template>
