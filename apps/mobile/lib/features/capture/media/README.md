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

Adapters and the asset safety guard can attach safe derived-artifact view
metadata for UI status display. That metadata is limited to artifact kind,
pending/ready/failed/blocked/needs-review status, safe excerpt, reason, and a
source label. It must not include raw media bytes, absolute storage paths, or
enough information to reconstruct the source file. Blocked and needs-review
states must be supplied by adapter/tool/platform/user state such as safety
labels, MIME support, permissions, tool result status, or explicit review
markers; this module must not classify user content with local keyword scans.

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
