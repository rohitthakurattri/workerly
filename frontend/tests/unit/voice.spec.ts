import { describe, expect, it } from 'vitest'
import { appendTranscript, formatDuration, pickVoiceMimeType, voiceFilename } from '~/utils/voice'

describe('voice notes', () => {
  it('picks Opus in WebM when available, MP4 on Safari, or lets the browser choose', () => {
    expect(pickVoiceMimeType(t => t.startsWith('audio/webm'))).toBe('audio/webm;codecs=opus')
    expect(pickVoiceMimeType(t => t.startsWith('audio/mp4'))).toBe('audio/mp4;codecs=mp4a.40.2')
    expect(pickVoiceMimeType(() => false)).toBe('')
    expect(pickVoiceMimeType(() => {
      throw new Error('old browser')
    })).toBe('')
  })

  it('names the upload so the server recognises the container', () => {
    expect(voiceFilename('audio/webm;codecs=opus')).toBe('voice.webm')
    expect(voiceFilename('audio/mp4;codecs=mp4a.40.2')).toBe('voice.m4a')
    expect(voiceFilename('audio/ogg')).toBe('voice.ogg')
    expect(voiceFilename('')).toBe('voice.webm')
  })

  it('formats durations as m:ss', () => {
    expect(formatDuration(0)).toBe('0:00')
    expect(formatDuration(75_400)).toBe('1:15')
    expect(formatDuration(120_000)).toBe('2:00')
    expect(formatDuration(-5)).toBe('0:00')
  })

  it('adds the transcript to the description once', () => {
    expect(appendTranscript('', ' Tap leaking ')).toBe('Tap leaking')
    expect(appendTranscript('Kitchen', 'Tap leaking')).toBe('Kitchen\n\nTap leaking')
    expect(appendTranscript('Kitchen\n\nTap leaking', 'Tap leaking')).toBe('Kitchen\n\nTap leaking')
    expect(appendTranscript('Kitchen', '  ')).toBe('Kitchen')
  })
})
