import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_mobile/features/capture/application/capture_input_controller.dart';
import 'package:widenote_mobile/features/capture/media/capture_media.dart';

void main() {
  test('fake photo adapter creates safe attachment metadata', () async {
    final raw = await FakePhotoCaptureAdapter(
      now: () => DateTime.utc(2026, 6, 24, 1),
    ).pickPhoto();
    final attachment = const AssetSafetyGuard().buildAttachment(raw);
    final payload = attachment.toEventPayload();

    expect(attachment.state, CaptureAttachmentState.ready);
    expect(attachment.previewText, contains('Photo sample'));
    expect(payload['kind'], 'photo');
    expect(payload['source_ref'], isA<Map<String, Object?>>());
    expect((payload['raw_metadata']! as Map)['mime_type'], 'image/jpeg');
  });

  test('dangerous fake photo is blocked and hides raw preview', () async {
    final raw = await FakePhotoCaptureAdapter(
      mode: FakePhotoMode.dangerous,
      now: () => DateTime.utc(2026, 6, 24, 2),
    ).pickPhoto();
    final attachment = const AssetSafetyGuard().buildAttachment(raw);
    final payload = attachment.toEventPayload();

    expect(attachment.state, CaptureAttachmentState.blocked);
    expect(attachment.canRenderPreview, isFalse);
    expect(attachment.previewText, isNot(contains('DANGEROUS')));
    expect(payload['preview_text'], 'preview_hidden');
    expect(
      ((payload['raw_metadata']! as Map)['adapter_metadata']!
          as Map)['raw_preview_text'],
      contains('DANGEROUS'),
    );
  });

  test('unsupported media is blocked by MIME type', () async {
    final raw = await FakePhotoCaptureAdapter(
      mode: FakePhotoMode.unsupported,
      now: () => DateTime.utc(2026, 6, 24, 3),
    ).pickPhoto();
    final attachment = const AssetSafetyGuard().buildAttachment(raw);

    expect(attachment.state, CaptureAttachmentState.blocked);
    expect(attachment.reviewReason, 'unsupported_mime_type:image/x-camera-raw');
  });

  test('voice transcript requires user review before submit', () async {
    final container = ProviderContainer(
      overrides: [
        voiceCaptureAdapterProvider.overrideWithValue(
          FakeVoiceCaptureAdapter(now: () => DateTime.utc(2026, 6, 24, 4)),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(captureInputControllerProvider.notifier)
        .addVoiceTranscript();

    final reviewState = container.read(captureInputControllerProvider);
    final attachment = reviewState.attachments.single;
    expect(attachment.kind, CaptureAssetKind.voice);
    expect(attachment.state, CaptureAttachmentState.needsReview);
    expect(reviewState.canSubmit, isFalse);

    container
        .read(captureInputControllerProvider.notifier)
        .acceptAttachmentReview(attachment.id);

    final acceptedState = container.read(captureInputControllerProvider);
    final accepted = acceptedState.attachments.single;
    expect(accepted.state, CaptureAttachmentState.ready);
    expect(acceptedState.canSubmit, isTrue);
    expect(accepted.rawMetadata['review'], isA<Map<String, Object?>>());
  });

  test('share import adapter preserves source URL metadata', () async {
    final raw = await FakeShareImportAdapter(
      now: () => DateTime.utc(2026, 6, 24, 5),
    ).importSharedItem();
    final attachment = const AssetSafetyGuard().buildAttachment(raw);
    final payload = attachment.toEventPayload();
    final metadata = payload['raw_metadata']! as Map;
    final adapterMetadata = metadata['adapter_metadata']! as Map;

    expect(attachment.kind, CaptureAssetKind.share);
    expect(attachment.state, CaptureAttachmentState.ready);
    expect(adapterMetadata['url'], 'https://example.test/widenote');
  });
}
