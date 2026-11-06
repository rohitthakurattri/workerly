/** Voice notes: the server takes up to 2 minutes / 3 MB (RequestAttachment::VOICE_MAX_MS / _SIZE). */
export const VOICE_MAX_MS = 120_000
export const VOICE_MAX_BYTES = 3 * 1024 * 1024
/** Opus at this rate is clear speech and ~0.5 MB for 2 minutes, well under the limit. */
export const VOICE_BITS_PER_SECOND = 32_000

// Best first: Opus in WebM (Chrome, Firefox, Android), Ogg Opus, then MP4/AAC (Safari, iOS).
const CANDIDATES = ['audio/webm;codecs=opus', 'audio/webm', 'audio/ogg;codecs=opus', 'audio/mp4;codecs=mp4a.40.2', 'audio/mp4']

/** The first recording format this browser supports, or '' to let the browser choose. */
export function pickVoiceMimeType(isTypeSupported: (type: string) => boolean): string {
  return CANDIDATES.find((t) => {
    try {
      return isTypeSupported(t)
    }
    catch {
      return false
    }
  }) ?? ''
}

/** A file name the server recognises from the recorder's type ("audio/mp4;codecs=..." -> voice.m4a). */
export function voiceFilename(mimeType: string): string {
  const base = mimeType.split(';')[0]!.trim()
  if (base === 'audio/mp4' || base === 'audio/x-m4a') return 'voice.m4a'
  if (base === 'audio/ogg') return 'voice.ogg'
  if (base === 'audio/mpeg') return 'voice.mp3'
  return 'voice.webm'
}

/** 75_400 -> "1:15". */
export function formatDuration(ms: number): string {
  const total = Math.max(0, Math.floor(ms / 1000))
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}`
}

/** Joins a transcript onto the description once (re-adding the same words is a no-op). */
export function appendTranscript(description: string, transcript: string): string {
  const text = description.trim()
  const spoken = transcript.trim()
  if (!spoken || text.includes(spoken)) return text
  return text ? `${text}\n\n${spoken}` : spoken
}
