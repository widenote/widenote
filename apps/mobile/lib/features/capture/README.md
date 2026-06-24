# Capture Feature

## Purpose

Owns the home/records tab, Capture Console UI, app-local capture/card/insight
read models, fake-adapter media/share/voice capture inputs, and Memory review
surface.

## Ownership Boundary

This feature presents record, card, insight, Memory, todo, and trace feedback
from the local runtime. It owns capture interaction state such as text, voice
draft, and import mode selection, but it must not become the durable runtime,
policy, persistence, or schema source of truth.

Voice mode is currently a transcript-draft path backed by fake adapters. It does
not request microphone permission, start recording, stream audio, or claim live
transcription. Real ASR/recorder behavior belongs behind explicit platform
permissions and future Agent Pack capability boundaries.

## Dependencies

- Flutter Material
- `flutter_riverpod`
- `packages/dart/agent_runtime`
- `packages/dart/cards`
- `packages/dart/memory`
- `media/` fake adapter contracts and asset safety guard

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
- lightweight domain view models in `domain/`

## Generated Artifacts

None.
