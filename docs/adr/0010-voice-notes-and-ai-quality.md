# ADR 0010 — Voice notes, transcription and AI triage quality

**Status:** accepted 2026-11-07 (Phase 8). No transcription model was chosen, so as with triage (ADR 0005) the fake adapter is the default and the feature is off in production until one is.

## Voice notes
- **One per request**, recorded in the customer app with `MediaRecorder` (Opus/WebM on Chrome, Firefox and Android; MP4/AAC on Safari and iOS) at 32 kbit/s, **max 2 minutes**. The server takes **≤ 3 MB** and refuses anything whose *bytes* aren't an audio/video container (`Marcel::Magic`; Marcel alone would trust a renamed file's extension). A new recording replaces the old one. Deleted like a photo.
- **No server-side transcoding:** the servers have no ffmpeg. The recording is stored as sent (stored as `audio/*` so browsers show an audio player). The duration is reported by the app, clamped to 2 minutes, and used for display only.
- **Retention:** voice notes go with their draft (30-day stale-draft purge, including the AI log rows; see ADR 0009's escape hatch).

## Transcription
- `Requests::TranscribeVoiceNoteJob` → `Ai::TranscribeVoiceNote` → `Ai::Gateway` (use case `transcribe`, 30 s timeout), so it shares the per-user/global daily budgets, circuit breaker, cache (by the audio's checksum) and the `ai_analyses` log with triage. Prompt (a vocabulary hint for trade words) in `config/ai/prompts/transcribe.yml`, versioned. Language hint = the customer's app language.
- **Adapters:** `fake` returns a fixed sentence per language (so the flow works offline and in tests); `openai` posts the audio as multipart to `/v1/audio/transcriptions` (never a link to our bucket). `AI_TRANSCRIBE_MODEL` must be set. Per-minute prices go in `config/ai/pricing.yml` (`per_minute`).
- **Flag:** `AI_TRANSCRIBE_ENABLED` (on in development/test, off in production). Off or failing → `transcript_status` `skipped` / `failed`; the recording is kept.
- **The customer decides:** the transcript is shown with *Add to description*; nothing is added automatically. Triage also reads a transcript the customer didn't paste, labelled as such.

## Who hears what
| Viewer | Recording | Transcript |
| --- | --- | --- |
| Customer, admin | yes | as transcribed |
| Invited worker (not booked) | **no** — a voice can carry a phone number no redaction can remove | contact details removed (`Shared::Redact`) |
| Booked worker, while contact is open | yes | as transcribed |

Spoken numbers transcribed as words ("nine eight one…") are not caught by the redactor; the recording rule is the real protection.

## Triage quality
- **Live report** (`GET /admin/ai/quality`, admin app → *AI quality*, admin only): accuracy of the AI's category against what customers submitted (they always confirm, so their choice is the label), accuracy when pre-selected (confidence ≥ 0.6), coverage, a calibration table, per-category precision/recall, top mix-ups, per prompt/model version, and voice-note transcription counts.
- **Offline evaluation:** `config/ai/eval/triage.yml` (36 labelled cases in English, Hindi, Punjabi and romanised mixes, plus a no-fit case) and `bin/rails "ai:eval[triage]"`, which calls the adapter directly with the production prompt (no budget, cache or log rows) and fails below `AI_EVAL_MIN_ACCURACY` (0.8). Run it before switching model or prompt. The fake keyword baseline scores 33/36.
- **Growing the set:** `bin/rails "ai:export_triage_cases[from,to]"` prints submitted requests as JSON lines — redacted text, language and chosen category, no names, addresses, photos or ids. Review each label before adding it.
