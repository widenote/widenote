import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../media/capture_media.dart';

final assetSafetyGuardProvider = Provider<AssetSafetyGuard>((ref) {
  return const AssetSafetyGuard();
});

final photoCaptureAdapterProvider = Provider<PhotoCaptureAdapter>((ref) {
  return const FakePhotoCaptureAdapter();
});

final voiceCaptureAdapterProvider = Provider<VoiceCaptureAdapter>((ref) {
  return const FakeVoiceCaptureAdapter();
});

final shareImportAdapterProvider = Provider<ShareImportAdapter>((ref) {
  return const FakeShareImportAdapter();
});

final captureInputControllerProvider =
    NotifierProvider<CaptureInputController, CaptureInputState>(
      CaptureInputController.new,
    );

final class CaptureInputState {
  const CaptureInputState({
    required this.attachments,
    this.errorMessage,
    this.isBusy = false,
  });

  factory CaptureInputState.initial() {
    return const CaptureInputState(attachments: <CaptureAttachment>[]);
  }

  final List<CaptureAttachment> attachments;
  final String? errorMessage;
  final bool isBusy;

  bool get hasAttachments => attachments.isNotEmpty;

  bool get hasBlockedAttachment => attachments.any(
    (attachment) => attachment.state == CaptureAttachmentState.blocked,
  );

  bool get hasReviewAttachment => attachments.any(
    (attachment) => attachment.state == CaptureAttachmentState.needsReview,
  );

  bool get canSubmit => !hasBlockedAttachment && !hasReviewAttachment;

  CaptureInputState copyWith({
    List<CaptureAttachment>? attachments,
    String? errorMessage,
    bool? isBusy,
    bool clearError = false,
  }) {
    return CaptureInputState(
      attachments: attachments ?? this.attachments,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isBusy: isBusy ?? this.isBusy,
    );
  }
}

class CaptureInputController extends Notifier<CaptureInputState> {
  @override
  CaptureInputState build() => CaptureInputState.initial();

  Future<void> addPhoto() async {
    await _capture(() => ref.read(photoCaptureAdapterProvider).pickPhoto());
  }

  Future<void> addVoiceTranscript() async {
    await _capture(
      () => ref.read(voiceCaptureAdapterProvider).captureVoiceTranscript(),
    );
  }

  Future<void> addShareImport() async {
    await _capture(
      () => ref.read(shareImportAdapterProvider).importSharedItem(),
    );
  }

  void acceptAttachmentReview(String id) {
    state = state.copyWith(
      attachments: [
        for (final attachment in state.attachments)
          if (attachment.id == id)
            attachment.copyWith(
              state: CaptureAttachmentState.ready,
              reviewReason: null,
              rawMetadata: <String, Object?>{
                ...attachment.rawMetadata,
                'review': <String, Object?>{
                  'accepted': true,
                  'reason': 'user_confirmed_transcript',
                },
              },
            )
          else
            attachment,
      ],
      clearError: true,
    );
  }

  void removeAttachment(String id) {
    state = state.copyWith(
      attachments: [
        for (final attachment in state.attachments)
          if (attachment.id != id) attachment,
      ],
      clearError: true,
    );
  }

  void clear() {
    state = CaptureInputState.initial();
  }

  void markSubmitBlocked() {
    final message = state.hasBlockedAttachment
        ? 'Remove blocked attachments before recording.'
        : 'Review attachments before recording.';
    state = state.copyWith(errorMessage: message);
  }

  Future<void> _capture(Future<RawCaptureAsset> Function() action) async {
    if (state.isBusy) {
      return;
    }

    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final rawAsset = await action();
      final attachment = ref
          .read(assetSafetyGuardProvider)
          .buildAttachment(rawAsset);
      state = state.copyWith(
        attachments: [attachment, ...state.attachments],
        isBusy: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'Attachment failed: $error',
      );
    }
  }
}
