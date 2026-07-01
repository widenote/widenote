# Voice Input, ASR, And Transcript Correction Plan

Status: Kimi-reviewed draft for product-owner confirmation
Date: 2026-06-30

Scope: WideNote mobile voice input, local ASR, optional Xiaomi MiMo ASR,
transcript correction, settings, source refs, and validation plan.

## Inputs

- Product direction from 2026-06-30 discussion:
  - Audio is a first-class attachment.
  - ASR text is the default record text for downstream Memory/card/todo/insight
    processing.
  - Original audio remains source truth.
  - Local ASR uses sherpa-onnx + SenseVoice unless blocked by implementation
    evidence.
  - Real-time transcript preview should ship in the first slice if feasible.
  - Remote ASR is explicit opt-in. Xiaomi MiMo is the first remote provider to
    research and shape.
  - Transcript correction must not write Memory. It records correction evidence
    for the Memory Agent to use later.
  - A settings page is required for ASR provider, model download, limits, and
    correction behavior.
- Current contracts: `docs/architecture/current-contracts.md`
- Current ASR plan: `docs/research/2026-06-27-memex-parity-capability-plans.md`
- Current media QA: `docs/research/2026-06-26-w7-real-media-capture-qa.md`
- Reference implementation inspected clean-room:
  `https://github.com/memex-lab/memex` at `2af6b06b0ac50e62693c60760e5b7c9a41cdbd62`
- Xiaomi MiMo official docs:
  - `https://mimo.mi.com/docs/zh-CN/api/audio/Speech-Recognition`
  - `https://mimo.mi.com/docs/zh-CN/quick-start/usage-guide/audio/Speech-Recognition`
- sherpa-onnx:
  - `https://github.com/k2-fsa/sherpa-onnx`
  - `https://pub.dev/packages/sherpa_onnx`

No API keys, raw user records, local databases, backups, or real audio samples
were used in this planning note.

## Accepted Direction

1. Raw audio is saved first as an attachment with hash, byte length, duration,
   local storage ref, and source refs.
2. ASR produces `audio_transcript` derived artifacts. It must not mutate or
   replace raw audio.
3. Voice-only captures become user-visible immediately, then downstream
   Memory/card/todo/insight processing runs after transcript readiness.
4. If a user also typed text, typed text can be processed immediately and the
   transcript can trigger an idempotent reprocess/update later.
5. Local/offline ASR is the default. Remote ASR must be explicitly enabled and
   cannot silently replace local ASR.
6. Transcript correction is a separate pack/service. It writes correction
   evidence and revised transcript artifacts, but never directly writes Memory.
7. A dedicated settings surface manages local model state, preview behavior,
   provider selection, language, limits, and correction policy.

## Kimi Review Summary

Kimi CLI reviewed this plan in read-only mode. Inputs were this note and public
repository architecture docs only. No API keys, private records, local DBs,
backups, audio files, environment variables, or credentials were included.

Verdict:

- `NO_P0`
- Proceed after resolving P1 items and product-owner decisions.

P1 findings folded into this revision:

- Local `sherpa_onnx + SenseVoice` must get a minimal Android/iOS build/runtime
  spike before broad UI work.
- Model downloads need explicit source, verification, quarantine, and repair
  behavior.
- The first real-time implementation needs a clear file format. This plan now
  uses app-written WAV as the original recording artifact for streaming capture.
- Existing `.m4a` recordings from the current adapter need an explicit handling
  rule. This plan keeps them visible/source-truth and treats local conversion or
  remote retry as follow-up unless product owner pulls it into the first slice.
- MiMo ASR needs real opt-in fixture/live validation before treating response
  schema, streaming deltas, or chunk metadata as stable.
- ASR should not live as an ambiguous capture-owned subdirectory.
- ASR service ownership must align with the prior `audio.transcribe` tool
  direction. This plan makes mobile transcription the first implementation
  engine and leaves Agent Runtime tool exposure as a wrapper over that boundary.
- MiMo credentials and provider config must use platform secure storage.
- SenseVoice and VAD model licensing must be reviewed before distribution.
- This change needs decision hygiene: update/create ADR/RFC coverage and
  `docs/architecture/current-contracts.md` when product decisions are accepted.
- Remote ASR permission names and user consent need product/architecture
  confirmation.
- Derived transcript artifacts and original media backup behavior must be
  validated explicitly.
- Correction plugin shape must be chosen before implementation: Agent Pack or
  native service.

## Current Implementation Fit

