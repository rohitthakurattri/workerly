<script setup lang="ts">
import { nextTick, ref, watch } from 'vue'
import type { BookingMessage } from '~/types/models'
import { ApiError } from '~/utils/api-error'

const props = defineProps<{ messages: BookingMessage[], me: 'customer' | 'worker', open: boolean, send: (body: string) => Promise<void> }>()
const { t, locale } = useI18n()
const toast = useToast()
const draft = ref('')
const sending = ref(false)
const list = ref<HTMLElement | null>(null)

watch(() => props.messages.length, async () => {
  await nextTick()
  list.value?.scrollTo({ top: list.value.scrollHeight })
})

async function submit() {
  const body = draft.value.trim()
  if (!body || sending.value) return
  sending.value = true
  try {
    await props.send(body)
    draft.value = ''
  }
  catch (e) {
    toast.error(ApiError.from(e).message)
  }
  finally {
    sending.value = false
  }
}

const time = (iso: string) => new Intl.DateTimeFormat(locale.value, { hour: 'numeric', minute: '2-digit', day: 'numeric', month: 'short', timeZone: 'Asia/Kolkata' }).format(new Date(iso))
</script>

<template>
  <UiCard>
    <template #title>
      {{ t('booking.chat') }}
    </template>
    <div
      ref="list"
      class="flex max-h-80 flex-col gap-2 overflow-y-auto"
      data-testid="chat-messages"
      aria-live="polite"
    >
      <p
        v-if="!messages.length"
        class="text-sm text-ink-muted"
      >
        {{ t('booking.noMessages') }}
      </p>
      <div
        v-for="m in messages"
        :key="m.id"
        class="max-w-[85%] rounded-[var(--radius-card)] px-3 py-2 text-sm"
        :class="m.sender_role === me ? 'self-end bg-brand-700 text-white' : 'self-start bg-surface-muted'"
      >
        <p class="whitespace-pre-line break-words">
          {{ m.body }}
        </p>
        <p
          class="mt-1 text-[0.7rem] opacity-75"
        >
          {{ m.sender_name }} · {{ time(m.created_at) }}
        </p>
      </div>
    </div>
    <form
      v-if="open"
      class="mt-3 flex gap-2"
      @submit.prevent="submit"
    >
      <label class="sr-only" for="chat-input">{{ t('booking.chatPlaceholder') }}</label>
      <input
        id="chat-input"
        v-model="draft"
        maxlength="2000"
        :placeholder="t('booking.chatPlaceholder')"
        class="h-11 min-w-0 flex-1 rounded-[var(--radius-control)] border border-border bg-surface px-3"
        data-testid="chat-input"
      >
      <UiButton
        type="submit"
        :loading="sending"
        :disabled="!draft.trim()"
      >
        {{ t('booking.send') }}
      </UiButton>
    </form>
    <p
      v-else
      class="mt-3 text-sm text-ink-muted"
    >
      {{ t('booking.chatClosed') }}
    </p>
  </UiCard>
</template>
