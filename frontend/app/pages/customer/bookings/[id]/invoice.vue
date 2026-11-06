<script setup lang="ts">
import { onMounted, ref } from 'vue'
import type { Invoice } from '~/types/models'
import { ApiError } from '~/utils/api-error'

definePageMeta({ middleware: ['role'], roles: ['customer'] })

const route = useRoute()
const { invoice: fetchInvoice } = usePayments()
const { t } = useI18n()
const invoice = ref<Invoice | null>(null)
const gone = ref(false)
const id = String(route.params.id)
const print = () => window.print()

onMounted(async () => {
  try {
    invoice.value = await fetchInvoice('customer', id)
  }
  catch (e) {
    if (ApiError.from(e).status === 404) gone.value = true
    else throw e
  }
})
</script>

<template>
  <div class="mx-auto flex max-w-2xl flex-col gap-4">
    <div class="flex items-center justify-between print:hidden">
      <NuxtLink
        :to="`/bookings/${id}`"
        class="text-sm text-brand-700"
      >
        ← {{ t('invoice.backToBooking') }}
      </NuxtLink>
      <UiButton
        v-if="invoice"
        variant="secondary"
        size="sm"
        @click="print"
      >
        {{ t('invoice.print') }}
      </UiButton>
    </div>
    <UiEmptyState
      v-if="gone"
      :title="t('invoice.notYet')"
    />
    <UiSkeleton
      v-else-if="!invoice"
      :lines="8"
    />
    <SharedInvoiceView
      v-else
      :invoice="invoice"
    />
  </div>
</template>
