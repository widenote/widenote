import 'dart:typed_data';

enum TranscriptStatus {
  pending('pending'),
  transcribing('transcribing'),
  active('active'),
  failed('failed'),
  noSpeech('no_speech'),
  needsReview('needs_review'),
  invalidated('invalidated');

  const TranscriptStatus(this.wireName);

  final String wireName;
}

enum TranscriptionProviderKind {
  localSenseVoice('local_sensevoice'),
  mimoAsr('mimo_asr'),
  disabled('disabled'),
  fake('fake');

  const TranscriptionProviderKind(this.wireName);

  final String wireName;
}

enum TranscriptionFailureCode {
  providerDisabled('provider_disabled'),
  modelMissing('model_missing'),
  modelCorrupted('model_corrupted'),
  modelInitFailed('model_init_failed'),
  unsupportedAudio('unsupported_audio'),
  noSpeech('no_speech'),
  streamUnavailable('stream_unavailable'),
  remoteDisabled('remote_disabled'),
  remoteCredentialMissing('remote_credential_missing'),
  remoteSizeLimit('remote_size_limit'),
  authentication('authentication'),
  rateLimited('rate_limited'),
  timeout('timeout'),
  server('server'),
  malformedResponse('malformed_response'),
  network('network'),
  unknown('unknown');

  const TranscriptionFailureCode(this.wireName);

  final String wireName;
}

final class TranscriptionException implements Exception {
  const TranscriptionException({
    required this.code,
    required this.message,
    this.cause,
  });

  final TranscriptionFailureCode code;
  final String message;
  final Object? cause;

  @override
  String toString() {
    return 'TranscriptionException(${code.wireName}): $message';
  }
}

final class AudioAttachmentRef {
  const AudioAttachmentRef({
    required this.id,
    required this.captureId,
    required this.storagePath,
    required this.mimeType,
    required this.sha256,
    required this.byteLength,
    required this.durationMs,
    required this.localPath,
  });

  final String id;
  final String captureId;
  final String storagePath;
  final String mimeType;
  final String sha256;
  final int byteLength;
  final int durationMs;
  final String localPath;

  bool get isWav => mimeType == 'audio/wav' || localPath.endsWith('.wav');
}

final class TranscriptSegment {
  const TranscriptSegment({
    required this.id,
    required this.text,
    required this.startMs,
    required this.endMs,
    this.confidence,
  });

  final String id;
  final String text;
  final int startMs;
  final int endMs;
  final double? confidence;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'text': text,
      'start_ms': startMs,
      'end_ms': endMs,
      if (confidence != null) 'confidence': confidence,
    };
  }
}

final class TranscriptionPreview {
  const TranscriptionPreview({
    this.confirmedText = '',
    this.pendingText = '',
    this.status = TranscriptStatus.pending,
    this.errorCode,
  });

  final String confirmedText;
  final String pendingText;
  final TranscriptStatus status;
  final TranscriptionFailureCode? errorCode;

  String get displayText {
    final parts = <String>[
      if (confirmedText.trim().isNotEmpty) confirmedText.trim(),
      if (pendingText.trim().isNotEmpty) pendingText.trim(),
    ];
    return parts.join(' ');
  }

  bool get hasText => displayText.trim().isNotEmpty;
}

final class TranscriptionOptions {
  const TranscriptionOptions({
    this.language = 'auto',
    this.allowRemoteFallback = true,
    this.manualRemoteRetry = false,
  });

  final String language;
  final bool allowRemoteFallback;
  final bool manualRemoteRetry;
}

final class AudioPcmChunk {
  const AudioPcmChunk({
    required this.bytes,
    required this.sampleRate,
    required this.channels,
  });

  final Uint8List bytes;
  final int sampleRate;
  final int channels;
}

final class TranscriptionResult {
  const TranscriptionResult({
    required this.text,
    required this.status,
    required this.providerId,
    required this.providerKind,
    required this.model,
    required this.durationMs,
    this.segments = const <TranscriptSegment>[],
    this.confidence,
    this.language = 'auto',
    this.rawAsrText,
    this.chunkCount = 1,
    this.errorCode,
    this.errorMessageSafe,
    this.metadata = const <String, Object?>{},
  });

  final String text;
  final TranscriptStatus status;
  final String providerId;
  final TranscriptionProviderKind providerKind;
  final String model;
  final int durationMs;
  final List<TranscriptSegment> segments;
  final double? confidence;
  final String language;
  final String? rawAsrText;
  final int chunkCount;
  final TranscriptionFailureCode? errorCode;
  final String? errorMessageSafe;
  final Map<String, Object?> metadata;

  Map<String, Object?> toPayload({
    required String sourceAttachmentSha256,
    required String correctionStatus,
    List<Object?> correctionPatches = const <Object?>[],
  }) {
    return <String, Object?>{
      'transcript_status': status.wireName,
      'language': language,
      'segments': segments.map((segment) => segment.toJson()).toList(),
      'provider_id': providerId,
      'provider_kind': providerKind.wireName,
      'model': model,
      'duration_ms': durationMs,
      'chunk_count': chunkCount,
      if (confidence != null) 'confidence': confidence,
      if (rawAsrText != null) 'raw_asr_text': rawAsrText,
      'correction_status': correctionStatus,
      'correction_patches': correctionPatches,
      if (errorCode != null) 'error_code': errorCode!.wireName,
      if (errorMessageSafe != null) 'error_message_safe': errorMessageSafe,
      'source_attachment_sha256': sourceAttachmentSha256,
      ...metadata,
    };
  }
}

abstract interface class AudioTranscriptionProvider {
  String get id;

  String get displayName;

  TranscriptionProviderKind get kind;

  bool get supportsFileTranscription;

  bool get supportsStreamingPreview;

  bool get supportsRemoteUpload;

  Future<void> prepare();

  Future<TranscriptionResult> transcribeAttachment(
    AudioAttachmentRef attachment, {
    TranscriptionOptions options = const TranscriptionOptions(),
  });

  Stream<TranscriptionPreview> transcribeSamples(
    Stream<AudioPcmChunk> samples, {
    TranscriptionOptions options = const TranscriptionOptions(),
  });

  Future<void> dispose();
}
