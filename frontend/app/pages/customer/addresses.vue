<script setup lang="ts">
import { onMounted, ref } from 'vue'
import type { Address } from '~/types/models'
import { ApiError } from '~/utils/api-error'

definePageMeta({ middleware: ['role'], roles: ['customer'] })

const { addresses, load, update, remove } = useAddresses()
const toast = useToast()
const { t } = useI18n()
const editing = ref<Address | 'new' | null>(null)
const removing = ref<Address | null>(null)

onMounted(load)

async function makeDefault(a: Address) {
  try {
    await update(a.id, { is_default: true })
  }
  catch (e) {
    toast.error(ApiError.from(e).message)
  }
}

async function doRemove() {
  if (!removing.value) return
  await remove(removing.value.id)
  removing.value = null
}
</script>

<template>
  <div class="mx-auto flex max-w-xl flex-col gap-4">
    <h1 class="text-2xl font-semibold">
      {{ t('addresses.title') }}
    </h1>
    <UiCard v-if="editing">
      <CustomerAddressForm
        :address="editing === 'new' ? null : editing"
        @saved="editing = null"
        @cancel="editing = null"
      />
    </UiCard>
    <template v-else>
      <UiSkeleton
        v-if="!addresses"
        :lines="3"
      />
      <UiEmptyState
        v-else-if="!addresses.length"
        :title="t('addresses.none')"
      />
      <ul
        v-else
        class="flex flex-col gap-2"
      >
        <li
          v-for="a in addresses"
          :key="a.id"
          class="rounded-[var(--radius-card)] border border-border bg-surface p-4"
        >
          <div class="flex items-start justify-between gap-2">
            <p class="text-sm">
              <strong>{{ a.label || a.locality }}</strong>
              <UiBadge
                v-if="a.is_default"
                tone="info"
                class="ml-2"
              >
                {{ t('addresses.default') }}
              </UiBadge><br>
              {{ a.line1 }}<template v-if="a.landmark">
                ({{ a.landmark }})
              </template>, {{ a.locality }} {{ a.pincode }}
            </p>
          </div>
          <div class="mt-2 flex flex-wrap gap-1">
            <UiButton
              variant="ghost"
              size="sm"
              @click="editing = a"
            >
              {{ t('requests.edit') }}
            </UiButton>
            <UiButton
              v-if="!a.is_default"
              variant="ghost"
              size="sm"
              @click="makeDefault(a)"
            >
              {{ t('addresses.makeDefault') }}
            </UiButton>
            <UiButton
              variant="ghost"
              size="sm"
              @click="removing = a"
            >
              {{ t('common.remove') }}
            </UiButton>
          </div>
        </li>
      </ul>
      <div>
        <UiButton @click="editing = 'new'">
          + {{ t('addresses.add') }}
        </UiButton>
      </div>
    </template>
    <UiConfirmDialog
      :open="!!removing"
      :title="t('addresses.removeTitle')"
      :message="t('addresses.removeBody')"
      :confirm-label="t('common.remove')"
      :cancel-label="t('common.cancel')"
      danger
      @update:open="v => { if (!v) removing = null }"
      @confirm="doRemove"
    />
  </div>
</template>
