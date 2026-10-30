<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import type { Address, LatLng } from '~/types/models'
import { ApiError } from '~/utils/api-error'

const props = defineProps<{ address?: Address | null }>()
const emit = defineEmits<{ saved: [Address], cancel: [] }>()
const { addresses, create, update } = useAddresses()
const { cities, load: loadCatalog } = useCatalog()
const { t } = useI18n()

const a = props.address
const point = ref<LatLng | null>(a ? { ...a.location } : null)
const form = ref({
  label: a?.label ?? '',
  line1: a?.line1 ?? '',
  line2: a?.line2 ?? '',
  landmark: a?.landmark ?? '',
  locality: a?.locality ?? '',
  pincode: a?.pincode ?? '',
})
const errors = ref<Record<string, string>>({})
const error = ref<string | null>(null)
const busy = ref(false)

onMounted(loadCatalog)
const fallback = computed(() => cities.value[0]?.center ?? null)
const canSave = computed(() => !!point.value && form.value.line1.trim() && form.value.locality.trim() && /^[1-9]\d{5}$/.test(form.value.pincode.replace(/\s/g, '')))

async function submit() {
  if (!point.value) return
  busy.value = true
  errors.value = {}
  error.value = null
  try {
    const input = { ...form.value, ...point.value }
    const saved = a ? await update(a.id, input) : await create({ ...input, is_default: !addresses.value?.length })
    emit('saved', saved)
  }
  catch (e) {
    const err = ApiError.from(e)
    errors.value = Object.fromEntries(Object.entries(err.fieldErrors).map(([k, v]) => [k, v[0] ?? '']))
    error.value = errors.value.location ? t('addresses.outsideArea') : Object.keys(errors.value).length ? null : err.message
  }
  finally {
    busy.value = false
  }
}
</script>

<template>
  <form
    class="flex flex-col gap-4"
    @submit.prevent="submit"
  >
    <SharedMapPicker
      v-model="point"
      :fallback="fallback"
      :label="t('addresses.mapLabel')"
      auto-locate
    />
    <p
      v-if="error"
      class="text-sm text-danger"
      role="alert"
    >
      {{ error }}
    </p>
    <UiInput
      v-model="form.line1"
      :label="t('addresses.line1')"
      :placeholder="t('addresses.line1Placeholder')"
      :error="errors.line1"
      autocomplete="address-line1"
      maxlength="200"
    />
    <div class="grid gap-4 sm:grid-cols-2">
      <UiInput
        v-model="form.locality"
        :label="t('addresses.locality')"
        :hint="t('addresses.localityHint')"
        :placeholder="t('addresses.localityPlaceholder')"
        :error="errors.locality"
        autocomplete="address-level3"
        maxlength="120"
      />
      <UiInput
        v-model="form.pincode"
        :label="t('addresses.pincode')"
        :error="errors.pincode"
        inputmode="numeric"
        autocomplete="postal-code"
        maxlength="7"
      />
    </div>
    <UiInput
      v-model="form.landmark"
      :label="t('addresses.landmark')"
      :placeholder="t('addresses.landmarkPlaceholder')"
      :error="errors.landmark"
      maxlength="120"
    />
    <UiInput
      v-model="form.label"
      :label="t('addresses.label')"
      :placeholder="t('addresses.labelPlaceholder')"
      maxlength="40"
    />
    <div class="flex flex-wrap gap-2">
      <UiButton
        type="submit"
        :loading="busy"
        :disabled="!canSave"
      >
        {{ t('addresses.save') }}
      </UiButton>
      <UiButton
        variant="ghost"
        @click="emit('cancel')"
      >
        {{ t('common.cancel') }}
      </UiButton>
    </div>
  </form>
</template>
