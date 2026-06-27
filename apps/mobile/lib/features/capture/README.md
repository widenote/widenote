# Capture Feature

## Purpose

Owns the home/records tab, Capture Console UI, visible capture feedback,
source-linked home-row navigation, app-local capture/card/insight read models,
text/photo/gallery/voice capture inputs, persistent text drafts, and Memory
review surface.

## Ownership Boundary

This feature presents record, card, insight, Memory, todo, and trace feedback
from the local runtime. It owns capture interaction state such as text drafts,
voice draft, and import mode selection, but it must not become the durable
runtime, policy, persistence, or schema source of truth.

The active text draft is app-local UI state stored outside public schemas and
backup contracts. It restores into the Capture Console after rebuild/relaunch
and clears after explicit submit.

Text capture remains local and immediate. Photo, gallery, and voice capture go
through narrow platform adapters that either return local attachment metadata or
surface cancelled/denied/unavailable errors without creating phantom captures,
events, or tasks. Deterministic fake adapters remain test-only substitutes.
Real ASR/OCR/image understanding is outside this module; media is saved as local
source material with metadata, hashes, and source refs before any AI processing.
The quick-capture text field disables autocorrect, suggestions, smart dashes,
and smart quotes so platform input helpers do not rewrite literal raw records.

Capture implements current contracts from
`docs/architecture/current-contracts.md`: original records remain source truth,
AI outputs are derived and source-linked, and low-risk source-linked
non-conflicting Memory should flow through the Memory policy as auto-accepted by
default. Review is reserved for low-confidence, conflicting, sensitive,
credential-like, or policy-unclear Memory.

## Dependencies

- Flutter Material
- `flutter_riverpod`
- `packages/dart/agent_runtime`
- `packages/dart/cards`
- `packages/dart/memory`
- `media/` adapter contracts, platform adapters, fake test adapters, and asset
  safety guard

## Public Surface

- `presentation/HomePage`
- `presentation/CaptureConsole`
- `application/CaptureMode`
- `application/captureControllerProvider`
- `application/captureDraftRepositoryProvider`
- `application/captureInputControllerProvider`
- `application/captureOrchestratorProvider`
- `application/LocalDbCaptureKnowledgeSink`
- `media/CaptureAttachment`
- `media/AssetSafetyGuard`
- `media/ImagePickerPhotoCaptureAdapter`
- `media/RecordVoiceCaptureAdapter`
- lightweight domain view models in `domain/`

## Generated Artifacts

None.

## Related Context

- `docs/architecture/current-contracts.md`
- `docs/rfcs/memory-model.md`
- `docs/decisions/0005-use-memory-first-instead-of-pkm-core.md`
- `docs/decisions/0009-use-object-truth-and-context-packets.md`
- `docs/architecture/engineering-rules.md`
