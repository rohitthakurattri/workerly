<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import type { WorkerBooking } from '~/types/models'
import { ApiError } from '~/utils/api-error'
import { formatMoney } from '~/utils/money'

definePageMeta({ middleware: ['worker-profile'] })

const route = useRoute()
const { findJob } = useQuotes()
const { t, locale } = useI18n()

const job = ref<WorkerBooking | null>(null)
const gone = ref(false)

onMounted(async () => {
  try {
    job.value = await findJob(String(route.params.id))
  }
  catch (e) {
    if ([403, 404].includes(ApiError.from(e).status)) gone.value = true
    else throw e
  }
})

const mapUrl = computed(() => {
  const loc = job.value?.address?.location
  return loc ? `https://www.google.com/maps/search/?api=1&query=${loc.lat},${loc.lng}` : null
})
const fmt = (iso: string) => new Intl.DateTimeFormat(locale.value, { weekday: 'short', day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit', timeZone: 'Asia/Kolkata' }).format(new Date(iso))
</script>

<template>
  <div class="mx-auto flex max-w-xl flex-col gap-4">
    <NuxtLink
      to="/"
      class="text-sm text-brand-700"
    >
      ← {{ t('jobs.title') }}
    </NuxtLink>
    <UiEmptyState
      v-if="gone"
      :title="t('jobs.gone')"
    />
    <UiSkeleton
      v-else-if="!job"
      :lines="6"
    />
    <template v-else>
      <div>
        <p class="text-sm font-medium text-success">
          {{ t('jobs.won') }}
        </p>
        <h1 class="text-2xl font-semibold">
          {{ job.category.name }}
        </h1>
        <UiBadge tone="success">
          {{ t(`bookingStatus.${job.status}`, job.status) }}
        </UiBadge>
      </div>
      <UiCard>
        <dl class="flex flex-col gap-3">
          <div v-if="job.customer">
            <dt class="text-xs uppercase tracking-wide text-ink-muted">
              {{ t('jobs.customer') }}
            </dt>
            <dd class="font-medium">
              {{ job.customer.name }}
            </dd>
            <dd class="mt-1">
              <a
                :href="`tel:${job.customer.phone}`"
                class="inline-flex h-11 items-center rounded-[var(--radius-control)] bg-brand-700 px-4 font-medium text-white"
                data-testid="call-customer"
              >📞 {{ t('jobs.call', { name: job.customer.name || job.customer.phone }) }}</a>
            </dd>
          </div>
          <div v-if="job.address">
            <dt class="text-xs uppercase tracking-wide text-ink-muted">
              {{ t('jobs.address') }}
            </dt>
            <dd data-testid="job-address">
              {{ job.address.line1 }}<template v-if="job.address.line2">
                , {{ job.address.line2 }}
              </template><br>
              <template v-if="job.address.landmark">
                {{ job.address.landmark }},
              </template>{{ job.address.locality }} {{ job.address.pincode }}
            </dd>
            <dd v-if="mapUrl">
              <a
                :href="mapUrl"
                target="_blank"
                rel="noopener"
                class="text-sm text-brand-700"
              >{{ t('jobs.openMap') }} ↗</a>
            </dd>
          </div>
          <div>
            <dt class="text-xs uppercase tracking-wide text-ink-muted">
              {{ t('requests.when') }}
            </dt>
            <dd>
              {{ t(`urgency.${job.urgency}`) }}<template v-if="job.preferred_from">
                · {{ fmt(job.preferred_from) }}
              </template>
            </dd>
          </div>
          <div>
            <dt class="text-xs uppercase tracking-wide text-ink-muted">
              {{ t('jobs.problem') }}
            </dt>
            <dd class="whitespace-pre-line break-words">
              {{ job.description }}
            </dd>
          </div>
          <div v-if="job.photos.length">
            <dd class="grid grid-cols-3 gap-2">
              <a
                v-for="p in job.photos"
                :key="p.id"
                :href="p.file?.url"
                target="_blank"
                rel="noopener"
              >
                <img
                  :src="p.file?.url"
                  :alt="t('requests.photoAlt')"
                  class="aspect-square w-full rounded-[var(--radius-control)] object-cover"
                >
              </a>
            </dd>
          </div>
        </dl>
      </UiCard>
      <UiCard>
        <template #title>
          {{ job.kind === 'inspection' ? t('jobs.visitFee') : t('jobs.agreed') }}: {{ formatMoney(job.approved_total) }}
        </template>
        <SharedQuoteBreakdown :revision="job.revision" />
      </UiCard>
      <p class="text-sm text-ink-muted">
        {{ t('jobs.nextSteps') }}
      </p>
    </template>
  </div>
</template>
