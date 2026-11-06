# Phase 8 — Voice notes and AI quality (handover)

**Exit gate:** a customer can describe the job by voice in any of the three languages; unbooked workers never get the recording; triage accuracy is measurable on live traffic and on a labelled set before any model change.
**Status (2026-11-07):** met locally.
- `spec/requests/api/v1/customer/voice_notes_spec.rb`: upload → background transcription through the gateway (in the customer's language), replace, byte-level type check (a renamed JPEG is refused), 3 MB cap, drafts only, flag off, provider failure keeps the recording, triage reads the transcript, invited worker gets a redacted transcript and no audio, booked worker gets both.
- `spec/services/ai/triage_quality_spec.rb`: accuracy, pre-select accuracy, calibration, precision/recall, confusions; the eval harness on the fake adapter (≥ 80%, no log rows); admin-only report.
- `e2e/voice.spec.ts`: Chromium's fake microphone → recording → transcript → *Add to description* (once) → triage pre-selects Plumber; admin opens *AI quality*.
- RSpec: 521 examples. Vitest: 80. Playwright: `voice.spec.ts` 2/2. RuboCop, Brakeman, ESLint and typecheck (all 3 apps) are clean.

Rules and defaults: `docs/adr/0010-voice-notes-and-ai-quality.md`.

## 1. What was built
**Backend:** voice note upload (`Requests::AddVoiceNote`), transcription job and service through `Ai::Gateway` (new `invoke:` hook and `transcribe` use case), OpenAI transcription adapter (multipart), fake transcripts in en/hi/pa, per-minute pricing, `VoiceNoteResource` with redaction and audio rules per viewer, triage reading the transcript, `Ai::TriageAccuracy`, `Ai::TriageEval` + labelled set, `ai:eval` and `ai:export_triage_cases` tasks.
**Customer app:** *Record a voice note* in the describe step (timer, 2-minute stop, cancel), playback, "turning it into text…", the transcript with *Add to description*, remove, privacy note.
**Worker app:** lead page shows the transcript (redacted) and says the recording comes after booking; job page plays the recording.
**Admin app:** voice note on the request page; **AI quality** page (admin only).

## 2. API
| Endpoint | Who |
| --- | --- |
| `POST /customer/service_requests/:id/voice_note` (multipart `file`, `duration_ms`) | the draft's customer |
| `DELETE /customer/service_requests/:id/attachments/:voice_note_id` | the draft's customer |
| `voice_note` on `GET /customer/service_requests/:id`, worker leads and bookings, admin request detail | as in ADR 0010's table |
| `GET /admin/ai/quality?from&to` | admin |

## 3. Commands and settings
```bash
cd backend && bin/rails db:migrate      # request_attachments: transcript_status, transcript_language, duration_ms, transcription_analysis_id
bin/rails "ai:eval[triage]"             # labelled set against AI_ADAPTER / AI_TRIAGE_MODEL
bin/rails "ai:export_triage_cases[2026-11-01,2026-11-30]" > cases.jsonl
cd ../frontend && npm run gen:api
```
New ENV: `AI_TRANSCRIBE_ENABLED`, `AI_TRANSCRIBE_MODEL`, `AI_EVAL_MIN_ACCURACY` (rake only).

## 4. Manual verification
1. Customer app (:3001) → **Post a job** → **Record a voice note**, allow the microphone, speak a few seconds → **Stop**.
2. "Turning your voice note into text…", then *We heard: …* (the fake adapter's sentence in your app language). **Add to description**; tapping again doesn't duplicate it.
3. Continue: the category step pre-selects **Plumber**.
4. Record again: the first note is replaced. Remove it with ✕.
5. Submit a request with a voice note. As an invited worker (:3002), the lead shows the transcript and "You can listen to the recording once you're booked." After booking, the job page plays it.
6. Admin (:3003) → the request shows the recording and transcript. **AI quality** shows accuracy, calibration and mix-ups for the period.
7. `bin/rails "ai:eval[triage]"` prints 33/36 with the fake adapter and lists the misses.

## 5. Not done in Phase 8
- **A transcription model and a triage model** (and their prices): still unchosen; both features are off in production until then.
- **Server-side duration check and transcoding** (needs ffmpeg on the servers); the 3 MB cap bounds what's stored.
- Voice notes in chat and on disputes; video attachments (`kind: video` exists but nothing uses it).
- Spoken phone numbers written as words are not redacted in transcripts (the recording rule covers unbooked workers).
