<script setup lang="ts">
import type { VoiceNote } from '~/types/models'
import { formatDuration } from '~/utils/voice'

/** Read-only voice note: the recording when this viewer may hear it, and the transcript. */
defineProps<{ note: VoiceNote, hiddenHint?: string }>()
const { t } = useI18n()
</script>

<template>
  <div
    class="flex flex-col gap-2"
    data-testid="voice-note-view"
  >
    <div
      v-if="note.file?.url"
      class="flex items-center gap-2"
    >
      <audio
        :src="note.file.url"
        controls
        preload="metadata"
        class="h-10 min-w-0 flex-1"
      />
      <span
        v-if="note.duration_ms"
        class="text-sm text-ink-muted tabular-nums"
      >{{ formatDuration(note.duration_ms) }}</span>
    </div>
    <p
      v-else-if="hiddenHint"
      class="text-xs text-ink-muted"
    >
      {{ hiddenHint }}
    </p>
    <blockquote
      v-if="note.transcript"
      class="whitespace-pre-line border-l-2 border-border pl-3 text-sm"
    >
      <span class="block text-xs text-ink-muted">{{ t('voice.transcriptLabel') }}</span>
      {{ note.transcript }}
    </blockquote>
    <p
      v-else-if="note.transcript_status === 'pending'"
      class="text-sm text-ink-muted"
    >
      {{ t('voice.transcribing') }}
    </p>
  </div>
</template>
