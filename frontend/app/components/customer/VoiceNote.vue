<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { ApiError } from '~/utils/api-error'
import { VOICE_BITS_PER_SECOND, VOICE_MAX_MS, formatDuration, pickVoiceMimeType } from '~/utils/voice'

/**
 * Record one voice note (up to 2 minutes) for the draft. The server transcribes it; the customer
 * decides whether the transcript goes into the description. Workers hear the recording only once
 * booked (before that they see the transcript with contact details removed).
 */
const emit = defineEmits<{ useTranscript: [text: string] }>()
const { request, addVoiceNote, removeVoiceNote, refreshVoiceNote } = useServiceRequest()
const toast = useToast()
const { t } = useI18n()

const supported = ref(false)
const recording = ref(false)
const uploading = ref(false)
const elapsed = ref(0)
const error = ref<string | null>(null)
let recorder: MediaRecorder | null = null
let stream: MediaStream | null = null
let chunks: Blob[] = []
let startedAt = 0
let tick: ReturnType<typeof setInterval> | null = null
let poll: ReturnType<typeof setTimeout> | null = null
let cancelled = false

const note = computed(() => request.value?.voice_note ?? null)

onMounted(() => {
  supported.value = typeof window !== 'undefined' && 'MediaRecorder' in window && !!navigator.mediaDevices?.getUserMedia
})

function stopTracks() {
  stream?.getTracks().forEach(tr => tr.stop())
  stream = null
  if (tick) clearInterval(tick)
  tick = null
}

async function start() {
  error.value = null
  try {
    stream = await navigator.mediaDevices.getUserMedia({ audio: { echoCancellation: true, noiseSuppression: true } })
  }
  catch {
    error.value = t('voice.micDenied')
    return
  }
  const mimeType = pickVoiceMimeType(type => MediaRecorder.isTypeSupported(type))
  recorder = new MediaRecorder(stream, { ...(mimeType ? { mimeType } : {}), audioBitsPerSecond: VOICE_BITS_PER_SECOND })
  chunks = []
  cancelled = false
  recorder.ondataavailable = (e) => {
    if (e.data.size) chunks.push(e.data)
  }
  recorder.onstop = () => {
    const duration = Date.now() - startedAt
    stopTracks()
    recording.value = false
    if (cancelled || !chunks.length) return
    void upload(new Blob(chunks, { type: recorder?.mimeType || mimeType || 'audio/webm' }), duration)
  }
  startedAt = Date.now()
  elapsed.value = 0
  recorder.start(1000)
  recording.value = true
  tick = setInterval(() => {
    elapsed.value = Date.now() - startedAt
    if (elapsed.value >= VOICE_MAX_MS) stop()
  }, 250)
}

function stop() {
  if (recorder?.state === 'recording') recorder.stop()
}

function discardRecording() {
  cancelled = true
  stop()
}

async function upload(audio: Blob, duration: number) {
  uploading.value = true
  try {
    await addVoiceNote(audio, Math.min(duration, VOICE_MAX_MS))
  }
  catch (e) {
    const err = ApiError.from(e)
    error.value = Object.values(err.fieldErrors)[0]?.[0] ?? err.message
  }
  finally {
    uploading.value = false
  }
}

async function remove() {
  try {
    await removeVoiceNote()
  }
  catch (e) {
    toast.error(ApiError.from(e).message)
  }
}

// The transcript arrives a few seconds after upload; check every 2 s for up to a minute.
let polls = 0
function schedulePoll() {
  if (poll) clearTimeout(poll)
  poll = null
  if (note.value?.transcript_status !== 'pending' || polls >= 30) return
  poll = setTimeout(async () => {
    polls += 1
    try {
      await refreshVoiceNote()
    }
    catch { /* try again on the next tick */ }
    schedulePoll()
  }, 2000)
}
watch(() => note.value?.id, () => {
  polls = 0
  schedulePoll()
}, { immediate: true })

onBeforeUnmount(() => {
  cancelled = true
  stop()
  stopTracks()
  if (poll) clearTimeout(poll)
})
</script>

<template>
  <div
    v-if="supported || note"
    class="flex flex-col gap-2"
    data-testid="voice-note"
  >
    <span class="text-sm font-medium">{{ t('voice.title') }} <span class="font-normal text-ink-muted">({{ t('common.optional') }})</span></span>

    <!-- Recording -->
    <div
      v-if="recording"
      class="flex items-center gap-3 rounded-[var(--radius-control)] border border-danger/40 bg-danger-soft p-3"
    >
      <span
        class="size-3 animate-pulse rounded-full bg-danger"
        aria-hidden="true"
      />
      <span
        class="font-medium tabular-nums"
        role="timer"
        aria-live="off"
      >{{ formatDuration(elapsed) }} / {{ formatDuration(VOICE_MAX_MS) }}</span>
      <span class="flex-1" />
      <UiButton
        variant="ghost"
        size="sm"
        @click="discardRecording"
      >
        {{ t('common.cancel') }}
      </UiButton>
      <UiButton
        size="sm"
        data-testid="voice-stop"
        @click="stop"
      >
        {{ t('voice.stop') }}
      </UiButton>
    </div>

    <!-- A saved note -->
    <div
      v-else-if="note"
      class="flex flex-col gap-2 rounded-[var(--radius-control)] border border-border bg-surface p-3"
    >
      <div class="flex items-center gap-2">
        <audio
          v-if="note.file?.url"
          :src="note.file.url"
          controls
          preload="metadata"
          class="h-10 min-w-0 flex-1"
        />
        <span
          v-if="note.duration_ms"
          class="text-sm text-ink-muted tabular-nums"
        >{{ formatDuration(note.duration_ms) }}</span>
        <UiButton
          variant="ghost"
          size="sm"
          :aria-label="t('voice.remove')"
          @click="remove"
        >
          ✕
        </UiButton>
      </div>
      <p
        v-if="note.transcript_status === 'pending'"
        class="text-sm text-ink-muted"
        role="status"
        data-testid="voice-pending"
      >
        {{ t('voice.transcribing') }}
      </p>
      <template v-else-if="note.transcript_status === 'succeeded' && note.transcript">
        <p class="text-sm text-ink-muted">
          {{ t('voice.weHeard') }}
        </p>
        <blockquote
          class="border-l-2 border-brand-600 pl-3 text-sm"
          data-testid="voice-transcript"
        >
          {{ note.transcript }}
        </blockquote>
        <div>
          <UiButton
            variant="secondary"
            size="sm"
            data-testid="voice-use"
            @click="emit('useTranscript', note.transcript)"
          >
            {{ t('voice.useTranscript') }}
          </UiButton>
        </div>
      </template>
      <p
        v-else-if="note.transcript_status === 'failed'"
        class="text-sm text-ink-muted"
      >
        {{ t('voice.noTranscript') }}
      </p>
      <p class="text-xs text-ink-muted">
        {{ t('voice.privacy') }}
      </p>
    </div>

    <!-- Nothing yet -->
    <div v-else>
      <UiButton
        variant="secondary"
        :loading="uploading"
        data-testid="voice-record"
        @click="start"
      >
        🎤 {{ uploading ? t('voice.saving') : t('voice.record') }}
      </UiButton>
      <p class="mt-1 text-xs text-ink-muted">
        {{ t('voice.hint') }}
      </p>
    </div>

    <p
      v-if="error"
      class="text-sm text-danger"
      role="alert"
    >
      {{ error }}
    </p>
  </div>
</template>