WideNote already has the right storage shape:

- `RecordVoiceCaptureAdapter` saves `.m4a` files under app documents and records
  duration/hash/byte length plus `transcript_status: pending`.
- `AttachmentRecord` persists attachment metadata.
- `DerivedArtifactRecord` already supports `sourceCaptureId`,
  `sourceAttachmentId`, `artifactKind`, `body`, `sourceRefs`, generator metadata,
  confidence, sensitivity, payload, and invalidation.
- `LocalCaptureReadModelStore` already creates pending `audio_transcript`
  artifacts for voice attachments.

The missing work is not a new source model. It is:

- real ASR providers
- durable transcript status transitions
- downstream reprocess after transcript readiness
- transcript correction pack
- settings, tests, and QA

Existing `.m4a` voice recordings created before the streaming WAV path should
remain valid attachments. First-slice local ASR can mark them as requiring
conversion or remote/manual retry rather than migrating them silently.

## User Interaction

### Record Flow

1. User taps Voice.
2. App starts recording immediately after microphone permission.
3. If local model and VAD are ready, a live preview panel appears:
   - confirmed transcript text is stable
   - pending transcript text may change while calibration runs
   - preview is clearly a draft until final stop calibration completes
4. If local model is missing, unsupported, or fails during preview, recording
   continues with waveform/timer only and the transcript status is pending.
5. Stop saves the audio attachment before ASR is attempted.
6. The app shows one continuous record row/sheet with:
   - audio chip
   - duration
   - transcript status
   - retry or download CTA when needed
   - typed context if the user adds it
7. On successful ASR, the transcript becomes the primary visible text for
   voice-only records while the audio chip remains visible as the source.
8. On ASR failure, the raw audio record remains visible, exportable, retryable,
   and deletable.

### Continuity Rule

The voice capture must feel continuous:

- no duplicate records for one recording
- no invisible background mutation
- all state changes happen on the same capture id and attachment id
- timeline/detail views show the status transition from saved -> transcribing
  -> transcript ready or failed

### Settings Surface

Add `Voice & Transcription` under Settings/Privacy.

Controls:

- Local model card:
  - not downloaded
  - downloading with percent
  - verifying
  - ready
  - failed with retry
  - corrupted with repair
  - delete model
- Transcription provider:
  - local only (default)
  - local first, remote manual retry
  - remote disabled
  - remote MiMo enabled after explicit consent and provider config
- Real-time preview:
  - enabled when local model is ready
  - disabled fallback when model missing or platform stream unsupported
- Language:
  - auto, zh, en
- Limits:
  - auto-transcribe max duration
  - remote upload max chunk duration
  - Wi-Fi-only model download
- Correction:
  - correction disabled
  - suggest corrections only
  - auto-apply high-confidence term corrections, review the rest

All user-visible strings must use ARB localization and generated bindings.

## Technical Architecture

### Module Shape

Add a mobile transcription feature boundary, separate from capture media
adapters:

```text
apps/mobile/lib/features/transcription/
  transcription_service.dart
  transcription_provider.dart
  local_sensevoice_provider.dart
  mimo_asr_provider.dart
  transcription_download_manager.dart
  streaming_transcriber.dart
  transcript_correction_controller.dart
```

Reusable pure data models can move to `packages/dart/model_providers` or a
future `packages/dart/transcription` only after the interface stabilizes. The
first local provider depends on Flutter plugins, so the implementation belongs
in the mobile app boundary.

Agent Runtime alignment:

- `apps/mobile/lib/features/transcription/` is the first concrete engine because
  microphone, secure storage, platform files, and native ASR plugins are mobile
  concerns.
- A future `audio.transcribe` Agent Runtime tool should call this service through
  a narrow app-owned adapter instead of creating a second transcription engine.
- Correction can be a Pack or native service, but the choice must be made before
  Slice D to avoid duplicating permission and trace semantics.

If this durable module is added, update:

- `apps/mobile/lib/features/README.md`
- `apps/mobile/README.md`
- `docs/agent-context/project-map.md`
- `apps/mobile/lib/features/capture/README.md` to state capture records media
  only and calls the transcription feature after source material is durable

### Provider Interface

```text
AudioTranscriptionProvider
  id
  displayName
  supportsFileTranscription
  supportsStreamingPreview
  supportsRemoteUpload
  prepare()
  transcribeAttachment(attachmentRef, options)
  transcribeSamples(samples, options)
  dispose()
```

