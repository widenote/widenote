---
id: ADR-0012
title: Accept voice transcription and correction boundaries
status: accepted
date: 2026-07-01
owners: [core, mobile, agents, privacy]
tags: [voice, asr, transcript, agent-pack, backup, privacy]
supersedes: []
superseded_by:
sources:
  - ../research/2026-06-30-voice-input-asr-correction-plan.md
  - ../rfcs/agent-pack-schema.md
  - ../rfcs/agent-runtime-capability-boundaries.md
  - ./0009-use-object-truth-and-context-packets.md
  - ./0011-adopt-agent-runtime-roadmap.md
---

# Accept Voice Transcription and Correction Boundaries

## Context

WideNote is adding real voice input, local ASR, optional remote ASR fallback,
and transcript correction. This crosses source-truth, backup, permission,
runtime, Agent Pack, schema, and default UX boundaries, so the product choices
must be recorded before mobile implementation depends on them.

The existing contract is that original user records and attachments remain
source truth, while ASR/OCR/vision/model outputs are derived artifacts with
source refs. The new voice slice keeps that rule but makes audio and transcript
behavior explicit.

## Decision

Ship real-time transcript preview in the first voice transcription slice when
the platform stream, local model, and tests are stable. If preview cannot run,
the recording flow still saves raw audio and falls back to final ASR after stop.

New first-slice voice recordings are saved as WAV source files. Existing `.m4a`
recordings are not a compatibility target for first-slice local ASR; they
remain source-truth attachments and can be handled by a later conversion slice.

Safe `.widenote` backup includes original audio/media bytes for this slice,
with per-entry checksums and without provider API keys or credentials.
Encrypted full backup remains the future path for secret-bearing portability.

Local/offline ASR is the default. Remote ASR, including MiMo or another
declared-host provider, is available only after explicit opt-in. After opt-in,
remote ASR is the automatic fallback when local ASR fails, and the user also
gets a manual retry entrypoint. Remote ASR uses the accepted permission names
`audio.upload.remote_asr` and `network.call.declared_host`.

Transcripts are `audio_transcript` derived artifacts. Transcript readiness,
failure, and correction use public transcript events under `packages/schemas`.
Downstream Memory, cards, todos, insights, and chat answers must cite capture,
attachment, transcript, and event refs when they depend on transcript text.

Transcript correction is an Agent Pack capability. The official correction pack
reads transcript text plus permissioned Memory or glossary context, emits
correction evidence, and writes source-linked transcript correction revisions.
It does not read raw audio and does not write Memory directly.

High-confidence exact term or name corrections auto-apply by default as
correction revisions. Medium or low confidence patches, and patches affecting
meaning, numbers, dates, credentials, medical, legal, or financial content, go
to review.

The `audio.transcribe` Agent Runtime tool is deferred until after the mobile
transcription engine lands. When exposed, it should be a narrow wrapper over
the mobile-owned transcription engine rather than a second ASR implementation.

## Considered Options

- Ship final-only ASR first and keep real-time preview behind a later flag.
- Save new recordings as compressed `.m4a` and transcode for ASR.
- Keep backup metadata-only for media and add media bytes later.
- Make remote ASR manual retry only.
- Implement correction as a native service before exposing it as an Agent Pack.
- Ship `audio.transcribe` as a runtime tool in the same implementation slice.

## Rationale

Real-time preview makes voice capture feel continuous, while the raw-audio-first
fallback preserves reliability when ASR assets or platform streaming fail.

WAV makes the first ASR path simpler and keeps the saved source file aligned
with local ASR input. Deferring `.m4a` conversion avoids turning compatibility
work into a blocker for first usable voice transcription.

Including media bytes in `.widenote` backup preserves source truth in the
artifact users can already open and restore. The provider credential boundary
for the backup artifact follows ADR-0013.

Automatic remote fallback after explicit opt-in gives users recovery from local
ASR failure without silently exporting audio. The accepted permission vocabulary
keeps remote upload and host access reviewable and revocable.

Using an Agent Pack for correction keeps the responsibility inspectable through
manifest, permission, event, and trace contracts. It also prevents correction
logic from bypassing Memory policy.

## Consequences

- Schema fixtures must cover transcript requested, created, failed, and
  corrected events before production code emits them.
- The correction pack must stay additive and source-linked; it cannot replace
  raw audio, original transcript evidence, or Memory policy.
- Backup tests must cover media-byte integrity for `.widenote` backup in the
  implementation slice.
- Remote ASR needs explicit consent, host declaration, trace redaction, and
  credentials stored only through the approved secure-storage boundary.
- Mobile code owns the first transcription engine. Runtime and Pack surfaces
  should call that engine through narrow adapters instead of duplicating ASR.

## Follow-ups

- Implement the mobile transcription engine, real-time preview degradation, and
  WAV recording path without touching raw source truth.
- Add mobile unit/widget tests and platform QA for voice capture, preview,
  transcript retry, correction review, and backup media restore.
- Add runtime/native pack handler tests when `pack.transcript_correction`
  becomes executable in mobile.
- Revisit `.m4a` conversion only after the first WAV/local-ASR path is stable.
