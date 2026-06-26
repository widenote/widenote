# Capture Media

## Purpose

Owns capture input contracts and attachment safety for photo, gallery, and
voice capture.

## Ownership Boundary

This module models raw attachment metadata, adapter contracts, deterministic
fake adapters, platform adapters, and the thin asset safety guard used by the
capture UI. Platform adapters may request camera, photo-library, and microphone
permissions through their underlying Flutter plugins, but they only return local
metadata and file references. They do not own persistence schemas, OCR/ASR, or
Agent Pack policy.

Failure states are part of the public boundary: cancelled, permission denied,
unavailable, and platform error results must not create attachments, captures,
events, or tasks.

## Dependencies

- Dart async/core/io libraries
- `image_picker`
- `record`
- `path_provider`
- `crypto`
- The capture application layer consumes this module through providers

## Public Surface

- `RawCaptureAsset`
- `CaptureAttachment`
- `AssetSafetyGuard`
- `PhotoCaptureAdapter`
- `VoiceCaptureAdapter`
- `ImagePickerPhotoCaptureAdapter`
- `RecordVoiceCaptureAdapter`
- fake adapter implementations for deterministic tests

## Generated Artifacts

None.