`attachmentRef` is a capture/file source ref, not an arbitrary filesystem path.
The resolver maps it to app-owned local storage only after permission checks.

### Local SenseVoice Provider

Technology:

- `sherpa_onnx` Flutter package
- SenseVoice int8 model used by Memex:
  `sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17`
- VAD: `silero_vad.onnx` bundled as an app asset
- background isolate for recognition
- provider selection:
  - iOS: CoreML
  - Android: NNAPI when available, CPU fallback
  - other platforms: CPU

First-slice constraints:

- Live recording uses `record.startStream` with PCM16, 16 kHz, mono.
- The first streaming slice stores original voice recordings as WAV, not m4a.
  The app writes a WAV file while receiving PCM stream chunks, then finalizes
  the header on stop. This keeps the attachment source file and ASR input aligned
  without an extra encoder.
- If streaming fails, fallback file recording uses `AudioEncoder.wav` where
  supported, then final ASR runs from the WAV file.
- Final calibration uses the captured PCM stream or the saved WAV file.
- Imported historical audio needs a platform converter to WAV 16 kHz mono. Do
  not block the first recording slice on broad import conversion.

### Real-Time Preview

Feasible for first slice because `record ^6.2.1` exposes `startStream`.

Preview algorithm:

1. Start PCM16 stream at 16 kHz mono.
2. Feed chunks into VAD.
3. Transcribe short segments in a background isolate.
4. Keep two text buffers:
   - confirmed: immutable after calibration
   - pending: may be replaced by calibration
5. When pending audio has enough context and at least two segments, re-transcribe
   the combined pending samples and move the result to confirmed.
6. On stop, run final full-sample calibration and replace draft preview with the
   final transcript artifact.

Fallbacks:

- model not downloaded -> no preview, transcript pending
- VAD asset missing -> no preview, final ASR only
- stream unsupported or throws -> fall back to file recording
- model isolate failure -> keep recording, show draft unavailable, retry final
  ASR after stop
- memory pressure -> disable preview for the current recording and record a
  trace

Before implementing broad UI, run a spike that proves:

- `sherpa_onnx` initializes on Android and iOS builds
- the recognizer can run in the chosen isolate/thread boundary
- WAV streaming write + final header repair produces readable audio
- the fallback `AudioEncoder.wav` path works on supported devices
- preview can be disabled without breaking raw audio save

### Download Manager

Model download must be transactional.

States:

- `not_downloaded`
- `checking`
- `downloading`
- `paused_or_interrupted`
- `verifying`
- `ready`
- `failed`
- `corrupted`
- `deleting`

Rules:

- Download into a temporary `.part` directory.
- Store a manifest with model version, source URL, expected file names, expected
  sizes and sha256 values when known, created time, and completion state.
- Mark `ready` only after model + token files exist, pass verification, and a
  lightweight recognizer init probe succeeds.
- If the app dies mid-download, next launch shows interrupted state and offers
  resume or restart.
- If HTTP range resume is unsupported, retry restarts cleanly from `.part`.
- Partial files never replace the active model directory.
- Corrupted files move to a quarantine/repair state rather than being used.
- Deleting the model disposes recognizers/isolate first, then removes files.
- Low disk, network timeout, mirror blocked, extraction failure, checksum
  mismatch, and permission/path failure are distinct error codes.

User-facing behavior:

- download can be canceled
- retry does not require app restart
- local voice recording still works without the model
- ASR waits for model readiness but raw audio save never waits

### Xiaomi MiMo ASR Provider

Official docs as of 2026-06-30:

- API: `https://api.xiaomimimo.com/v1/chat/completions`
- Compatibility shape: OpenAI-compatible chat completions
- Model: `mimo-v2.5-asr`
- Auth: `api-key` header or Bearer authorization
- Audio input: `input_audio` with Base64 audio
- Supported formats: wav and mp3
- Quick-start states Base64 string size limit: 10 MB
- `asr_options.language`: auto, zh, en
- `stream: true` returns SSE streaming output
- Current non-streaming examples return transcript text in
  `choices[0].message.content` and usage metadata including `seconds`

Implementation implications:

- Do not reuse the current Anthropic-compatible MIMO chat adapter for ASR.
- Add a dedicated `MimoAsrProvider` with audio request/response parsing.
- Because Base64 expands size, enforce encoded-size limits, not only raw file
  limits.
- For WAV 16 kHz mono, use conservative remote chunks, for example 120 seconds,
  to stay well below 10 MB after Base64.
