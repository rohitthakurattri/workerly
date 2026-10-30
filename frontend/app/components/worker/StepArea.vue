<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { ApiError } from '~/utils/api-error'

const emit = defineEmits<{ saved: [] }>()
const { profile, cities, addArea, removeArea } = useWorkerProfile()
const { t } = useI18n()

const city = ref('')
const radiusKm = ref(5)
const label = ref('')
const point = ref<{ lat: number, lng: number } | null>(null)
const error = ref<string | null>(null)
const busy = ref(false)

const selectedCity = computed(() => cities.value.find(c => c.slug === city.value))
watch(cities, (list) => {
  if (!city.value && list[0]) city.value = list[0].slug
}, { immediate: true })
watch(city, () => {
  point.value = null
})

// The centre is the pin the worker placed (tap, drag or GPS), else the city centre.
const center = computed(() => point.value ?? selectedCity.value?.center ?? null)

async function add() {
  if (!center.value) return
  busy.value = true
  error.value = null
  try {
    await addArea({ city: city.value, ...center.value, radius_m: radiusKm.value * 1000, label: label.value.trim() || undefined })
    label.value = ''
  }
  catch (e) {
    const err = ApiError.from(e)
    error.value = Object.values(err.fieldErrors)[0]?.[0] ?? err.message
  }
  finally {
    busy.value = false
  }
}

async function remove(id: string) {
  busy.value = true
  try {
    await removeArea(id)
  }
  finally {
    busy.value = false
  }
}

const cityName = (slug: string) => cities.value.find(c => c.slug === slug)?.name ?? slug
</script>

<template>
  <div class="flex flex-col gap-4">
    <ul
      v-if="profile?.service_areas.length"
      class="flex flex-col gap-2"
    >
      <li
        v-for="a in profile.service_areas"
        :key="a.id"
        class="flex items-center justify-between rounded-[var(--radius-control)] border border-border bg-surface px-3 py-2"
      >
        <span>
          <strong>{{ a.label || cityName(a.city) }}</strong>
          <span class="text-sm text-ink-muted"> · {{ t('onboarding.withinKm', { km: a.radius_m / 1000 }) }}</span>
        </span>
        <UiButton
          variant="ghost"
          size="sm"
          :disabled="busy"
          @click="remove(a.id)"
        >
          {{ t('common.remove') }}
        </UiButton>
      </li>
    </ul>

    <form
      class="flex flex-col gap-4 rounded-[var(--radius-card)] border border-dashed border-border p-4"
      @submit.prevent="add"
    >
      <UiSelect
        v-model="city"
        :label="t('onboarding.city')"
        :options="cities.map(c => ({ value: c.slug, label: c.name }))"
      />
      <div class="flex flex-col gap-2">
        <span class="text-sm font-medium">{{ t('onboarding.areaCenter') }}</span>
        <p class="text-sm text-ink-muted">
          {{ point ? t('onboarding.centerGps') : t('onboarding.centerCity', { city: selectedCity?.name ?? '' }) }}
        </p>
        <SharedMapPicker
          v-model="point"
          :fallback="selectedCity?.center ?? null"
          :radius-m="radiusKm * 1000"
          :label="t('onboarding.areaCenter')"
        />
      </div>
      <div class="flex flex-col gap-1.5">
        <label
          for="radius"
          class="text-sm font-medium"
        >{{ t('onboarding.radius', { km: radiusKm }) }}</label>
        <input
          id="radius"
          v-model.number="radiusKm"
          type="range"
          min="1"
          max="25"
          step="1"
          class="accent-brand-700"
        >
      </div>
      <UiInput
        v-model="label"
        :label="t('onboarding.areaLabel')"
        :hint="t('onboarding.areaLabelHint')"
        maxlength="60"
      />
      <p
        v-if="error"
        class="text-sm text-danger"
        role="alert"
      >
        {{ error }}
      </p>
      <div class="flex flex-wrap gap-2">
        <UiButton
          type="submit"
          variant="secondary"
          :loading="busy"
          :disabled="!center || (profile?.service_areas.length ?? 0) >= 3"
        >
          {{ t('onboarding.addArea') }}
        </UiButton>
        <UiButton
          v-if="profile?.service_areas.length"
          @click="emit('saved')"
        >
          {{ t('onboarding.continue') }}
        </UiButton>
      </div>
    </form>
  </div>
</template>
