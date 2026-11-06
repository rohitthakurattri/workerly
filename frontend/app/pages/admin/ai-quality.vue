<script setup lang="ts">
import { onMounted, ref } from 'vue'
import type { AiQuality } from '~/types/models'
import { ApiError } from '~/utils/api-error'

definePageMeta({ middleware: ['role'], roles: ['admin'] })

const api = useApi()
const toast = useToast()
const { t } = useI18n()

const day = (d: Date) => d.toISOString().slice(0, 10)
const from = ref(day(new Date(Date.now() - 30 * 86_400_000)))
const to = ref(day(new Date()))
const report = ref<AiQuality | null>(null)
const loading = ref(false)

async function load() {
  loading.value = true
  try {
    report.value = (await api<{ data: AiQuality }>('/admin/ai/quality', {
      query: { from: `${from.value}T00:00:00+05:30`, to: `${to.value}T23:59:59+05:30` },
    })).data
  }
  catch (e) {
    toast.error(ApiError.from(e).message)
  }
  finally {
    loading.value = false
  }
}
onMounted(load)

const pct = (v?: number | null) => (v === null || v === undefined ? '–' : `${Math.round(v * 1000) / 10}%`)
</script>

<template>
  <div class="flex flex-col gap-4">
    <h1 class="text-2xl font-semibold">
      {{ t('aiQuality.title') }}
    </h1>
    <p class="text-sm text-ink-muted">
      {{ t('aiQuality.hint') }}
    </p>
    <form
      class="flex flex-wrap items-end gap-3"
      @submit.prevent="load"
    >
      <UiInput
        v-model="from"
        type="date"
        :label="t('finance.from')"
      />
      <UiInput
        v-model="to"
        type="date"
        :label="t('finance.to')"
      />
      <UiButton
        type="submit"
        :loading="loading"
      >
        {{ t('finance.run') }}
      </UiButton>
    </form>

    <UiSkeleton
      v-if="!report"
      :lines="6"
    />
    <template v-else>
      <dl class="grid gap-3 sm:grid-cols-4">
        <UiCard>
          <dt class="text-sm text-ink-muted">
            {{ t('aiQuality.accuracy') }}
          </dt>
          <dd
            class="text-2xl font-semibold tabular-nums"
            data-testid="ai-accuracy"
          >
            {{ pct(report.accuracy) }}
          </dd>
          <dd class="text-xs text-ink-muted">
            {{ t('aiQuality.ofTriaged', { n: report.triaged }) }}
          </dd>
        </UiCard>
        <UiCard>
          <dt class="text-sm text-ink-muted">
            {{ t('aiQuality.preselected') }}
          </dt>
          <dd class="text-2xl font-semibold tabular-nums">
            {{ pct(report.preselected.accuracy) }}
          </dd>
          <dd class="text-xs text-ink-muted">
            {{ t('aiQuality.preselectedHint', { share: pct(report.preselected.share) }) }}
          </dd>
        </UiCard>
        <UiCard>
          <dt class="text-sm text-ink-muted">
            {{ t('aiQuality.coverage') }}
          </dt>
          <dd class="text-2xl font-semibold tabular-nums">
            {{ pct(report.coverage) }}
          </dd>
          <dd class="text-xs text-ink-muted">
            {{ t('aiQuality.coverageHint', { triaged: report.triaged, submitted: report.submitted }) }}
          </dd>
        </UiCard>
        <UiCard>
          <dt class="text-sm text-ink-muted">
            {{ t('aiQuality.voiceNotes') }}
          </dt>
          <dd class="text-2xl font-semibold tabular-nums">
            {{ report.voice_notes.count }}
          </dd>
          <dd class="text-xs text-ink-muted">
            {{ t('aiQuality.voiceHint', report.voice_notes) }}
          </dd>
        </UiCard>
      </dl>

      <UiCard>
        <template #title>
          {{ t('aiQuality.calibration') }}
        </template>
        <p class="mb-2 text-xs text-ink-muted">
          {{ t('aiQuality.calibrationHint') }}
        </p>
        <UiTable
          :rows="report.calibration.map(b => ({ ...b, key: `${b.from}` }))"
          row-key="key"
          :caption="t('aiQuality.calibration')"
          :columns="[
            { key: 'range', label: t('aiQuality.confidence') },
            { key: 'count', label: t('aiQuality.requests'), align: 'right' },
            { key: 'accuracy', label: t('aiQuality.accuracy'), align: 'right' },
          ]"
        >
          <template #cell-range="{ row }">
            {{ Math.round(row.from * 100) }}–{{ Math.round(row.to * 100) }}%
          </template>
          <template #cell-accuracy="{ row }">
            {{ pct(row.accuracy) }}
          </template>
        </UiTable>
      </UiCard>

      <UiCard>
        <template #title>
          {{ t('aiQuality.byCategory') }}
        </template>
        <UiTable
          :rows="report.categories"
          row-key="slug"
          :caption="t('aiQuality.byCategory')"
          :columns="[
            { key: 'slug', label: t('finance.category') },
            { key: 'requests', label: t('aiQuality.requests'), align: 'right' },
            { key: 'suggested', label: t('aiQuality.suggested'), align: 'right' },
            { key: 'recall', label: t('aiQuality.recall'), align: 'right' },
            { key: 'precision', label: t('aiQuality.precision'), align: 'right' },
          ]"
        >
          <template #cell-recall="{ row }">
            {{ pct(row.recall) }}
          </template>
          <template #cell-precision="{ row }">
            {{ pct(row.precision) }}
          </template>
          <template #empty>
            <UiEmptyState :title="t('aiQuality.noData')" />
          </template>
        </UiTable>
      </UiCard>

      <div class="grid gap-3 md:grid-cols-2">
        <UiCard>
          <template #title>
            {{ t('aiQuality.confusions') }}
          </template>
          <p
            v-if="!report.confusions.length"
            class="text-sm text-ink-muted"
          >
            {{ t('aiQuality.noConfusions') }}
          </p>
          <ul
            v-else
            class="flex flex-col gap-1 text-sm"
          >
            <li
              v-for="c in report.confusions"
              :key="`${c.suggested}-${c.chosen}`"
              class="flex justify-between"
            >
              <span>{{ t('aiQuality.confusion', { suggested: c.suggested, chosen: c.chosen }) }}</span>
              <span class="tabular-nums">{{ c.count }}</span>
            </li>
          </ul>
        </UiCard>
        <UiCard>
          <template #title>
            {{ t('aiQuality.versions') }}
          </template>
          <ul class="flex flex-col gap-1 text-sm">
            <li
              v-for="v in report.versions"
              :key="`${v.prompt_version}-${v.model}`"
              class="flex justify-between gap-2"
            >
              <span class="break-all">{{ v.prompt_version }} · {{ v.model || '–' }}</span>
              <span class="tabular-nums">{{ pct(v.accuracy) }} ({{ v.triaged }})</span>
            </li>
          </ul>
          <p class="mt-2 text-xs text-ink-muted">
            {{ t('aiQuality.evalHint') }}
          </p>
        </UiCard>
      </div>
    </template>
  </div>
</template>
