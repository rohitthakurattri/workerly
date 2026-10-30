<script setup lang="ts">
import { onMounted, ref } from 'vue'
import type { Address } from '~/types/models'
import { ApiError } from '~/utils/api-error'

const emit = defineEmits<{ done: [] }>()
const { request, save } = useServiceRequest()
const { addresses, load } = useAddresses()
const { t } = useI18n()

const selected = ref(request.value?.address?.id ?? '')
const adding = ref(false)
const loading = ref(true)
const busy = ref(false)
const error = ref<string | null>(null)

onMounted(async () => {
  await load()
  if (!selected.value) selected.value = addresses.value?.find(a => a.is_default)?.id ?? addresses.value?.[0]?.id ?? ''
  adding.value = !addresses.value?.length
  loading.value = false
})

async function added(address: Address) {
  selected.value = address.id
  adding.value = false
  await next()
}

async function next() {
  busy.value = true
  error.value = null
  try {
    await save({ address: selected.value })
    emit('done')
  }
  catch (e) {
    error.value = ApiError.from(e).message
  }
  finally {
    busy.value = false
  }
}
</script>

<template>
  <UiSkeleton
    v-if="loading"
    :lines="3"
  />
  <CustomerAddressForm
    v-else-if="adding"
    @saved="added"
    @cancel="adding = false"
  />
  <form
    v-else
    class="flex flex-col gap-3"
    @submit.prevent="next"
  >
    <fieldset class="flex flex-col gap-2">
      <legend class="sr-only">
        {{ t('requests.address') }}
      </legend>
      <label
        v-for="a in addresses"
        :key="a.id"
        class="flex cursor-pointer items-start gap-3 rounded-[var(--radius-control)] border border-border bg-surface p-3 has-[:checked]:border-brand-700 has-[:checked]:bg-brand-50"
      >
        <input
          v-model="selected"
          type="radio"
          name="address"
          :value="a.id"
          class="mt-1 accent-brand-700"
        >
        <span class="text-sm">
          <strong>{{ a.label || a.locality }}</strong><br>
          {{ a.line1 }}, {{ a.locality }} {{ a.pincode }}
        </span>
      </label>
    </fieldset>
    <div>
      <UiButton
        variant="ghost"
        size="sm"
        @click="adding = true"
      >
        + {{ t('addresses.add') }}
      </UiButton>
    </div>
    <p class="text-xs text-ink-muted">
      {{ t('requests.addressPrivacy') }}
    </p>
    <p
      v-if="error"
      class="text-sm text-danger"
      role="alert"
    >
      {{ error }}
    </p>
    <UiButton
      type="submit"
      size="lg"
      block
      :loading="busy"
      :disabled="!selected"
    >
      {{ t('requests.continue') }}
    </UiButton>
  </form>
</template>
