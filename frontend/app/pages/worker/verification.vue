<script setup lang="ts">
import { computed, onMounted } from 'vue'

definePageMeta({ middleware: ['worker-profile'] })

const { profile, load } = useWorkerProfile()
const { t } = useI18n()

// Pick up a decision made while the worker was away.
onMounted(load)

const state = computed(() => {
  if (!profile.value) return null
  if (profile.value.suspended) return 'suspended'
  return profile.value.verification_status
})
</script>

<template>
  <div class="flex flex-col gap-6">
    <h1 class="text-2xl font-semibold">
      {{ t('verification.title') }}
    </h1>
    <UiCard v-if="state">
      <UiEmptyState
        :title="t(`verification.${state}.title`)"
        :description="t(`verification.${state}.body`)"
      >
        <p
          v-if="state !== 'pending_review' && profile?.last_decision?.reason"
          class="text-sm"
        >
          {{ t('verification.reason') }}: {{ profile.last_decision.reason }}
        </p>
      </UiEmptyState>
    </UiCard>
    <UiCard v-if="profile?.documents.length">
      <template #title>
        {{ t('verification.documents') }}
      </template>
      <ul class="flex flex-col gap-2 text-sm">
        <li
          v-for="d in profile.documents.filter(d => d.status !== 'superseded')"
          :key="d.id"
          class="flex items-center justify-between"
        >
          <span>{{ t(`docKinds.${d.kind}`) }} · {{ t(`docTypes.${d.doc_type}`) }}</span>
          <UiBadge :tone="d.status === 'approved' ? 'success' : d.status === 'rejected' ? 'danger' : 'info'">
            {{ t(`docStatus.${d.status}`) }}
          </UiBadge>
        </li>
      </ul>
    </UiCard>
  </div>
</template>
