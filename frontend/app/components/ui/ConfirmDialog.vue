<script setup lang="ts">
import Modal from './Modal.vue'
import Button from './Button.vue'

withDefaults(defineProps<{
  title: string
  message: string
  confirmLabel?: string
  cancelLabel?: string
  danger?: boolean
  loading?: boolean
}>(), { confirmLabel: 'Confirm', cancelLabel: 'Cancel', danger: false, loading: false })

const open = defineModel<boolean>('open', { default: false })
const emit = defineEmits<{ confirm: [] }>()
</script>

<template>
  <Modal
    v-model:open="open"
    :title="title"
  >
    <p class="text-ink-muted">
      {{ message }}
    </p>
    <template #footer>
      <Button
        variant="secondary"
        @click="open = false"
      >
        {{ cancelLabel }}
      </Button>
      <Button
        :variant="danger ? 'danger' : 'primary'"
        :loading="loading"
        @click="emit('confirm')"
      >
        {{ confirmLabel }}
      </Button>
    </template>
  </Modal>
</template>
