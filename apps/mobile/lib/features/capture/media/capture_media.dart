enum CaptureAssetKind {
  photo('photo'),
  voice('voice'),
  share('share');

  const CaptureAssetKind(this.wireName);

  final String wireName;
}

enum CaptureMediaFailureReason {
  cancelled('cancelled'),
  permissionDenied('permission_denied'),
  unavailable('unavailable'),
  platformError('platform_error');

  const CaptureMediaFailureReason(this.wireName);

  final String wireName;
}

final class CaptureMediaException implements Exception {
  const CaptureMediaException(this.reason, this.message, {this.cause});

  final CaptureMediaFailureReason reason;
  final String message;
  final Object? cause;

  String get userMessage => message;

  @override
  String toString() => 'CaptureMediaException(${reason.wireName}): $message';
}

enum CaptureAttachmentState {
  ready('ready'),
  needsReview('needs_review'),
  blocked('blocked');

  const CaptureAttachmentState(this.wireName);

  final String wireName;
}

final class RawCaptureAsset {
  const RawCaptureAsset({
    required this.id,
    required this.kind,
    required this.displayName,
    required this.mimeType,
    required this.sourceUri,
    required this.createdAt,
    this.sizeBytes,
    this.previewText = '',
    this.rawMetadata = const <String, Object?>{},
    this.safetyLabels = const <String>[],
  });

  final String id;
  final CaptureAssetKind kind;
  final String displayName;
  final String mimeType;
  final String sourceUri;
  final DateTime createdAt;
  final int? sizeBytes;
  final String previewText;
  final Map<String, Object?> rawMetadata;
  final List<String> safetyLabels;

  Map<String, Object?> toRawMetadata() {
    return <String, Object?>{
      'id': id,
      'kind': kind.wireName,
      'display_name': displayName,
      'mime_type': mimeType,
      'source_uri': sourceUri,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      'created_at': createdAt.toUtc().toIso8601String(),
      'adapter_metadata': rawMetadata,
      'safety_labels': safetyLabels,
    };
  }
}

final class CaptureAttachment {
  const CaptureAttachment({
    required this.id,
    required this.kind,
    required this.displayName,
    required this.mimeType,
    required this.sourceUri,
    required this.createdAt,
    required this.state,
    required this.rawMetadata,
    this.sizeBytes,
    this.previewText = '',
    this.reviewReason,
  });

  final String id;
  final CaptureAssetKind kind;
  final String displayName;
  final String mimeType;
  final String sourceUri;
  final DateTime createdAt;
  final int? sizeBytes;
  final CaptureAttachmentState state;
  final String previewText;
  final String? reviewReason;
  final Map<String, Object?> rawMetadata;

  bool get canRenderPreview => state != CaptureAttachmentState.blocked;

  bool get isReady => state == CaptureAttachmentState.ready;

  CaptureAttachment copyWith({
    CaptureAttachmentState? state,
    String? previewText,
    String? reviewReason,
    Map<String, Object?>? rawMetadata,
  }) {
    return CaptureAttachment(
      id: id,
      kind: kind,
      displayName: displayName,
      mimeType: mimeType,
      sourceUri: sourceUri,
      createdAt: createdAt,
      sizeBytes: sizeBytes,
      state: state ?? this.state,
      previewText: previewText ?? this.previewText,
      reviewReason: reviewReason,
      rawMetadata: rawMetadata ?? this.rawMetadata,
    );
  }