- Stitch chunk outputs with segment metadata and source refs.
- Remote ASR requires explicit user consent and stored provider config.
- If the configured provider lacks audio capability or credentials, remote ASR
  is disabled, not used as fallback.
- MiMo API keys and provider config must live in platform secure storage
  (Keychain/Keystore-backed), not plain settings rows or test fixtures.
- Remote traces must record provider id, model, duration, chunk count, status,
  and error class, but not API key or raw audio bytes.
- Add an opt-in live validation fixture before relying on response shape. The
  adapter tests should freeze the observed non-streaming and streaming response
  schemas with credentials supplied only through dart-define or local runtime
  settings.
- If MiMo returns only full transcript text and no segment timestamps, chunk
  stitching falls back to ordered text with conservative overlap handling and
  source refs per chunk.

### Transcript Artifact

Use `DerivedArtifactRecord` first.

Artifact kind:

- `audio_transcript`

Statuses:

- `pending`
- `transcribing`
- `active`
- `failed`
- `no_speech`
- `needs_review`
- `invalidated`

Body:

- current best transcript text for `active`
- user-safe failure or pending text for non-active states

Payload:

- `transcript_status`
- `language`
- `segments`
- `provider_id`
- `provider_kind`
- `model`
- `duration_ms`
- `chunk_count`
- `confidence`
- `raw_asr_text`
- `correction_status`
- `correction_patches`
- `error_code`
- `error_message_safe`
- `source_attachment_sha256`

Source refs:

- capture ref
- file/attachment ref
- ASR event ref
- segment refs when available

Public contract work:

- Add transcript events to `packages/schemas` and fixtures before production
  use:
  - `wn.transcript.requested`
  - `wn.transcript.created`
  - `wn.transcript.failed`
  - `wn.transcript.corrected`
- Add or update event fixtures and run
  `node packages/schemas/validate_fixtures.mjs`.

Attachment payload should keep only status pointers:

- `transcript_status`
- `transcript_id`
- `duration_ms`
- `provider_kind`
- `last_error_code`

### Downstream Reprocess

Voice-only capture:

```text
raw audio saved
  -> capture visible
  -> transcript pending
  -> ASR artifact active
  -> publish transcript-ready event
  -> run default capture loop using transcript text
  -> Memory/card/todo/insight source refs include capture + file + transcript
```

Text + voice capture:

```text
typed text saved
  -> default loop may run on typed text
  -> audio transcript later becomes extra source
  -> idempotent reprocess updates derived outputs or creates source-linked
     additions without duplicating existing Memory/todos
```

Idempotency keys should include capture id, attachment id, transcript content
hash, and pack id.

### Correction Plugin

Add a transcript correction pack or native service.

Responsibilities:

- read transcript artifact text
- read accepted Memory/glossary context if permissioned
- propose corrections for names, domain terms, homophones, and near-terms
- record the exact correction process and patch list
- update transcript artifact or create a corrected transcript artifact
- emit trace/event evidence for the Memory Agent

Non-responsibilities:

- no Memory writes
- no raw audio access in first slice
- no replacing original ASR text without revision evidence
- no broad semantic rewriting or summarization

Patch shape:

```text
{
  "from": "...",
  "to": "...",
  "span": {"start": 0, "end": 0},
  "confidence": "high|medium|low",
  "reason": "term_memory|user_glossary|context_consistency|model_guess",
  "requires_review": true
}
```

Auto-apply policy:

- high-confidence exact term/name corrections can auto-apply
- medium/low confidence patches go to review
- corrections affecting meaning, numbers, dates, credentials, or medical/legal/
  financial content go to review

The correction evidence is available to Memory Agent as source-linked derived
evidence. Memory Agent decides whether to write or update Memory through the
normal Memory policy.

## Data, Permission, And Privacy

- Raw audio never leaves the device unless remote ASR is explicitly enabled for
  the item/provider.
- Remote ASR must have a visible consent boundary and trace.
- Correction can use a configured text model, but it receives transcript text
  and selected Memory/glossary context, not raw audio.
- Context Packets include transcript excerpts and attachment metadata by default,
  not raw audio bytes.
- Deleting an attachment invalidates transcript/correction artifacts.
- Editing a transcript creates a new revision/artifact state; it does not
  mutate source audio.
- External review prompts must exclude raw audio, private transcripts, backups,
  API keys, local DB contents, and credentials.

Permission proposal:

- Local ASR:
  - `attachment.read.user_selected`
  - `source.write.transcript`
