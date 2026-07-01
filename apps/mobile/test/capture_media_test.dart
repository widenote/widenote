import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:widenote_mobile/features/capture/application/capture_input_controller.dart';
import 'package:widenote_mobile/features/capture/media/capture_media.dart';
import 'package:widenote_mobile/features/capture/media/platform_capture_media.dart';

void main() {
  test('capture mode switching does not call media adapters', () async {
    final photo = _CountingPhotoAdapter();
    final voice = _CountingVoiceAdapter();
    final container = ProviderContainer(
      overrides: [
        photoCaptureAdapterProvider.overrideWithValue(photo),
        voiceCaptureAdapterProvider.overrideWithValue(voice),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(captureInputControllerProvider.notifier);
    controller
      ..setMode(CaptureMode.voice)
      ..setMode(CaptureMode.media)
      ..setMode(CaptureMode.text);

    final state = container.read(captureInputControllerProvider);
    expect(state.mode, CaptureMode.text);
    expect(state.attachments, isEmpty);
    expect(photo.cameraCalls, 0);
    expect(photo.galleryCalls, 0);
    expect(voice.startCalls, 0);

    await controller.startVoiceRecording();

    expect(voice.startCalls, 1);
    expect(photo.cameraCalls, 0);
    expect(photo.galleryCalls, 0);
  });

  test('fake camera adapter creates safe attachment metadata', () async {
    final raw = await FakePhotoCaptureAdapter(
      now: () => DateTime.utc(2026, 6, 24, 1),
    ).captureFromCamera();
    final attachment = const AssetSafetyGuard().buildAttachment(raw);
    final payload = attachment.toEventPayload();
    final metadata = payload['raw_metadata']! as Map;
    final adapterMetadata = metadata['adapter_metadata']! as Map;

    expect(attachment.state, CaptureAttachmentState.ready);
    expect(attachment.previewText, contains('Camera photo'));
    expect(
      attachment.derivedArtifacts.map((artifact) => artifact.status),
      <AttachmentDerivedArtifactStatus>[
        AttachmentDerivedArtifactStatus.ready,
        AttachmentDerivedArtifactStatus.pending,
      ],
    );
    expect(
      attachment.derivedArtifacts.map((artifact) => artifact.sourceLabel),
      everyElement(startsWith('source: capture_attachment:')),
    );
    expect(payload['kind'], 'photo');
    expect(payload['source_ref'], isA<Map<String, Object?>>());
    expect(payload['derived_artifacts'], isA<List<Object?>>());
    expect(metadata['mime_type'], 'image/jpeg');
    expect(adapterMetadata['source'], 'camera');
    expect(adapterMetadata['sha256'], 'fake-camera-photo-sha256');
  });

  test('fake gallery adapter preserves gallery source metadata', () async {
    final raw = await FakePhotoCaptureAdapter(
      now: () => DateTime.utc(2026, 6, 24, 1, 1),
    ).pickFromGallery();
    final attachment = const AssetSafetyGuard().buildAttachment(raw);
    final payload = attachment.toEventPayload();
    final adapterMetadata =
        ((payload['raw_metadata']! as Map)['adapter_metadata']! as Map);

    expect(attachment.state, CaptureAttachmentState.ready);
    expect(attachment.previewText, contains('Gallery photo'));
    expect(adapterMetadata['source'], 'gallery');
    expect(adapterMetadata['sha256'], 'fake-gallery-photo-sha256');
  });

  test('dangerous fake photo is blocked and hides raw preview', () async {
    final raw = await FakePhotoCaptureAdapter(
      mode: FakePhotoMode.dangerous,
      now: () => DateTime.utc(2026, 6, 24, 2),
    ).captureFromCamera();
    final attachment = const AssetSafetyGuard().buildAttachment(raw);
    final payload = attachment.toEventPayload();

    expect(attachment.state, CaptureAttachmentState.blocked);
    expect(attachment.canRenderPreview, isFalse);
    expect(attachment.previewText, isNot(contains('DANGEROUS')));
    expect(
      attachment.derivedArtifacts.single.status,
      AttachmentDerivedArtifactStatus.blocked,
    );
    expect(
      attachment.derivedArtifacts.single.excerpt,
      isNot(contains('DANGEROUS')),
    );
    expect(payload['preview_text'], 'preview_hidden');
    expect(
      ((payload['raw_metadata']! as Map)['adapter_metadata']!
          as Map)['raw_preview_text'],
      contains('DANGEROUS'),
    );
  });

  test(
    'derived artifact states come from adapter metadata, not preview words',
    () {
      final raw = RawCaptureAsset(
        id: 'metadata-status-photo',
        kind: CaptureAssetKind.photo,
        displayName: 'metadata-status.jpg',
        mimeType: 'image/jpeg',
        sourceUri: '/Users/private/raw/metadata-status.jpg',
        createdAt: DateTime.utc(2026, 6, 29, 1),
        previewText:
            'This safe preview says blocked and review as plain words.',
        rawMetadata: const <String, Object?>{
          'vision_status': 'failed',
          'ocr_status': 'needs_review',
        },
      );

      final attachment = const AssetSafetyGuard().buildAttachment(raw);

      expect(attachment.state, CaptureAttachmentState.ready);
      expect(
        attachment.derivedArtifacts.map((artifact) => artifact.status),
        <AttachmentDerivedArtifactStatus>[
          AttachmentDerivedArtifactStatus.failed,
          AttachmentDerivedArtifactStatus.needsReview,
        ],
      );
      expect(
        attachment.derivedArtifacts.map((artifact) => artifact.excerpt),
        everyElement(isNot(contains('/Users/private/raw'))),
      );
    },
  );

  test('unsupported media is blocked by MIME type', () async {
    final raw = await FakePhotoCaptureAdapter(
      mode: FakePhotoMode.unsupported,
      now: () => DateTime.utc(2026, 6, 24, 3),
    ).captureFromCamera();
    final attachment = const AssetSafetyGuard().buildAttachment(raw);

    expect(attachment.state, CaptureAttachmentState.blocked);
    expect(attachment.reviewReason, 'unsupported_mime_type:image/x-camera-raw');
  });

  test(
    'camera cancel, denied, and error are visible without attachments',
    () async {
      for (final entry in <FakePhotoMode, String>{
        FakePhotoMode.cancelled: 'Camera capture cancelled.',
        FakePhotoMode.denied: 'Camera permission denied.',
        FakePhotoMode.error: 'Camera capture failed.',
      }.entries) {
        final container = ProviderContainer(
          overrides: [
            photoCaptureAdapterProvider.overrideWithValue(
              FakePhotoCaptureAdapter(mode: entry.key),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(captureInputControllerProvider.notifier)
            .addCameraPhoto();

        final state = container.read(captureInputControllerProvider);
        expect(state.attachments, isEmpty);
        expect(state.errorMessage, entry.value);
      }
    },
  );

  test(
    'gallery cancel, denied, and error are visible without attachments',
    () async {
      for (final entry in <FakePhotoMode, String>{
        FakePhotoMode.cancelled: 'Gallery selection cancelled.',
        FakePhotoMode.denied: 'Photo library permission denied.',
        FakePhotoMode.error: 'Gallery selection failed.',
      }.entries) {
        final container = ProviderContainer(
          overrides: [
            photoCaptureAdapterProvider.overrideWithValue(
              FakePhotoCaptureAdapter(mode: entry.key),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(captureInputControllerProvider.notifier)
            .addGalleryPhoto();

        final state = container.read(captureInputControllerProvider);
        expect(state.attachments, isEmpty);
        expect(state.errorMessage, entry.value);
      }
    },
  );

  test(
    'voice recording start and stop creates ready raw audio attachment',
    () async {
      final container = ProviderContainer(
        overrides: [
          voiceCaptureAdapterProvider.overrideWithValue(
            FakeVoiceCaptureAdapter(now: () => DateTime.utc(2026, 6, 24, 4)),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        captureInputControllerProvider.notifier,
      );
      await controller.startVoiceRecording();

      final recordingState = container.read(captureInputControllerProvider);
      expect(recordingState.isRecordingVoice, isTrue);
      expect(recordingState.canSubmit, isFalse);

      await controller.stopVoiceRecording();

      final stoppedState = container.read(captureInputControllerProvider);
      final attachment = stoppedState.attachments.single;
      final metadata = attachment.rawMetadata['adapter_metadata']! as Map;
      expect(stoppedState.isRecordingVoice, isFalse);
      expect(attachment.kind, CaptureAssetKind.voice);
      expect(attachment.state, CaptureAttachmentState.ready);
      expect(stoppedState.canSubmit, isTrue);
      expect(metadata['source'], 'microphone');
      expect(metadata['sha256'], 'fake-voice-sha256');
      expect(metadata['transcript_status'], 'pending');
    },
  );

  test('voice denied and user cancel do not create attachments', () async {
    final denied = ProviderContainer(
      overrides: [
        voiceCaptureAdapterProvider.overrideWithValue(
          const FakeVoiceCaptureAdapter(mode: FakeVoiceMode.denied),
        ),
      ],
    );
    addTearDown(denied.dispose);

    await denied
        .read(captureInputControllerProvider.notifier)
        .startVoiceRecording();

    var state = denied.read(captureInputControllerProvider);
    expect(state.attachments, isEmpty);
    expect(state.isRecordingVoice, isFalse);
    expect(state.errorMessage, 'Microphone permission denied.');

    final cancelled = ProviderContainer(
      overrides: [
        voiceCaptureAdapterProvider.overrideWithValue(
          const FakeVoiceCaptureAdapter(),
        ),
      ],
    );
    addTearDown(cancelled.dispose);

    final controller = cancelled.read(captureInputControllerProvider.notifier);
    await controller.startVoiceRecording();
    await controller.cancelVoiceRecording();

    state = cancelled.read(captureInputControllerProvider);
    expect(state.attachments, isEmpty);
    expect(state.isRecordingVoice, isFalse);
    expect(state.errorMessage, 'Voice recording cancelled.');

    final stopError = ProviderContainer(
      overrides: [
        voiceCaptureAdapterProvider.overrideWithValue(
          const FakeVoiceCaptureAdapter(mode: FakeVoiceMode.stopError),
        ),
      ],
    );
    addTearDown(stopError.dispose);

    final stopErrorController = stopError.read(
      captureInputControllerProvider.notifier,
    );
    await stopErrorController.startVoiceRecording();
    await stopErrorController.stopVoiceRecording();

    state = stopError.read(captureInputControllerProvider);
    expect(state.attachments, isEmpty);
    expect(state.isRecordingVoice, isFalse);
    expect(state.errorMessage, 'Voice recording failed.');
  });

  test(
    'file store copies media and preserves hash and local source metadata',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'widenote-media-test-',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final source = File('${tempDir.path}/source.jpg');
      await source.writeAsString('raw image bytes');
      final fileStore = CaptureMediaFileStore(
        rootDirectoryProvider: () async => tempDir,
        now: () => DateTime.utc(2026, 6, 24, 9),
      );

      final asset = await fileStore.storePickedImage(
        file: XFile(source.path, mimeType: 'image/jpeg', name: 'source.jpg'),
        source: 'gallery',
      );
      final metadata = asset.rawMetadata;

      expect(asset.sourceUri, startsWith('local://capture_media/photos/'));
      expect(asset.mimeType, 'image/jpeg');
      expect(asset.sizeBytes, source.lengthSync());
      expect(metadata['source'], 'gallery');
      expect(metadata['local_path'], isA<String>());
      expect(metadata['sha256'], hasLength(64));
      expect(File(metadata['local_path']! as String).existsSync(), isTrue);
    },
  );

  test(
    'image picker adapter stores selected photo with local metadata',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'widenote-picker-test-',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final source = File('${tempDir.path}/picked.jpg');
      await source.writeAsString('real-ish camera bytes');
      var requestedFullMetadata = true;
      final adapter = ImagePickerPhotoCaptureAdapter(
        fileStore: CaptureMediaFileStore(
          rootDirectoryProvider: () async => tempDir,
          now: () => DateTime.utc(2026, 6, 24, 10),
        ),
        supportsImageSource: (_) async => true,
        pickImage: (sourceKind, {requestFullMetadata = false}) async {
          expect(sourceKind, ImageSource.camera);
          requestedFullMetadata = requestFullMetadata;
          return XFile(source.path, name: 'picked.jpg', mimeType: 'image/jpeg');
        },
      );

      final asset = await adapter.captureFromCamera();
      final metadata = asset.rawMetadata;

      expect(requestedFullMetadata, isFalse);
      expect(asset.sourceUri, startsWith('local://capture_media/photos/'));
      expect(asset.sizeBytes, source.lengthSync());
      expect(metadata['adapter'], 'image_picker');
      expect(metadata['source'], 'camera');
      expect(metadata['user_selected'], isTrue);
      expect(metadata['request_full_metadata'], isFalse);
      expect(metadata['sha256'], hasLength(64));
      expect(File(metadata['local_path']! as String).existsSync(), isTrue);
    },
  );

  test(
    'image picker adapter maps cancel, permission, unavailable, and error',
    () async {
      Future<CaptureMediaException> catchMediaError(
        Future<RawCaptureAsset> Function() action,
      ) async {
        try {
          await action();
        } on CaptureMediaException catch (error) {
          return error;
        }
        fail('Expected CaptureMediaException');
      }

      final cancelled = await catchMediaError(
        () => ImagePickerPhotoCaptureAdapter(
          supportsImageSource: (_) => true,
          pickImage: (_, {requestFullMetadata = false}) async => null,
        ).pickFromGallery(),
      );
      expect(cancelled.reason, CaptureMediaFailureReason.cancelled);
      expect(cancelled.message, 'Gallery selection cancelled.');

      final denied = await catchMediaError(
        () => ImagePickerPhotoCaptureAdapter(
          supportsImageSource: (_) => true,
          pickImage: (_, {requestFullMetadata = false}) async {
            throw PlatformException(code: 'photo_access_restricted');
          },
        ).pickFromGallery(),
      );
      expect(denied.reason, CaptureMediaFailureReason.permissionDenied);
      expect(denied.message, 'Photo library permission denied.');

      final unavailable = await catchMediaError(
        () => ImagePickerPhotoCaptureAdapter(
          supportsImageSource: (_) => false,
        ).captureFromCamera(),
      );
      expect(unavailable.reason, CaptureMediaFailureReason.unavailable);
      expect(unavailable.message, 'Camera is unavailable on this device.');

      final failed = await catchMediaError(
        () => ImagePickerPhotoCaptureAdapter(
          supportsImageSource: (_) => true,
          pickImage: (_, {requestFullMetadata = false}) async {
            throw PlatformException(code: 'picker_broke');
          },
        ).captureFromCamera(),
      );
      expect(failed.reason, CaptureMediaFailureReason.platformError);
      expect(failed.message, 'Camera capture failed.');
    },
  );

  test(
    'file store stores voice recording metadata and cleans empty output',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'widenote-voice-store-test-',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final fileStore = CaptureMediaFileStore(
        rootDirectoryProvider: () async => tempDir,
        now: () => DateTime.utc(2026, 6, 24, 11),
      );
      final input = File('${tempDir.path}/input.wav');
      await input.writeAsString('voice bytes');
      final session = await fileStore.prepareVoiceSession();

      final asset = await fileStore.storeVoiceRecording(session, input.path);
      final metadata = asset.rawMetadata;

      expect(asset.kind, CaptureAssetKind.voice);
      expect(asset.sourceUri, startsWith('local://capture_media/voice/'));
      expect(asset.mimeType, 'audio/wav');
      expect(metadata['adapter'], 'record');
      expect(metadata['source'], 'microphone');
      expect(metadata['sha256'], hasLength(64));
      expect(metadata['duration_ms'], 0);
      expect(File(metadata['local_path']! as String).existsSync(), isTrue);

      final emptySession = await fileStore.prepareVoiceSession();
      await File(emptySession.path).writeAsBytes(<int>[]);
      try {
        await fileStore.storeVoiceRecording(emptySession, emptySession.path);
        fail('Expected empty recording to fail');
      } on CaptureMediaException catch (error) {
        expect(error.reason, CaptureMediaFailureReason.unavailable);
        expect(error.message, 'Voice recording produced an empty file.');
      }
      expect(File(emptySession.path).existsSync(), isFalse);
    },
  );
}

final class _CountingPhotoAdapter implements PhotoCaptureAdapter {
  int cameraCalls = 0;
  int galleryCalls = 0;

  @override
  Future<RawCaptureAsset> captureFromCamera() {
    cameraCalls += 1;
    return FakePhotoCaptureAdapter(
      now: () => DateTime.utc(2026, 6, 24, 6),
    ).captureFromCamera();
  }

  @override
  Future<RawCaptureAsset> pickFromGallery() {
    galleryCalls += 1;
    return FakePhotoCaptureAdapter(
      now: () => DateTime.utc(2026, 6, 24, 7),
    ).pickFromGallery();
  }
}

final class _CountingVoiceAdapter implements VoiceCaptureAdapter {
  int startCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;

  @override
  Future<VoiceRecordingSession> startRecording() {
    startCalls += 1;
    return FakeVoiceCaptureAdapter(
      now: () => DateTime.utc(2026, 6, 24, 8),
    ).startRecording();
  }

  @override
  Future<RawCaptureAsset> stopRecording(VoiceRecordingSession session) {
    stopCalls += 1;
    return FakeVoiceCaptureAdapter(
      now: () => DateTime.utc(2026, 6, 24, 8, 1),
    ).stopRecording(session);
  }

  @override
  Future<void> cancelRecording(VoiceRecordingSession session) async {
    cancelCalls += 1;
  }
}
