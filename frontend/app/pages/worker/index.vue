<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'
import { useAuthStore } from '~/stores/auth'
import { ApiError } from '~/utils/api-error'

// Approved workers see leads here; everyone else is routed to onboarding/verification.
definePageMeta({ middleware: ['worker-profile'] })

const auth = useAuthStore()
const { profile, register, setAvailable } = useWorkerProfile()
const toast = useToast()
const { leads, load: loadLeads, live } = useLeads()
const { t } = useI18n()
let stopLive = () => {}

const name = ref(auth.user?.name ?? '')
const registering = ref(false)
const registerError = ref<string | null>(null)
const toggling = ref(false)

async function becomeWorker() {
  registering.value = true
  registerError.value = null
  try {
    await register(name.value.trim())
    await navigateTo('/onboarding')
  }
  catch (e) {
    const err = ApiError.from(e)
    registerError.value = err.fieldErrors.name?.[0] ?? err.message
  }
  finally {
    registering.value = false
  }
}

async function toggleAvailable() {
  if (!profile.value) return
  toggling.value = true
  try {
    await setAvailable(!profile.value.available)
    toast.success(profile.value.available ? t('worker.nowAvailable') : t('worker.nowUnavailable'))
  }
  catch (e) {
    toast.error(ApiError.from(e).message)
  }
  finally {
    toggling.value = false
  }
}

// Leads arrive live over the WebSocket; the list is refetched on every (re)connect.
onMounted(async () => {
  if (auth.activeRole !== 'worker' || profile.value?.verification_status !== 'approved' || profile.value.suspended) return
  await loadLeads()
  stopLive = live(lead => toast.show(t('leads.arrived', { category: lead.category.name, locality: lead.locality }), 'info'))
})
onBeforeUnmount(() => stopLive())
</script>

<template>
  <div class="flex flex-col gap-6">
    <h1 class="text-2xl font-semibold">
      {{ t('home.greeting', { name: auth.user?.name || t('home.there') }) }}
    </h1>

    <template v-if="auth.activeRole === 'worker' && profile">
      <UiCard>
        <div class="flex items-center justify-between gap-4">
          <div>
            <p class="font-semibold">
              {{ profile.available ? t('worker.available') : t('worker.unavailable') }}
            </p>
            <p class="text-sm text-ink-muted">
              {{ t('worker.availabilityHint') }}
            </p>
          </div>
          <button
            type="button"
            role="switch"
            :aria-checked="profile.available"
            :aria-label="t('worker.availability')"
            :disabled="toggling"
            class="relative h-7 w-12 shrink-0 rounded-full transition-colors"
            :class="profile.available ? 'bg-success' : 'bg-border'"
            @click="toggleAvailable"
          >
            <span
              class="absolute top-0.5 size-6 rounded-full bg-white shadow transition-all"
              :class="profile.available ? 'left-[1.4rem]' : 'left-0.5'"
            />
          </button>
        </div>
      </UiCard>
      <UiCard>
        <template #title>
          {{ t('worker.leads') }}
        </template>
        <UiSkeleton
          v-if="leads === null"
          :lines="2"
        />
        <UiEmptyState
          v-else-if="!leads.length"
          :title="t('worker.noLeads')"
          :description="profile.available ? t('worker.noLeadsApproved') : t('leads.offDuty')"
        />
        <div
          v-else
          class="flex flex-col gap-2"
        >
          <WorkerLeadCard
            v-for="lead in leads"
            :key="lead.id"
            :lead="lead"
          />
        </div>
      </UiCard>
      <WorkerJobAlerts />
    </template>

    <UiCard v-else>
      <template #title>
        {{ t('worker.becomeTitle') }}
      </template>
      <p class="mb-4 text-ink-muted">
        {{ t('worker.becomeBody') }}
      </p>
      <form
        class="flex flex-col gap-4"
        @submit.prevent="becomeWorker"
      >
        <UiInput
          v-model="name"
          :label="t('profile.name')"
          :error="registerError"
          autocomplete="name"
          maxlength="100"
          required
        />
        <div>
          <UiButton
            type="submit"
            :loading="registering"
            :disabled="!name.trim()"
          >
            {{ t('worker.startRegistration') }}
          </UiButton>
        </div>
      </form>
    </UiCard>
  </div>
</template>