- Remote ASR:
  - `attachment.read.user_selected`
  - `source.write.transcript`
  - `audio.upload.remote_asr`
  - `network.call.declared_host`
- Correction:
  - `source.read.transcript`
  - `memory.read`
  - `source.write.transcript_correction`

These names require product/architecture confirmation before schema and Pack
manifest changes.

## Risks And Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Partial model download | Broken ASR or crash | `.part` dir, manifest, verify before ready, repair state |
| Model corruption | Bad transcripts or native crash | sha256/size checks and recognizer init probe |
| Large model size | Poor first-use experience | settings card, Wi-Fi option, local recording still works |
| Native plugin size/ABI issues | Android/iOS build failures | isolate ASR dependency in one slice; Android/iOS build gates |
| Model/asset license mismatch | Distribution or compliance risk | review and document SenseVoice and VAD licenses before bundling or download |
| Real-time preview instability | Recording flow feels broken | degrade to final ASR; raw audio save independent |
| MIMO 10 MB Base64 limit | Remote failures for long audio | encode-size check and conservative chunking |
| Generic text model lacks audio support | Remote ASR unusable | dedicated ASR provider and capability gate |
| Transcript duplicates downstream outputs | Dirty Memory/todo/card state | idempotency by transcript content hash + capture refs |
| Correction over-edits meaning | Loss of source fidelity | patch evidence, review gates, no raw source mutation |
| Correction writes Memory directly | Blurred responsibilities | pack emits evidence only; Memory Agent owns Memory writes |
| Media backup gap | Source truth may not travel in `.widenote` archive | product owner decides whether this slice includes media bytes; tests must reflect the decision |
| Imported audio conversion | Local ASR fails on non-WAV inputs | first slice uses recording PCM; import conversion is separate boundary |

## Implementation Slices

### Slice A: Local ASR Foundation

- Run a native feasibility spike first: Android/iOS build, recognizer init,
  isolate/thread boundary, WAV stream writing, and fallback recording.
- Review and document SenseVoice model and VAD asset licenses before exposing
  the download or bundling assets.
- Update/create the ADR/RFC and `docs/architecture/current-contracts.md` entries
  after product-owner decisions are accepted.
- Add ASR settings page shell.
- Add model download manager with fake HTTP/file tests.
- Add local SenseVoice provider and fake provider.
- Add transcript artifact status transitions.
- Add raw-audio-first voice flow and final transcript processing.
- Add targeted unit/widget tests.

### Slice B: Real-Time Preview

Can be part of Slice A if build/test evidence stays stable.

- Add PCM stream recording path.
- Add VAD asset and streaming transcriber.
- Add confirmed/pending preview state.
- Add final calibration on stop.
- Add fallback tests for stream/model/VAD failure.

### Slice C: MiMo ASR

- Add `MimoAsrProvider`.
- Add request builder for `mimo-v2.5-asr`.
- Add encoded-size limit and chunking.
- Add provider settings and consent gate.
- Store MiMo credential/provider config in platform secure storage only.
- Add fake HTTP tests for success, streaming, 401, 429, timeout, malformed
  response, and missing transcript.
- Add live opt-in test only when credentials are provided through dart-define.
- Decide permission name and consent granularity before enabling upload.

### Slice D: Transcript Correction

- Add correction Agent Pack or native service after product-owner decision.
- Add correction evidence events/traces.
- Add patch review/auto-apply policy.
- Add tests proving no direct Memory writes.
- Add Memory Agent read path for correction evidence in a later Memory slice.

### Slice E: Backup And Delete Follow-Up

- Decide whether `.widenote` safe backup includes original media bytes.
- Decide whether existing `.m4a` voice recordings need local conversion support
  in this slice or remain source-truth attachments with unsupported-local-ASR
  status until a later media conversion slice.
- Add attachment delete/reject cleanup rules.
- Add backup/restore tests for transcript artifacts and media integrity if
  included.

## Validation Plan

### Unit Tests

- download success, cancel, interrupted resume/restart, network failure,
  checksum/size mismatch, corrupt model, delete model
- local ASR fake provider success, no speech, model missing, model init failure,
  stream unavailable, VAD unavailable
- MiMo request body uses `mimo-v2.5-asr`, `input_audio`, language option, and
  never logs API key or raw audio
- MiMo credentials/provider config are stored through the secure-storage
  boundary, not plain settings persistence
- MiMo encoded-size limit, chunking, 401, 429, timeout, server error, malformed
  JSON, no transcript text
