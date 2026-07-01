import 'dart:async';
import 'dart:typed_data';

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

enum AttachmentDerivedArtifactStatus {
  pending('pending'),
  ready('ready'),
  failed('failed'),
  blocked('blocked'),
  needsReview('needs_review');

  const AttachmentDerivedArtifactStatus(this.wireName);

  final String wireName;

  static AttachmentDerivedArtifactStatus fromWire(String? value) {
    return switch (value?.trim()) {
      'active' ||
      'accepted' ||
      'complete' ||
      'completed' ||
      'ready' ||
      'succeeded' => AttachmentDerivedArtifactStatus.ready,
      'blocked' || 'denied' => AttachmentDerivedArtifactStatus.blocked,
      'failed' || 'error' => AttachmentDerivedArtifactStatus.failed,
      'needs_review' ||
      'needsReview' ||
      'review' => AttachmentDerivedArtifactStatus.needsReview,
      'pending' ||
      'processing' ||
      'queued' ||
      'running' => AttachmentDerivedArtifactStatus.pending,
      _ => AttachmentDerivedArtifactStatus.pending,
    };
  }
}

final class AttachmentDerivedArtifact {
  const AttachmentDerivedArtifact({
    required this.artifactKind,
    required this.status,
    required this.sourceLabel,
    this.id,
    this.excerpt = '',
    this.reason,
  });

  factory AttachmentDerivedArtifact.fromPayload(Map<Object?, Object?> payload) {
    return AttachmentDerivedArtifact(
      id: _payloadString(payload['id']),
      artifactKind:
          _payloadString(payload['artifact_kind']) ??
          _payloadString(payload['kind']) ??
          'attachment_artifact',
      status: AttachmentDerivedArtifactStatus.fromWire(
        _payloadString(payload['status']),
      ),
      sourceLabel: _payloadString(payload['source_label']) ?? 'source: unknown',
      excerpt: _payloadString(payload['excerpt']) ?? '',
      reason: _payloadString(payload['reason']),
    );
  }

  final String? id;
  final String artifactKind;
  final AttachmentDerivedArtifactStatus status;
  final String sourceLabel;
  final String excerpt;
  final String? reason;