  Map<String, Object?> toEventPayload() {
    return <String, Object?>{
      'id': id,
      'kind': kind.wireName,
      'display_name': displayName,
      'mime_type': mimeType,
      'source_uri': sourceUri,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      'state': state.wireName,
      'preview_text': canRenderPreview ? previewText : 'preview_hidden',
      if (reviewReason != null) 'review_reason': reviewReason,
      'raw_metadata': rawMetadata,
      'source_ref': <String, Object?>{'kind': 'capture_attachment', 'id': id},
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}

final class AssetSafetyDecision {
  const AssetSafetyDecision({
    required this.state,
    required this.reason,
    required this.previewText,
  });

  final CaptureAttachmentState state;
  final String reason;
  final String previewText;
}

final class AssetSafetyGuard {
  const AssetSafetyGuard({
    this.allowedMimeTypes = const <String>{
      'image/jpeg',
      'image/png',
      'image/heic',
      'image/webp',
      'audio/m4a',
      'audio/mp4',
      'text/plain',
      'text/uri-list',
    },
  });

  final Set<String> allowedMimeTypes;

  CaptureAttachment buildAttachment(RawCaptureAsset asset) {
    final decision = evaluate(asset);
    return CaptureAttachment(
      id: asset.id,
      kind: asset.kind,
      displayName: asset.displayName,
      mimeType: asset.mimeType,
      sourceUri: asset.sourceUri,
      createdAt: asset.createdAt,
      sizeBytes: asset.sizeBytes,
      state: decision.state,
      previewText: decision.previewText,
      reviewReason: decision.reason,
      rawMetadata: asset.toRawMetadata(),
    );
  }

  AssetSafetyDecision evaluate(RawCaptureAsset asset) {
    if (asset.safetyLabels.contains('dangerous')) {
      return const AssetSafetyDecision(
        state: CaptureAttachmentState.blocked,
        reason: 'blocked_by_asset_safety',
        previewText: 'Preview hidden until review.',
      );
    }
    if (!allowedMimeTypes.contains(asset.mimeType)) {
      return AssetSafetyDecision(
        state: CaptureAttachmentState.blocked,
        reason: 'unsupported_mime_type:${asset.mimeType}',
        previewText: 'Preview hidden until review.',
      );
    }
    if (asset.kind == CaptureAssetKind.voice &&
        asset.rawMetadata['transcript_requires_review'] == true) {
      return AssetSafetyDecision(
        state: CaptureAttachmentState.needsReview,
        reason: 'voice_transcript_requires_review',
        previewText: asset.previewText,
      );
    }
    return AssetSafetyDecision(
      state: CaptureAttachmentState.ready,
      reason: 'allowed',
      previewText: asset.previewText,
    );
  }
}

abstract interface class PhotoCaptureAdapter {
  Future<RawCaptureAsset> captureFromCamera();

  Future<RawCaptureAsset> pickFromGallery();
}

abstract interface class VoiceCaptureAdapter {
  Future<VoiceRecordingSession> startRecording();

  Future<RawCaptureAsset> stopRecording(VoiceRecordingSession session);

  Future<void> cancelRecording(VoiceRecordingSession session);
}

final class VoiceRecordingSession {
  const VoiceRecordingSession({
    required this.id,
    required this.path,
    required this.startedAt,
  });

  final String id;
  final String path;
  final DateTime startedAt;
}

enum FakePhotoMode { safe, dangerous, unsupported, cancelled, denied, error }

final class FakePhotoCaptureAdapter implements PhotoCaptureAdapter {
  const FakePhotoCaptureAdapter({
    this.mode = FakePhotoMode.safe,
    this.now = _defaultFakeNow,
  });

  final FakePhotoMode mode;
  final DateTime Function() now;

  @override
  Future<RawCaptureAsset> captureFromCamera() {
    return _pickPhoto(source: 'camera');
  }

  @override
  Future<RawCaptureAsset> pickFromGallery() {
    return _pickPhoto(source: 'gallery');
  }

  Future<RawCaptureAsset> _pickPhoto({required String source}) async {
    final createdAt = now();
    return switch (mode) {
      FakePhotoMode.safe => RawCaptureAsset(
        id: 'fake-$source-photo-${createdAt.microsecondsSinceEpoch}',
        kind: CaptureAssetKind.photo,
        displayName: source == 'camera'
            ? 'Camera photo sample.jpg'
            : 'Gallery photo sample.jpg',
        mimeType: 'image/jpeg',
        sourceUri: 'fake://$source/photo-sample.jpg',
        sizeBytes: 384000,
        previewText: source == 'camera'
            ? 'Camera photo saved locally: whiteboard snapshot'
            : 'Gallery photo saved locally: reference image',
        rawMetadata: <String, Object?>{
          'adapter': 'fake_photo',
          'source': source,
          'width': 1280,
          'height': 960,
          'sha256': 'fake-$source-photo-sha256',
        },
        createdAt: createdAt,
      ),
      FakePhotoMode.dangerous => RawCaptureAsset(
        id: 'fake-$source-photo-blocked-${createdAt.microsecondsSinceEpoch}',
        kind: CaptureAssetKind.photo,
        displayName: 'Blocked photo sample.jpg',
        mimeType: 'image/jpeg',
        sourceUri: 'fake://$source/blocked-photo.jpg',
        sizeBytes: 512000,
        previewText: 'DANGEROUS RAW PREVIEW SHOULD NOT RENDER',
        rawMetadata: <String, Object?>{
          'adapter': 'fake_photo',
          'source': source,
          'raw_preview_text': 'DANGEROUS RAW PREVIEW SHOULD NOT RENDER',
        },
        safetyLabels: const <String>['dangerous'],
        createdAt: createdAt,
      ),
      FakePhotoMode.unsupported => RawCaptureAsset(
        id: 'fake-$source-photo-unsupported-${createdAt.microsecondsSinceEpoch}',
        kind: CaptureAssetKind.photo,
        displayName: 'Unsupported photo sample.raw',
        mimeType: 'image/x-camera-raw',
        sourceUri: 'fake://$source/unsupported.raw',
        sizeBytes: 720000,
        previewText: 'Unsupported raw image preview',
        rawMetadata: <String, Object?>{
          'adapter': 'fake_photo',
          'source': source,
        },
        createdAt: createdAt,
      ),
      FakePhotoMode.cancelled => throw CaptureMediaException(
        CaptureMediaFailureReason.cancelled,
        source == 'camera'
            ? 'Camera capture cancelled.'
            : 'Gallery selection cancelled.',
      ),
      FakePhotoMode.denied => throw CaptureMediaException(
        CaptureMediaFailureReason.permissionDenied,
        source == 'camera'
            ? 'Camera permission denied.'
            : 'Photo library permission denied.',
      ),
      FakePhotoMode.error => throw CaptureMediaException(
        CaptureMediaFailureReason.platformError,
        source == 'camera'
            ? 'Camera capture failed.'
            : 'Gallery selection failed.',
      ),
    };
  }
}

enum FakeVoiceMode { success, denied, cancelled, stopError }

final class FakeVoiceCaptureAdapter implements VoiceCaptureAdapter {
  const FakeVoiceCaptureAdapter({
    this.mode = FakeVoiceMode.success,
    this.now = _defaultFakeNow,
  });

  final FakeVoiceMode mode;
  final DateTime Function() now;

  @override
  Future<VoiceRecordingSession> startRecording() async {
    final createdAt = now();
    return switch (mode) {
      FakeVoiceMode.success || FakeVoiceMode.stopError => VoiceRecordingSession(
        id: 'fake-voice-session-${createdAt.microsecondsSinceEpoch}',
        path: 'fake://microphone/voice-note.m4a',
        startedAt: createdAt,
      ),
      FakeVoiceMode.denied => throw const CaptureMediaException(
        CaptureMediaFailureReason.permissionDenied,
        'Microphone permission denied.',
      ),
      FakeVoiceMode.cancelled => throw const CaptureMediaException(
        CaptureMediaFailureReason.cancelled,
        'Voice recording cancelled.',
      ),
    };
  }

  @override
  Future<RawCaptureAsset> stopRecording(VoiceRecordingSession session) async {
    if (mode == FakeVoiceMode.stopError) {
      throw const CaptureMediaException(
        CaptureMediaFailureReason.platformError,
        'Voice recording failed.',
      );
    }
    final endedAt = now();
    return RawCaptureAsset(
      id: 'fake-voice-${endedAt.microsecondsSinceEpoch}',
      kind: CaptureAssetKind.voice,
      displayName: 'Voice recording sample.m4a',
      mimeType: 'audio/m4a',
      sourceUri: session.path,
      sizeBytes: 96000,
      previewText: 'Voice recording captured. Transcript pending.',
      rawMetadata: <String, Object?>{
        'adapter': 'fake_voice',
        'source': 'microphone',
        'duration_ms': endedAt.difference(session.startedAt).inMilliseconds,
        'sha256': 'fake-voice-sha256',
        'transcript_status': 'pending',
      },
      createdAt: endedAt,
    );
  }

  @override
  Future<void> cancelRecording(VoiceRecordingSession session) async {}
}

DateTime _defaultFakeNow() => DateTime.now().toUtc();
