<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { STEPS, firstOpenStep, stepStatus, type StepId } from '~/utils/onboarding'

definePageMeta({ middleware: ['worker-profile'] })

const { profile, loadCatalog } = useWorkerProfile()
const { t } = useI18n()
const open = ref<StepId>(profile.value ? firstOpenStep(profile.value) : 'about')
const loading = ref(true)

onMounted(async () => {
  await loadCatalog()
  loading.value = false
})

// After saving a step, jump to the earliest step that still needs work (or simply the next one).
function next(from: StepId) {
  const target = profile.value ? firstOpenStep(profile.value) : 'review'
  open.value = target === from ? STEPS[STEPS.indexOf(from) + 1] ?? 'review' : target
}

const decision = computed(() => profile.value?.verification_status === 'changes_requested' ? profile.value.last_decision : null)
</script>

<template>
  <div class="flex flex-col gap-4">
    <h1 class="text-2xl font-semibold">
      {{ t('onboarding.title') }}
    </h1>
    <p
      v-if="decision"
      class="rounded-[var(--radius-card)] border border-warning/30 bg-warning-soft p-4 text-sm text-warning"
      role="status"
    >
      <strong>{{ t('onboarding.changesRequested') }}</strong> {{ decision.reason }}
    </p>

    <UiSkeleton
      v-if="loading || !profile"
      :lines="5"
    />
    <ol
      v-else
      class="flex flex-col gap-3"
    >
      <li
        v-for="(step, i) in STEPS"
        :key="step"
        class="rounded-[var(--radius-card)] border border-border bg-surface"
      >
        <button
          type="button"
          class="flex w-full items-center gap-3 p-4 text-left"
          :aria-expanded="open === step"
          @click="open = step"
        >
          <span
            class="flex size-7 shrink-0 items-center justify-center rounded-full text-sm font-semibold"
            :class="stepStatus(profile, step) === 'done' ? 'bg-success text-white' : 'bg-surface-muted text-ink-muted'"
          >{{ stepStatus(profile, step) === 'done' ? '✓' : i + 1 }}</span>
          <span class="font-semibold">{{ t(`onboarding.steps.${step}`) }}</span>
        </button>
        <div
          v-if="open === step"
          class="border-t border-border p-4"
        >
          <WorkerStepAbout
            v-if="step === 'about'"
            @saved="next('about')"
          />
          <WorkerStepSkills
            v-else-if="step === 'skills'"
            @saved="next('skills')"
          />
          <WorkerStepArea
            v-else-if="step === 'area'"
            @saved="next('area')"
          />
          <div
            v-else-if="step === 'documents'"
            class="flex flex-col gap-3"
          >
            <p class="text-sm text-ink-muted">
              {{ t('onboarding.documentsHint') }}
            </p>
            <WorkerDocumentSlot
              kind="identity"
              required
            />
            <WorkerDocumentSlot
              kind="address"
              required
            />
            <WorkerDocumentSlot
              kind="trade"
              :required="false"
            />
            <div>
              <UiButton @click="next('documents')">
                {{ t('onboarding.continue') }}
              </UiButton>
            </div>
          </div>
          <WorkerStepReview v-else />
        </div>
      </li>
    </ol>
  </div>
</template>
