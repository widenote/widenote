import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transcription/transcription_service.dart';
import '../../transcription/transcription_types.dart';
import '../media/capture_media.dart';
import '../media/platform_capture_media.dart';

enum CaptureMode { text, voice, media }

final assetSafetyGuardProvider = Provider<AssetSafetyGuard>((ref) {
  return const AssetSafetyGuard();
});

final captureMediaFileStoreProvider = Provider<CaptureMediaFileStore>((ref) {
  return CaptureMediaFileStore();
});

final photoCaptureAdapterProvider = Provider<PhotoCaptureAdapter>((ref) {
  return ImagePickerPhotoCaptureAdapter(
    fileStore: ref.watch(captureMediaFileStoreProvider),
  );
});

final voiceCaptureAdapterProvider = Provider<VoiceCaptureAdapter>((ref) {
  return RecordVoiceCaptureAdapter(
    fileStore: ref.watch(captureMediaFileStoreProvider),
  );
});

final captureInputControllerProvider =
    NotifierProvider<CaptureInputController, CaptureInputState>(
      CaptureInputController.new,
    );

final class CaptureInputState {
  const CaptureInputState({
    required this.attachments,
    this.mode = CaptureMode.text,
    this.voiceSession,
    this.voicePreview = const TranscriptionPreview(),
    this.errorMessage,
    this.isBusy = false,
  });

  factory CaptureInputState.initial() {
    return const CaptureInputState(attachments: <CaptureAttachment>[]);
  }

  final List<CaptureAttachment> attachments;
  final CaptureMode mode;
  final VoiceRecordingSession? voiceSession;
  final TranscriptionPreview voicePreview;
  final String? errorMessage;
  final bool isBusy;

  bool get hasAttachments => attachments.isNotEmpty;

  bool get isRecordingVoice => voiceSession != null;

  bool get hasBlockedAttachment => attachments.any(
    (attachment) => attachment.state == CaptureAttachmentState.blocked,
  );

  bool get hasReviewAttachment => attachments.any(
    (attachment) => attachment.state == CaptureAttachmentState.needsReview,
  );

  bool get canSubmit =>
      !hasBlockedAttachment && !hasReviewAttachment && !isRecordingVoice;

  CaptureInputState copyWith({
    List<CaptureAttachment>? attachments,
    CaptureMode? mode,
    VoiceRecordingSession? voiceSession,
    TranscriptionPreview? voicePreview,
    String? errorMessage,
    bool? isBusy,
    bool clearError = false,
    bool clearVoiceSession = false,
    bool clearVoicePreview = false,
  }) {
    return CaptureInputState(
      attachments: attachments ?? this.attachments,
      mode: mode ?? this.mode,
      voiceSession: clearVoiceSession
          ? null
          : voiceSession ?? this.voiceSession,
      voicePreview: clearVoicePreview
          ? const TranscriptionPreview()
          : voicePreview ?? this.voicePreview,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isBusy: isBusy ?? this.isBusy,
    );
  }
}

class CaptureInputController extends Notifier<CaptureInputState> {
  StreamSubscription<TranscriptionPreview>? _voicePreviewSubscription;

  @override
  CaptureInputState build() {
    ref.onDispose(() {
      unawaited(_voicePreviewSubscription?.cancel());
    });
    return CaptureInputState.initial();
  }

  void setMode(CaptureMode mode) {
    if (state.mode == mode || state.isBusy) {
      return;
    }
    state = state.copyWith(mode: mode, clearError: true);
  }

  Future<void> addCameraPhoto() async {
    await _capture(
      () => ref.read(photoCaptureAdapterProvider).captureFromCamera(),
    );
  }

  Future<void> addGalleryPhoto() async {
    await _capture(
      () => ref.read(photoCaptureAdapterProvider).pickFromGallery(),
    );
  }

