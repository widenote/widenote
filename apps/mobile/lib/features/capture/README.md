# Capture Feature

## Purpose

Owns the home/records tab, Quick Capture UI, app-local capture/card/insight
read models, fake-adapter media/share/voice capture inputs, and Memory review
surface.

## Ownership Boundary

This feature presents record, card, insight, Memory, todo, and trace feedback
from the local runtime. It must not become the durable runtime, policy,
persistence, or schema source of truth.

## Dependencies

- Flutter Material
- `flutter_riverpod`
- `packages/dart/agent_runtime`
- `packages/dart/cards`
- `packages/dart/memory`
- `media/` fake adapter contracts and asset safety guard

## Public Surface

- `presentation/HomePage`
- `application/captureControllerProvider`
- `application/captureInputControllerProvider`
- `application/captureOrchestratorProvider`
- `application/LocalDbCaptureKnowledgeSink`
- `media/CaptureAttachment`
- `media/AssetSafetyGuard`
- lightweight domain view models in `domain/`

## Generated Artifacts

None.
