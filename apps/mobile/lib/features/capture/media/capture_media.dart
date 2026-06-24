enum CaptureAssetKind {
  photo('photo'),
  voice('voice'),
  share('share');

  const CaptureAssetKind(this.wireName);

  final String wireName;
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
      'audio/m4a',
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
  Future<RawCaptureAsset> pickPhoto();
}

abstract interface class VoiceCaptureAdapter {
  Future<RawCaptureAsset> captureVoiceTranscript();
}

abstract interface class ShareImportAdapter {
  Future<RawCaptureAsset> importSharedItem();
}

enum FakePhotoMode { safe, dangerous, unsupported }

final class FakePhotoCaptureAdapter implements PhotoCaptureAdapter {
  const FakePhotoCaptureAdapter({
    this.mode = FakePhotoMode.safe,
    this.now = _defaultFakeNow,
  });

  final FakePhotoMode mode;
  final DateTime Function() now;

  @override
  Future<RawCaptureAsset> pickPhoto() async {
    final createdAt = now();
    return switch (mode) {
      FakePhotoMode.safe => RawCaptureAsset(
        id: 'fake-photo-${createdAt.microsecondsSinceEpoch}',
        kind: CaptureAssetKind.photo,
        displayName: 'Field photo sample.jpg',
        mimeType: 'image/jpeg',
        sourceUri: 'fake://camera/field-photo.jpg',
        sizeBytes: 384000,
        previewText: 'Photo sample: whiteboard snapshot',
        rawMetadata: const <String, Object?>{
          'adapter': 'fake_photo',
          'width': 1280,
          'height': 960,
        },
        createdAt: createdAt,
      ),
      FakePhotoMode.dangerous => RawCaptureAsset(
        id: 'fake-photo-blocked-${createdAt.microsecondsSinceEpoch}',
        kind: CaptureAssetKind.photo,
        displayName: 'Blocked photo sample.jpg',
        mimeType: 'image/jpeg',
        sourceUri: 'fake://camera/blocked-photo.jpg',
        sizeBytes: 512000,
        previewText: 'DANGEROUS RAW PREVIEW SHOULD NOT RENDER',
        rawMetadata: const <String, Object?>{
          'adapter': 'fake_photo',
          'raw_preview_text': 'DANGEROUS RAW PREVIEW SHOULD NOT RENDER',
        },
        safetyLabels: const <String>['dangerous'],
        createdAt: createdAt,
      ),
      FakePhotoMode.unsupported => RawCaptureAsset(
        id: 'fake-photo-unsupported-${createdAt.microsecondsSinceEpoch}',
        kind: CaptureAssetKind.photo,
        displayName: 'Unsupported photo sample.raw',
        mimeType: 'image/x-camera-raw',
        sourceUri: 'fake://camera/unsupported.raw',
        sizeBytes: 720000,
        previewText: 'Unsupported raw image preview',
        rawMetadata: const <String, Object?>{'adapter': 'fake_photo'},
        createdAt: createdAt,
      ),
    };
  }
}

final class FakeVoiceCaptureAdapter implements VoiceCaptureAdapter {
  const FakeVoiceCaptureAdapter({this.now = _defaultFakeNow});

  final DateTime Function() now;

  @override
  Future<RawCaptureAsset> captureVoiceTranscript() async {
    final createdAt = now();
    return RawCaptureAsset(
      id: 'fake-voice-${createdAt.microsecondsSinceEpoch}',
      kind: CaptureAssetKind.voice,
      displayName: 'Voice transcript sample.m4a',
      mimeType: 'audio/m4a',
      sourceUri: 'fake://microphone/voice-note.m4a',
      sizeBytes: 96000,
      previewText: 'Transcript draft: remember to compare capture flows.',
      rawMetadata: const <String, Object?>{
        'adapter': 'fake_voice',
        'duration_ms': 6400,
        'transcript_text':
            'Transcript draft: remember to compare capture flows.',
        'transcript_requires_review': true,
      },
      createdAt: createdAt,
    );
  }
}

final class FakeShareImportAdapter implements ShareImportAdapter {
  const FakeShareImportAdapter({this.now = _defaultFakeNow});

  final DateTime Function() now;

  @override
  Future<RawCaptureAsset> importSharedItem() async {
    final createdAt = now();
    return RawCaptureAsset(
      id: 'fake-share-${createdAt.microsecondsSinceEpoch}',
      kind: CaptureAssetKind.share,
      displayName: 'Shared web note sample',
      mimeType: 'text/uri-list',
      sourceUri: 'fake://share-sheet/example-link',
      previewText: 'Shared link: https://example.test/widenote',
      rawMetadata: const <String, Object?>{
        'adapter': 'fake_share',
        'url': 'https://example.test/widenote',
        'title': 'Shared web note sample',
      },
      createdAt: createdAt,
    );
  }
}

DateTime _defaultFakeNow() => DateTime.now().toUtc();
