# Capture Feature

## Purpose

Owns the home/records tab, Capture Console UI, visible capture feedback,
source-linked home-row navigation, app-local capture/card/insight read models,
text/photo/gallery/voice capture inputs, and Memory review surface.

## Ownership Boundary

This feature presents record, card, insight, Memory, todo, and trace feedback
from the local runtime. It owns capture interaction state such as text, voice
draft, and import mode selection, but it must not become the durable runtime,
policy, persistence, or schema source of truth.

Text capture remains local and immediate. Photo, gallery, and voice capture go
through narrow platform adapters that either return local attachment metadata or
surface cancelled/denied/unavailable errors without creating phantom captures,
events, or tasks. Deterministic fake adapters remain the default test fallback.
Real ASR/OCR/image understanding is outside this module; media is saved as local
source material with metadata, hashes, and source refs before any AI processing.

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