  Map<String, Object?> toPayload() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'artifact_kind': artifactKind,
      'status': status.wireName,
      'source_label': sourceLabel,
      if (excerpt.trim().isNotEmpty) 'excerpt': excerpt,
      if (reason != null) 'reason': reason,
    };
  }
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
    this.derivedArtifacts = const <AttachmentDerivedArtifact>[],
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
  final List<AttachmentDerivedArtifact> derivedArtifacts;
  final Map<String, Object?> rawMetadata;

  bool get canRenderPreview => state != CaptureAttachmentState.blocked;

  bool get isReady => state == CaptureAttachmentState.ready;

  CaptureAttachment copyWith({
    CaptureAttachmentState? state,
    String? previewText,
    String? reviewReason,
    List<AttachmentDerivedArtifact>? derivedArtifacts,
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
      derivedArtifacts: derivedArtifacts ?? this.derivedArtifacts,
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
      if (derivedArtifacts.isNotEmpty)
        'derived_artifacts': derivedArtifacts
            .map((artifact) => artifact.toPayload())
            .toList(growable: false),
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
      'audio/wav',
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
      derivedArtifacts: _derivedArtifactsFor(asset, decision),
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

List<AttachmentDerivedArtifact> _derivedArtifactsFor(
  RawCaptureAsset asset,
  AssetSafetyDecision decision,
) {
  if (decision.state == CaptureAttachmentState.blocked) {
    return <AttachmentDerivedArtifact>[
      AttachmentDerivedArtifact(
        artifactKind: _blockedArtifactKind(asset.kind),
        status: AttachmentDerivedArtifactStatus.blocked,
        sourceLabel: 'source: capture_attachment:${asset.id}',
        excerpt: 'Preview hidden until review.',
        reason: decision.reason,
      ),
    ];
  }
  if (decision.state == CaptureAttachmentState.needsReview) {
    return <AttachmentDerivedArtifact>[
      AttachmentDerivedArtifact(
        artifactKind: _reviewArtifactKind(asset.kind),
        status: AttachmentDerivedArtifactStatus.needsReview,
        sourceLabel: 'source: capture_attachment:${asset.id}',
        excerpt: _safeExcerpt(asset.previewText),
        reason: decision.reason,
      ),
    ];
  }

  return switch (asset.kind) {
    CaptureAssetKind.voice => <AttachmentDerivedArtifact>[
      AttachmentDerivedArtifact(
        artifactKind: 'audio_transcript',
        status: AttachmentDerivedArtifactStatus.fromWire(
          _metadataString(asset.rawMetadata, 'transcript_status'),
        ),
        sourceLabel: 'source: capture_attachment:${asset.id}',
        excerpt: _safeExcerpt(
          _metadataText(asset.rawMetadata, const <String>[
                'transcript',
                'transcript_text',
                'recognized_text',
                'speech_text',
              ]) ??
              asset.previewText,
        ),
      ),
    ],
    CaptureAssetKind.photo => <AttachmentDerivedArtifact>[
      AttachmentDerivedArtifact(
        artifactKind: 'vision_summary',
        status: AttachmentDerivedArtifactStatus.fromWire(
          _metadataString(asset.rawMetadata, 'vision_status') ?? 'ready',
        ),
        sourceLabel: 'source: capture_attachment:${asset.id}',
        excerpt: _safeExcerpt(
          _metadataText(asset.rawMetadata, const <String>[
                'vision_summary',
                'caption',
                'image_caption',
              ]) ??
              asset.previewText,
        ),
      ),
      AttachmentDerivedArtifact(
        artifactKind: 'ocr_text',
        status: _ocrArtifactStatus(asset.rawMetadata),
        sourceLabel: 'source: capture_attachment:${asset.id}',
        excerpt: _safeExcerpt(
          _metadataText(asset.rawMetadata, const <String>[
                'ocr_text',
                'recognized_text',
                'image_text',
              ]) ??
              'OCR pending for ${asset.displayName}.',
        ),
      ),
    ],
    CaptureAssetKind.share => <AttachmentDerivedArtifact>[
      AttachmentDerivedArtifact(
        artifactKind: 'shared_text',
        status: AttachmentDerivedArtifactStatus.fromWire(
          _metadataString(asset.rawMetadata, 'shared_text_status') ?? 'ready',
        ),
        sourceLabel: 'source: capture_attachment:${asset.id}',
        excerpt: _safeExcerpt(
          _metadataText(asset.rawMetadata, const <String>[
                'shared_text',
                'text',
                'body',
              ]) ??
              asset.previewText,
        ),
      ),
    ],
  };
}

AttachmentDerivedArtifactStatus _ocrArtifactStatus(
  Map<String, Object?> metadata,
) {
  final explicit = _metadataString(metadata, 'ocr_status');
  if (explicit != null) {
    return AttachmentDerivedArtifactStatus.fromWire(explicit);
  }
  final text = _metadataText(metadata, const <String>[
    'ocr_text',
    'recognized_text',
    'image_text',
  ]);
  return text == null
      ? AttachmentDerivedArtifactStatus.pending
      : AttachmentDerivedArtifactStatus.ready;
}

String _blockedArtifactKind(CaptureAssetKind kind) {
  return switch (kind) {
    CaptureAssetKind.photo => 'image_derivatives',
    CaptureAssetKind.voice => 'audio_transcript',
    CaptureAssetKind.share => 'shared_text',
  };
}

String _reviewArtifactKind(CaptureAssetKind kind) {
  return switch (kind) {
    CaptureAssetKind.photo => 'image_derivatives',
    CaptureAssetKind.voice => 'audio_transcript',
    CaptureAssetKind.share => 'shared_text',
  };
}

String? _metadataText(Map<String, Object?> metadata, List<String> keys) {
  for (final key in keys) {
    final value = _metadataString(metadata, key);
    if (value != null) {
      return value;
    }
  }
  return null;
}

String? _metadataString(Map<String, Object?> metadata, String key) {
  return _payloadString(metadata[key]) ??
      _payloadString(_nestedMetadata(metadata)[key]);
}

Map<String, Object?> _nestedMetadata(Map<String, Object?> metadata) {
  final nested = metadata['adapter_metadata'];
  if (nested is Map) {
    return nested.cast<String, Object?>();
  }
  return const <String, Object?>{};
}

String _safeExcerpt(String value) {
  final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty) {
    return '';
  }
  if (text.length <= 160) {
    return text;
  }
  return '${text.substring(0, 157)}...';
}

String? _payloadString(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
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
    this.pcmStream,
    this.sampleRate = 16000,
    this.numChannels = 1,
    this.usesStreamingSource = false,
    this.finalizeStreamingSource,
    this.cancelStreamingSource,
  });

  final String id;
  final String path;
  final DateTime startedAt;
  final Stream<Uint8List>? pcmStream;
  final int sampleRate;
  final int numChannels;
  final bool usesStreamingSource;
  final Future<void> Function()? finalizeStreamingSource;
  final Future<void> Function()? cancelStreamingSource;
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
        path: 'fake://microphone/voice-note.wav',
        startedAt: createdAt,
        pcmStream: Stream<Uint8List>.fromIterable(<Uint8List>[
          Uint8List.fromList(<int>[0, 0, 1, 0, 2, 0, 3, 0]),
        ]),
        usesStreamingSource: true,
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
      displayName: 'Voice recording sample.wav',
      mimeType: 'audio/wav',
      sourceUri: session.path,
      sizeBytes: 96000,
      previewText: 'Voice recording captured. Transcript pending.',
      rawMetadata: <String, Object?>{
        'adapter': 'fake_voice',
        'source': 'microphone',
        'audio_format': 'wav',
        'sample_rate': session.sampleRate,
        'num_channels': session.numChannels,
        'streaming_source': session.usesStreamingSource,
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
