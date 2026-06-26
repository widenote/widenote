# W7 Real Media Capture Permissions QA

Status: W7-C worker verified, code-level GO
Date: 2026-06-26
Scope: phase-one text, camera, gallery, and voice capture permission boundary

## Acceptance Standard

- Text capture remains usable without any media permission.
- Camera, gallery, and voice capture use real platform adapters where available
  and deterministic fake adapters in tests.
- Cancelled, denied, revoked/unavailable, and platform-error paths do not create
  phantom attachments, captures, events, runtime tasks, or source refs.
- Successful media capture stores source material on the local filesystem and
  persists metadata, hash, byte length, local storage reference, and source refs.
  Large media bytes are not stored in SQLite.
- Blocked attachments hide raw preview text and cannot be submitted.
- Review-needed attachments must be explicitly accepted before submit.
- Android and iOS permission declarations exist for phase-one camera,
  microphone, and selected photo access.

## Implemented Boundary

- `ImagePickerPhotoCaptureAdapter` wraps `image_picker` for camera and gallery.
  It requests selected media with `requestFullMetadata: false`, stores the file
  under app documents, records SHA-256 and byte length, and marks the item as
  user selected.
- `RecordVoiceCaptureAdapter` wraps `record` for microphone capture. It checks
  microphone permission before start, stores `.m4a` recordings under app
  documents, records SHA-256, byte length, duration, and transcript-pending
  metadata, and cleans empty or failed output files.
- `CaptureInputController` shows cancelled/denied/unavailable/platform errors
  without creating attachments.
- `CaptureOrchestrator.processCapture` rejects non-ready attachments before
  publishing `wn.capture.created`, so direct calls cannot bypass the UI block.
- `AssetSafetyGuard` hides blocked previews and keeps raw preview text only in
  metadata for local review/debug paths.

## Explicit Non-Goals

- No background or continuous capture.
- No live ASR, OCR, image understanding, or batch import.
- No share extension integration beyond the deterministic fake import sample.
- No broad filesystem or media-library permission. Gallery capture is selected
  media first.

## User Manual Checks

1. Open the app and submit a text-only record.
2. Tap Camera, deny permission, confirm an error appears and no record is saved.
3. Tap Camera, grant permission, take or cancel a photo; success should create
   one attachment, cancel should create none.
4. Tap Gallery, cancel the picker, confirm no attachment/record appears.
5. Tap Gallery, select one image, confirm it appears as a local attachment.
6. Tap Voice, deny microphone permission, confirm no recording row appears.
7. Tap Voice, start recording, try Save, confirm submit is blocked while
   recording.
8. Stop recording, confirm a voice attachment appears and can be submitted.
9. Trigger a review-needed or blocked synthetic media item in tests/dev mode:
   review-needed blocks submit until accepted, blocked media must be removed.
10. Restart the app and confirm saved media records retain metadata/source refs.

## Automated Verification

Passed:

```sh
cd apps/mobile && dart format lib/features/capture/media/platform_capture_media.dart lib/features/capture/application/capture_orchestrator.dart test/capture_media_test.dart test/capture_orchestrator_test.dart test/capture_console_widget_test.dart
cd apps/mobile && flutter test test/capture_media_test.dart test/capture_orchestrator_test.dart test/capture_console_widget_test.dart
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test test/capture_media_test.dart test/capture_orchestrator_test.dart test/capture_console_widget_test.dart test/android_manifest_test.dart test/ios_permission_config_test.dart
cd apps/mobile && flutter test
git diff --check
cd apps/mobile && flutter build apk --debug --flavor dev
cd apps/mobile && flutter build ios --simulator --debug --flavor dev
```

Results:

- W7-C targeted suite: 40 passed.
- Full mobile suite: 146 passed, 2 skipped live-provider tests.
- Android dev debug APK built at
  `build/app/outputs/flutter-apk/app-dev-debug.apk`.
- iOS dev simulator app built at `build/ios/iphonesimulator/Runner.app`.

Coverage:

- photo camera/gallery success, cancel, denied/restricted, unavailable, and
  platform error
- image picker local file copy, hash, storage ref, selected-media metadata, and
  no full metadata request
- voice start/stop/cancel/denied/stop-error
- voice local file copy, hash, duration, and empty-output cleanup
- blocked preview hidden
- review-needed attachment blocks submit until accepted
- blocked/review attachment direct orchestrator calls rejected before event
  publication
- Android/iOS permission declaration tests are part of final validation

## Kimi Review

Input stayed redacted:

- file list
- diff summary
- acceptance criteria
- test command summaries
- no real photos, audio, local database, backup artifact, API key, token, or
  private user record

Result: `NO_BLOCKERS` for W7-C code-level acceptance.

Kimi follow-up risks:

- Decide whether `capture_media/` should be included in or excluded from
  platform/cloud backup. Phase one currently keeps user source media in app
  documents so normal device backup may preserve it.
- Define attachment delete/reject cleanup to avoid orphaned files.
- Decide future encryption-at-rest strategy for raw media if the product
  requires encrypted local notes/media.
- Real device/simulator permission grant, denial, and revocation remain manual
  QA before release.

## Remaining Risk

- Simulator permission grant/deny/revoke should still be run as a manual device
  QA pass.
- Gallery limited/partial-library behavior is treated as selected-media access
  in phase one; broader media-library management is deferred.
- Real device audio/photo codecs can vary by OS version; adapter tests cover
  metadata and boundary behavior, not every codec.
