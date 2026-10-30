<script setup lang="ts">
import { nextTick, ref, watch } from 'vue'

const props = defineProps<{ title: string, dismissible?: boolean }>()
const open = defineModel<boolean>('open', { default: false })
const dialog = ref<HTMLDialogElement | null>(null)

// Native <dialog> gives focus trapping, Esc handling and inert background for free.
watch(open, async (value) => {
  await nextTick()
  if (!dialog.value) return
  if (value && !dialog.value.open) dialog.value.showModal?.()
  if (!value && dialog.value.open) dialog.value.close?.()
}, { immediate: true })

function onCancel(e: Event) {
  if (props.dismissible === false) e.preventDefault()
  else open.value = false
}
</script>

<template>
  <dialog
    ref="dialog"
    class="m-auto w-[min(32rem,calc(100vw-2rem))] rounded-[var(--radius-card)] border border-border bg-surface p-0 text-ink shadow-xl backdrop:bg-ink/40"
    :aria-label="title"
    @cancel="onCancel"
    @close="open = false"
  >
    <div class="p-5">
      <h2 class="mb-3 text-lg font-semibold">
        {{ title }}
      </h2>
      <slot />
    </div>
    <footer
      v-if="$slots.footer"
      class="flex justify-end gap-2 border-t border-border px-5 py-3"
    >
      <slot name="footer" />
    </footer>
  </dialog>
</template>