- transcript artifact source refs, content hash, status transitions,
  invalidation on attachment deletion
- transcript artifact and attachment status update transactionality
- WAV streaming writer finalizes a readable file and preserves sha256/byte
  length/duration metadata
- existing `.m4a` voice attachments remain source-truth and route to explicit
  unsupported/conversion-needed status when local WAV transcription is required
- downstream idempotency for transcript-ready reprocess
- correction patch parser, Unicode spans, overlapping patches, invalid spans,
  auto-apply threshold, review routing, no Memory write

### Widget Tests

- settings page local model card states
- download progress, failure, retry, delete
- recording starts without model and still saves raw audio
- recording with model shows live preview and final transcript
- final transcript becomes primary voice record text with audio source chip
- failed transcript shows retry and keeps raw audio visible
- remote provider consent and disabled state when no credential/capability
- correction suggestions and review UI

### Package / Schema Tests

- public event/schema updates for transcript events
- pack validator for file-context and correction packs
- Context Packet tests for transcript excerpts, attachment metadata, and no raw
  audio bytes
- local DB backup/export tests for transcript artifacts
- `.widenote` backup/restore media-byte tests if product owner chooses media
  backup in this slice
- docs validation for ADR/RFC, current contracts, project map, and module README
  updates when the implementation changes the accepted target state

### Mobile QA

- Android emulator: permission deny, start, live preview, stop, transcript ready,
  retry failed ASR, settings download failure
- iOS simulator build: ASR plugin build and settings UI
- Real device spot check before release: microphone + native ASR plugin because
  simulator microphone/native accelerator behavior can differ
- Performance spot check: CPU/memory while previewing on one lower-end Android
  device class when available; otherwise record the skipped risk.

### External Review

Completed:

- Kimi returned `NO_P0` in the initial and final planning reviews.
- P1 findings from both reviews were folded into this revision.

Repeat Kimi review after the first implementation diff and validation summary,
again with no secrets, private records, DBs, backups, raw audio, or credentials.

## Open Decisions For Product Owner

1. Should Slice A and Slice B ship together if the streaming path passes tests,
   or should real-time preview remain behind a dev flag for one iteration?
2. Should `.widenote` safe backup include original audio/media bytes in this
   same ASR slice, or be a follow-up slice?
3. Should remote MiMo ASR be available as manual retry only, or as an opt-in
   automatic fallback after local ASR failure?
4. What should the default auto-transcribe duration be for local ASR? Proposed:
   5 minutes local, 120 seconds per remote chunk.
5. Should high-confidence transcript corrections auto-apply by default, or
   should the first release be suggestions-only?
6. Should transcript correction be implemented as an Agent Pack first, or as a
   native service with a later Pack wrapper?
7. Should the first voice recording source format be WAV for implementation
   simplicity, accepting larger files than m4a?
8. Which remote ASR permission vocabulary should be accepted:
   `audio.upload.remote_asr` + `network.call.declared_host`, or another name?
9. Should existing `.m4a` voice recordings get local conversion in the first
   slice, or remain source-truth attachments with unsupported-local-ASR/manual
   retry status until a later conversion slice?
10. Should `audio.transcribe` Agent Runtime exposure wait until after the mobile
    transcription engine lands, using it as a wrapper, or ship in the same
    implementation slice?

## Final Product Owner Decisions

Date: 2026-07-01

These decisions supersede the open-decision list above for the first
implementation slice:

- Real-time transcript preview ships with the first voice transcription slice
  when the platform stream, local model, and tests are stable; raw audio save
  and final ASR after stop remain the fallback path.
- New first-slice recordings use WAV as the source audio format.
- Safe `.widenote` backup includes original audio/media bytes in this slice,
  with provider secrets still excluded.
- Existing `.m4a` recordings are not a compatibility target for first-slice
  local ASR. They remain source-truth attachments for a later conversion slice.
- MiMo or another declared-host remote ASR provider is an automatic fallback
  after local ASR failure once the user has explicitly opted in; manual retry is
  also available.
- Transcript correction is implemented through an Agent Pack first.
- High-confidence exact term or name transcript corrections auto-apply by
  default as source-linked correction revisions; lower confidence or
  meaning-sensitive changes route to review.
- The accepted remote ASR permission names are `audio.upload.remote_asr` and
  `network.call.declared_host`.
- `audio.transcribe` Agent Runtime exposure waits until the mobile
  transcription engine lands, then wraps that engine through a narrow adapter.
