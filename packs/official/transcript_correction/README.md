# Transcript Correction Pack

## Purpose

The Transcript Correction Pack improves source-linked audio transcript
artifacts after ASR creates them.

It is an additive official Pack. Raw audio remains source truth, the original
ASR text remains revision evidence, and Memory writes still go through the
normal Memory policy.

## Ownership Boundary

Owns transcript correction evidence and the short-term inline correction
revision semantics.

It must not:

- read raw audio bytes
- overwrite raw captures or source attachments
- mutate accepted Memory
- write private mobile tables directly
- perform remote ASR or upload audio
- rewrite meaning, dates, numbers, credentials, or sensitive domain content
  without review

## Public Surface

| Surface | Source |
| --- | --- |
| Agent Pack manifest | `manifest.json` |

The manifest declares:

- Permission requests: `model.complete`, `source.read.transcript`,
  `memory.read`, `source.write.transcript_correction`
- Subscription: `wn.transcript.created`
- Native agent: `agent.transcript_correction`
- Prompt reference: `transcript.correction.v1`
- Additive slot: `transcript.correction`
- Output event: `wn.transcript.corrected`

## Runtime Behavior

For each created transcript, the pack reads the transcript text plus
permissioned Memory or glossary context. It proposes exact patches for names,
domain terms, homophones, and near-terms.

High-confidence exact term or name corrections may auto-apply by recording
source-linked correction fields on the `audio_transcript` derived artifact
payload and emitting `wn.transcript.corrected`. The short-term design does not
add a dedicated `transcript_correction_revisions` table; add one only when
audit, undo, or historical review requirements are accepted. Medium or low
confidence corrections, and corrections that affect meaning, numbers, dates,
credentials, medical, legal, or financial content, must route to review.

## Generated Artifacts

No generated artifacts exist yet.

Generated pack indexes or docs must point back to `manifest.json` when
introduced.

## Related Context

- `docs/decisions/0012-accept-voice-transcription-and-correction-boundaries.md`
- `docs/research/2026-06-30-voice-input-asr-correction-plan.md`
- `packages/schemas/src/transcript/transcript.schema.json`
- `packages/schemas/src/agent_pack/agent_pack_manifest.schema.json`