  Future<void> startVoiceRecording() async {
    if (state.isBusy || state.isRecordingVoice) {
      return;
    }
    state = state.copyWith(
      mode: CaptureMode.voice,
      isBusy: true,
      clearError: true,
    );
    try {
      final session = await ref
          .read(voiceCaptureAdapterProvider)
          .startRecording();
      state = state.copyWith(
        voiceSession: session,
        voicePreview: const TranscriptionPreview(
          status: TranscriptStatus.transcribing,
        ),
        isBusy: false,
        clearError: true,
      );
      _startVoicePreview(session);
    } on CaptureMediaException catch (error) {
      state = state.copyWith(isBusy: false, errorMessage: error.userMessage);
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'Voice recording failed: $error',
      );
    }
  }

  Future<void> stopVoiceRecording() async {
    final session = state.voiceSession;
    if (state.isBusy || session == null) {
      return;
    }
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final draftPreview = state.voicePreview;
      final rawAsset = await ref
          .read(voiceCaptureAdapterProvider)
          .stopRecording(session);
      await _voicePreviewSubscription?.cancel();
      final builtAttachment = ref
          .read(assetSafetyGuardProvider)
          .buildAttachment(rawAsset);
      final attachment = _attachmentWithDraftPreview(
        builtAttachment,
        draftPreview,
      );
      state = state.copyWith(
        attachments: [attachment, ...state.attachments],
        isBusy: false,
        clearVoiceSession: true,
        clearVoicePreview: true,
        clearError: true,
      );
    } on CaptureMediaException catch (error) {
      state = state.copyWith(
        isBusy: false,
        clearVoiceSession: true,
        clearVoicePreview: true,
        errorMessage: error.userMessage,
      );
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        clearVoiceSession: true,
        clearVoicePreview: true,
        errorMessage: 'Voice recording failed: $error',
      );
    }
  }

  Future<void> cancelVoiceRecording() async {
    final session = state.voiceSession;
    if (state.isBusy || session == null) {
      return;
    }
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await ref.read(voiceCaptureAdapterProvider).cancelRecording(session);
      await _voicePreviewSubscription?.cancel();
      state = state.copyWith(
        isBusy: false,
        clearVoiceSession: true,
        clearVoicePreview: true,
        errorMessage: 'Voice recording cancelled.',
      );
    } on CaptureMediaException catch (error) {
      state = state.copyWith(
        isBusy: false,
        clearVoiceSession: true,
        clearVoicePreview: true,
        errorMessage: error.userMessage,
      );
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        clearVoiceSession: true,
        clearVoicePreview: true,
        errorMessage: 'Voice recording cancel failed: $error',
      );
    }
  }

  void acceptAttachmentReview(String id) {
    state = state.copyWith(
      attachments: [
        for (final attachment in state.attachments)
          if (attachment.id == id)
            attachment.copyWith(
              state: CaptureAttachmentState.ready,
              reviewReason: null,
              derivedArtifacts: [
                for (final artifact in attachment.derivedArtifacts)
                  artifact.status == AttachmentDerivedArtifactStatus.needsReview
                      ? AttachmentDerivedArtifact(
                          id: artifact.id,
                          artifactKind: artifact.artifactKind,
                          status: AttachmentDerivedArtifactStatus.ready,
                          sourceLabel: artifact.sourceLabel,
                          excerpt: artifact.excerpt,
                          reason: artifact.reason,
                        )
                      : artifact,
              ],
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
    unawaited(_voicePreviewSubscription?.cancel());
    state = CaptureInputState.initial();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void markSubmitBlocked() {
    final message = state.isRecordingVoice
        ? 'Stop or cancel the voice recording before saving.'
        : state.hasBlockedAttachment
        ? 'Remove blocked attachments before saving.'
        : 'Review attachments before saving.';
    state = state.copyWith(errorMessage: message);
  }

  void markEmptySubmitBlocked(String message) {
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
    } on CaptureMediaException catch (error) {
      state = state.copyWith(isBusy: false, errorMessage: error.userMessage);
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'Attachment failed: $error',
      );
    }
  }

  void _startVoicePreview(VoiceRecordingSession session) {
    unawaited(_voicePreviewSubscription?.cancel());
    final pcmStream = session.pcmStream;
    if (pcmStream == null) {
      state = state.copyWith(
        voicePreview: const TranscriptionPreview(
          status: TranscriptStatus.pending,
          errorCode: TranscriptionFailureCode.streamUnavailable,
        ),
      );
      return;
    }
    _voicePreviewSubscription = ref
        .read(transcriptionServiceProvider)
        .preview(
          pcmStream.map(
            (bytes) => AudioPcmChunk(
              bytes: bytes,
              sampleRate: session.sampleRate,
              channels: session.numChannels,
            ),
          ),
        )
        .listen(
          (preview) {
            state = state.copyWith(voicePreview: preview);
          },
          onError: (_) {
            state = state.copyWith(
              voicePreview: const TranscriptionPreview(
                status: TranscriptStatus.pending,
                errorCode: TranscriptionFailureCode.streamUnavailable,
              ),
            );
          },
        );
  }

  CaptureAttachment _attachmentWithDraftPreview(
    CaptureAttachment attachment,
    TranscriptionPreview preview,
  ) {
    if (!preview.hasText) {
      return attachment;
    }
    final draft = preview.displayText;
    return attachment.copyWith(
      previewText: 'Draft transcript: $draft. Final transcript pending.',
      rawMetadata: <String, Object?>{
        ...attachment.rawMetadata,
        'draft_transcript': draft,
        'transcript_status': 'pending',
      },
    );
  }
}
