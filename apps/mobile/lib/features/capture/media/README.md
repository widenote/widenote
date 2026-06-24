# Capture Media

## Purpose

Owns fake-adapter-first capture inputs for photo, voice transcript, and
share/import samples.

## Ownership Boundary

This module models raw attachment metadata, adapter contracts, fake adapters,
and the thin asset safety guard used by the capture UI. It does not request real
camera, microphone, file-picker, or share-extension permissions, and it does not
own persistence schemas.

## Dependencies

- Dart async/core libraries only
- The capture application layer consumes this module through providers

## Public Surface

- `RawCaptureAsset`
- `CaptureAttachment`
- `AssetSafetyGuard`
- `PhotoCaptureAdapter`
- `VoiceCaptureAdapter`
- `ShareImportAdapter`
- fake adapter implementations for deterministic tests

## Generated Artifacts

None.
