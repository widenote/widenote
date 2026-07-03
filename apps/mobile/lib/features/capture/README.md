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

The capture sheet may show attachment derived-artifact status rows for pending,
ready, failed, blocked, and needs-review states. These rows are presentation
only: original raw attachments remain source truth, and the UI must render only
safe previews, artifact excerpts, and source labels. It must not render raw file
paths, raw media bytes, raw unsafe preview text, or infer blocked/review states
from local content keyword scanning. Blocked and review states come from adapter,
tool, platform permission, or explicit user-review state.

Capture implements current contracts from
`docs/architecture/current-contracts.md`: original records remain source truth,
AI outputs are derived and source-linked, quick capture persists immediately
then queues full model/runtime processing in the background, and low-risk
source-linked non-conflicting Memory should flow through the Memory policy as
auto-accepted by default. Review is reserved for low-confidence, conflicting,
sensitive, credential-like, or policy-unclear Memory. Background processing
state must not disable new capture input; failed records expose per-record
retry, while pending records do not expose edit/delete in this slice. Runtime
task claim, retry due time, dependency blocking, and concurrency slots are
durable local-db behavior; the controller is only a foreground drain and UI
state bridge. Workmanager/BGTask scheduling may trigger short drains for
already-saved ready records, but it does not take over recording, foreground
location, or voice ASR.

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
- `application/captureReplayServiceProvider`
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
- `docs/decisions/0017-accept-continuous-capture-background-processing.md`
- `docs/decisions/0018-accept-durable-agent-work-queue.md`
- `docs/architecture/engineering-rules.md`
