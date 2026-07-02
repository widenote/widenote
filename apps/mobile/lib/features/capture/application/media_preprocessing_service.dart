import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart' as localdb;

import '../../../app/local_database.dart';
import '../../../app/model_client.dart';
import '../domain/capture_models.dart';
import '../media/capture_media.dart';

final mediaPreprocessingServiceProvider = Provider<MediaPreprocessingService>((
  ref,
) {
  return MediaPreprocessingService(
    database: ref.watch(localDatabaseProvider),
    modelClient: ref.watch(visionModelClientProvider),
  );
});

final class CaptureMediaSemanticAgent {
  const CaptureMediaSemanticAgent({required runtime.ModelClient modelClient})
    : _modelClient = modelClient;

  static const generatorId = 'capture.media.semantic_agent';
  static const generatorVersion = '1.0.0';

  final runtime.ModelClient _modelClient;

  Future<runtime.ModelResponse> analyzeImage({
    required String captureId,
    required String attachmentId,
    required String attachmentKind,
    required String mimeType,
    required Uint8List imageBytes,
    required Map<String, Object?> uploadPayload,
  }) {
    return _modelClient.complete(
      runtime.ModelRequest(
        prompt: _imagePreprocessingPrompt,
        context: <String, Object?>{
          'feature': 'capture.media_semantic_agent',
          'agent_id': generatorId,
          'capture_id': captureId,
          'attachment_id': attachmentId,
          'attachment_kind': attachmentKind,
          'mime_type': mimeType,
          'prompt_version': _imagePreprocessingPromptVersion,
          'image_upload': uploadPayload,
          'source_ref': <String, Object?>{
            'kind': 'capture_attachment',
            'id': attachmentId,
          },
        },
        attachments: <runtime.ModelRequestAttachment>[
          runtime.ModelRequestAttachment.inlineImage(
            mimeType: mimeType,
            dataBase64: base64Encode(imageBytes),
            sourceRef: <String, Object?>{
              'kind': 'capture_attachment',
              'id': attachmentId,
            },
          ),
        ],
      ),
    );
  }
}

final class MediaPreprocessingService {
  MediaPreprocessingService({
    required localdb.WideNoteLocalDatabase database,
    required runtime.ModelClient modelClient,
    CaptureMediaSemanticAgent? semanticAgent,
    int maxDirectUploadBytes = _defaultMaxDirectUploadBytes,
    int maxResizedUploadBytes = _defaultMaxResizedUploadBytes,
    int maxImageDimension = _defaultMaxImageDimension,
  }) : _database = database,
       _semanticAgent =
           semanticAgent ?? CaptureMediaSemanticAgent(modelClient: modelClient),
       _maxDirectUploadBytes = maxDirectUploadBytes,
       _maxResizedUploadBytes = maxResizedUploadBytes,
       _maxImageDimension = maxImageDimension;

  final localdb.WideNoteLocalDatabase _database;
  final CaptureMediaSemanticAgent _semanticAgent;
  final int _maxDirectUploadBytes;
  final int _maxResizedUploadBytes;
  final int _maxImageDimension;

  Future<List<CaptureAttachment>> preprocessPhotoAttachments(
    CaptureRecord record,
    List<CaptureAttachment> attachments,
  ) async {
    if (!attachments.any(_shouldPreprocess)) {
      return attachments;
    }
    final updated = <CaptureAttachment>[];
    for (final attachment in attachments) {
      if (!_shouldPreprocess(attachment)) {
        updated.add(attachment);
        continue;
      }
      updated.add(await _preprocessPhoto(record, attachment));
    }
    return List<CaptureAttachment>.unmodifiable(updated);
  }

  bool _shouldPreprocess(CaptureAttachment attachment) {
    return attachment.kind == CaptureAssetKind.photo &&
        attachment.isReady &&
        attachment.rawMetadata['image_preprocessing_status'] != 'active' &&
        _localPath(attachment) != null;
  }

  Future<CaptureAttachment> _preprocessPhoto(
    CaptureRecord record,
    CaptureAttachment attachment,
  ) async {
    try {
      final path = _localPath(attachment);
      if (path == null) {
        return _markFailed(
          record,
          attachment,
          reason: 'missing_local_image_path',
        );
      }
      final file = File(path);
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return _markFailed(record, attachment, reason: 'empty_image_file');
      }
      final prepared = await _prepareImageForUpload(
        bytes,
        mimeType: attachment.mimeType,
      );

      final response = await _semanticAgent.analyzeImage(
        captureId: record.id,
        attachmentId: attachment.id,
        attachmentKind: attachment.kind.wireName,
        mimeType: prepared.mimeType,
        imageBytes: prepared.bytes,
        uploadPayload: prepared.toPayload(redacted: true),
      );
      final output = _parseOutput(response.text);
      return _markReady(record, attachment, output, response.raw, prepared);
    } on ModelUnavailableException catch (error) {
      return _markFailed(
        record,
        attachment,
        reason: 'no_vision_provider',
        cause: error,
      );
    } catch (error) {
      return _markFailed(
        record,
        attachment,
        reason: 'image_preprocessing_failed',
        cause: error,
      );
    }
  }

  CaptureAttachment _markReady(
    CaptureRecord record,
    CaptureAttachment attachment,
    _ImagePreprocessingOutput output,
    Map<String, Object?> responseRaw,
    _PreparedImage prepared,
  ) {
    final summary = output.visionSummary.trim().isEmpty
        ? 'Image analyzed; no salient visual summary was returned.'
        : output.visionSummary.trim();
    final ocrText = output.ocrText.trim();
    final ocrBody = ocrText.isEmpty ? 'No visible text detected.' : ocrText;
    final artifacts = <AttachmentDerivedArtifact>[
      AttachmentDerivedArtifact(
        id: _artifactId(record.id, attachment.id, 'vision_summary'),
        artifactKind: 'vision_summary',
        status: AttachmentDerivedArtifactStatus.ready,
        sourceLabel: 'source: capture_attachment:${attachment.id}',
        excerpt: _excerpt(summary),
      ),
      AttachmentDerivedArtifact(
        id: _artifactId(record.id, attachment.id, 'ocr_text'),
        artifactKind: 'ocr_text',
        status: AttachmentDerivedArtifactStatus.ready,
        sourceLabel: 'source: capture_attachment:${attachment.id}',
        excerpt: _excerpt(ocrBody),
      ),
    ];
    final updated = attachment.copyWith(
      derivedArtifacts: _mergeArtifacts(attachment.derivedArtifacts, artifacts),
      rawMetadata: <String, Object?>{
        ...attachment.rawMetadata,
        'vision_summary': summary,
        'vision_status': 'active',
        'ocr_text': ocrText,
        'ocr_status': 'active',
        'image_labels': output.labels,
        if (output.confidence != null) 'image_confidence': output.confidence,
        'image_preprocessing_status': 'active',
        if (responseRaw['provider_id'] is String)
          'image_preprocessing_provider_id': responseRaw['provider_id'],
        if (responseRaw['model'] is String)
          'image_preprocessing_model': responseRaw['model'],
        'image_preprocessing_prompt_version': _imagePreprocessingPromptVersion,
        'image_preprocessing_agent_id': CaptureMediaSemanticAgent.generatorId,
        'image_upload_mime_type': prepared.mimeType,
        'image_upload_byte_length': prepared.bytes.length,
        'image_upload_resize': prepared.resize,
      },
    );
    _saveArtifact(
      record: record,
      attachment: updated,
      artifactKind: 'vision_summary',
      status: 'active',
      title: 'Image attachment summary',
      body: summary,
      confidence: output.confidence ?? 'medium',
      payload: <String, Object?>{
        'artifact_status': 'ready',
        'source_label': 'source: capture_attachment:${attachment.id}',
        'labels': output.labels,
        'source_sha256': _sourceSha256(attachment),
        'derived_by': _derivedBy(responseRaw, prepared),
      },
    );
    _saveArtifact(
      record: record,
      attachment: updated,
      artifactKind: 'ocr_text',
      status: 'active',
      title: ocrText.isEmpty ? 'Image OCR result' : 'Image OCR text',
      body: ocrBody,
      confidence: ocrText.isEmpty ? 'low' : output.confidence ?? 'medium',
      payload: <String, Object?>{
        'artifact_status': 'ready',
        'source_label': 'source: capture_attachment:${attachment.id}',
        if (ocrText.isEmpty) 'empty_reason': 'no_visible_text',
        'source_sha256': _sourceSha256(attachment),
        'derived_by': _derivedBy(responseRaw, prepared),
      },
    );
    return updated;
  }

  CaptureAttachment _markFailed(
    CaptureRecord record,
    CaptureAttachment attachment, {
    required String reason,
    Object? cause,
  }) {
    final message = 'Image preprocessing failed: $reason.';
    final artifacts = <AttachmentDerivedArtifact>[
      AttachmentDerivedArtifact(
        id: _artifactId(record.id, attachment.id, 'vision_summary'),
        artifactKind: 'vision_summary',
        status: AttachmentDerivedArtifactStatus.failed,
        sourceLabel: 'source: capture_attachment:${attachment.id}',
        excerpt: message,
        reason: reason,
      ),
      AttachmentDerivedArtifact(
        id: _artifactId(record.id, attachment.id, 'ocr_text'),
        artifactKind: 'ocr_text',
        status: AttachmentDerivedArtifactStatus.failed,
        sourceLabel: 'source: capture_attachment:${attachment.id}',
        excerpt: message,
        reason: reason,
      ),
    ];
    final updated = attachment.copyWith(
      derivedArtifacts: _mergeArtifacts(attachment.derivedArtifacts, artifacts),
      rawMetadata: <String, Object?>{
        ...attachment.rawMetadata,
        'vision_status': 'failed',
        'ocr_status': 'failed',
        'image_preprocessing_status': 'failed',
        'image_preprocessing_error': reason,
        'image_preprocessing_prompt_version': _imagePreprocessingPromptVersion,
        'image_preprocessing_agent_id': CaptureMediaSemanticAgent.generatorId,
      },
    );
    for (final artifact in artifacts) {
      _saveArtifact(
        record: record,
        attachment: updated,
        artifactKind: artifact.artifactKind,
        status: 'failed',
        title: artifact.artifactKind == 'vision_summary'
            ? 'Image attachment summary failed'
            : 'Image OCR failed',
        body: message,
        confidence: 'low',
        payload: <String, Object?>{
          'artifact_status': artifact.status.wireName,
          'source_label': artifact.sourceLabel,
          'reason': reason,
          'source_sha256': _sourceSha256(attachment),
          'derived_by': _derivedBy(const <String, Object?>{}, null),
          if (cause != null) 'error_type': cause.runtimeType.toString(),
        },
      );
    }
    return updated;
  }

  void _saveArtifact({
    required CaptureRecord record,
    required CaptureAttachment attachment,
    required String artifactKind,
    required String status,
    required String title,
    required String body,
    required String confidence,
    required Map<String, Object?> payload,
  }) {
    final now = DateTime.now().toUtc();
    _database.derivedArtifacts.save(
      localdb.DerivedArtifactRecord(
        id: _artifactId(record.id, attachment.id, artifactKind),
        sourceCaptureId: record.id,
        sourceAttachmentId: attachment.id,
        sourceEventId: record.sourceEventId,
        artifactKind: artifactKind,
        status: status,
        title: title,
        body: body,
        mimeType: attachment.mimeType,
        storagePath: attachment.sourceUri,
        contentHash: _stableContentHash(<String, Object?>{
          'capture_id': record.id,
          'attachment_id': attachment.id,
          'artifact_kind': artifactKind,
          'status': status,
          'body': body,
        }),
        sourceRefs: <Object?>[
          <String, Object?>{
            'kind': 'capture',
            'id': record.id,
            'excerpt': _excerpt(record.body),
          },
          <String, Object?>{
            'kind': 'attachment',
            'id': attachment.id,
            'excerpt': _excerpt(attachment.previewText),
          },
          if (record.sourceEventId != null)
            <String, Object?>{'kind': 'event', 'id': record.sourceEventId},
        ],
        sensitivity: 'low',
        confidence: confidence,
        generatorId: CaptureMediaSemanticAgent.generatorId,
        generatorVersion: CaptureMediaSemanticAgent.generatorVersion,
        payload: <String, Object?>{
          ...payload,
          'attachment_kind': attachment.kind.wireName,
          'attachment_state': attachment.state.wireName,
          'display_name': attachment.displayName,
        },
        createdAt: attachment.createdAt.toUtc(),
        updatedAt: now,
      ),
    );
  }

  Future<_PreparedImage> _prepareImageForUpload(
    Uint8List bytes, {
    required String mimeType,
  }) async {
    if (bytes.length <= _maxDirectUploadBytes && _isModelImageMime(mimeType)) {
      return _PreparedImage(
        bytes: bytes,
        mimeType: mimeType,
        resize: 'original',
        originalByteLength: bytes.length,
      );
    }

    final descriptor = await _imageDescriptor(bytes);
    final scale = _resizeScale(
      width: descriptor.width,
      height: descriptor.height,
      maxDimension: _maxImageDimension,
    );
    final targetWidth = (descriptor.width * scale)
        .round()
        .clamp(1, descriptor.width)
        .toInt();
    final targetHeight = (descriptor.height * scale)
        .round()
        .clamp(1, descriptor.height)
        .toInt();
    final codec = await descriptor.instantiateCodec(
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    try {
      final frame = await codec.getNextFrame();
      try {
        final data = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (data == null) {
          throw const FormatException('Unable to encode resized image.');
        }
        final resized = data.buffer.asUint8List();
        if (resized.length > _maxResizedUploadBytes) {
          throw const FormatException('Resized image is too large to upload.');
        }
        return _PreparedImage(
          bytes: Uint8List.fromList(resized),
          mimeType: 'image/png',
          resize:
              targetWidth == descriptor.width &&
                  targetHeight == descriptor.height
              ? 'reencoded_png'
              : 'long_edge_${_maxImageDimension}_png',
          originalByteLength: bytes.length,
          width: targetWidth,
          height: targetHeight,
        );
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
      descriptor.dispose();
    }
  }
}

const _imagePreprocessingPromptVersion = '2026-07-02.v1';
const _defaultMaxDirectUploadBytes = 1024 * 1024;
const _defaultMaxResizedUploadBytes = 2 * 1024 * 1024;
const _defaultMaxImageDimension = 1536;

const _imagePreprocessingPrompt = '''
Analyze the attached image for WideNote capture preprocessing.
Return strict JSON only, with these keys:
- "vision_summary": one concise factual summary of what is visible.
- "ocr_text": visible text transcribed from the image, or an empty string.
- "labels": a short array of factual visual labels.
- "confidence": one of "low", "medium", or "high".
Do not invent details that are not visible.
''';

Future<ui.ImageDescriptor> _imageDescriptor(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    return await ui.ImageDescriptor.encoded(buffer);
  } catch (_) {
    rethrow;
  } finally {
    buffer.dispose();
  }
}

double _resizeScale({
  required int width,
  required int height,
  required int maxDimension,
}) {
  final longEdge = width > height ? width : height;
  if (longEdge <= maxDimension) {
    return 1;
  }
  return maxDimension / longEdge;
}

bool _isModelImageMime(String value) {
  return switch (value.toLowerCase()) {
    'image/jpeg' || 'image/png' || 'image/webp' || 'image/gif' => true,
    _ => false,
  };
}

String? _sourceSha256(CaptureAttachment attachment) {
  return _metadataString(attachment.rawMetadata, 'sha256');
}

Map<String, Object?> _derivedBy(
  Map<String, Object?> responseRaw,
  _PreparedImage? prepared,
) {
  return <String, Object?>{
    'agent_id': CaptureMediaSemanticAgent.generatorId,
    'agent_version': CaptureMediaSemanticAgent.generatorVersion,
    'prompt_version': _imagePreprocessingPromptVersion,
    if (responseRaw['provider_id'] is String)
      'provider_id': responseRaw['provider_id'],
    if (responseRaw['model'] is String) 'model': responseRaw['model'],
    if (prepared != null) 'image_upload': prepared.toPayload(redacted: true),
  };
}

_ImagePreprocessingOutput _parseOutput(String text) {
  final jsonObject = _decodeJsonObject(text);
  if (jsonObject == null) {
    throw const FormatException('Image preprocessing response was not JSON.');
  }
  return _ImagePreprocessingOutput(
    visionSummary: _string(jsonObject['vision_summary']) ?? '',
    ocrText: _string(jsonObject['ocr_text']) ?? '',
    labels: _stringList(jsonObject['labels']),
    confidence: _normalizedConfidence(_string(jsonObject['confidence'])),
  );
}

Map<String, Object?>? _decodeJsonObject(String text) {
  final trimmed = text.trim();
  for (final candidate in <String>[
    trimmed,
    _stripCodeFence(trimmed),
    _bracedSubstring(trimmed),
  ]) {
    if (candidate.trim().isEmpty) {
      continue;
    }
    try {
      final decoded = jsonDecode(candidate);
      if (decoded is Map) {
        return decoded.cast<String, Object?>();
      }
    } on FormatException {
      continue;
    }
  }
  return null;
}

String _stripCodeFence(String text) {
  final match = RegExp(
    r'^```(?:json)?\s*([\s\S]*?)\s*```$',
    caseSensitive: false,
  ).firstMatch(text);
  return match?.group(1) ?? text;
}

String _bracedSubstring(String text) {
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start < 0 || end <= start) {
    return '';
  }
  return text.substring(start, end + 1);
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String? _normalizedConfidence(String? value) {
  return switch (value?.toLowerCase()) {
    'low' || 'medium' || 'high' => value!.toLowerCase(),
    _ => null,
  };
}

List<AttachmentDerivedArtifact> _mergeArtifacts(
  List<AttachmentDerivedArtifact> current,
  List<AttachmentDerivedArtifact> incoming,
) {
  final replacementKinds = incoming
      .map((artifact) => artifact.artifactKind)
      .toSet();
  return <AttachmentDerivedArtifact>[
    for (final artifact in current)
      if (!replacementKinds.contains(artifact.artifactKind)) artifact,
    ...incoming,
  ];
}

String? _localPath(CaptureAttachment attachment) {
  final value =
      _metadataString(attachment.rawMetadata, 'local_path') ??
      _metadataString(attachment.rawMetadata, 'storage_ref');
  if (value == null) {
    return null;
  }
  if (value.startsWith('file://')) {
    return Uri.parse(value).toFilePath();
  }
  return value;
}

String? _metadataString(Map<String, Object?> metadata, String key) {
  return _string(metadata[key]) ?? _string(_nestedMetadata(metadata)[key]);
}

Map<String, Object?> _nestedMetadata(Map<String, Object?> metadata) {
  final nested = metadata['adapter_metadata'];
  if (nested is Map) {
    return nested.cast<String, Object?>();
  }
  return const <String, Object?>{};
}

String? _string(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

String _artifactId(String captureId, String attachmentId, String artifactKind) {
  return 'artifact.${_safeId(captureId)}.${_safeId(attachmentId)}.$artifactKind';
}

String _safeId(String value) {
  return value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_');
}

String _stableContentHash(Map<String, Object?> value) {
  return sha256.convert(utf8.encode(jsonEncode(value))).toString();
}

String _excerpt(String value) {
  final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.length <= 240) {
    return text;
  }
  return '${text.substring(0, 237)}...';
}

final class _ImagePreprocessingOutput {
  const _ImagePreprocessingOutput({
    required this.visionSummary,
    required this.ocrText,
    required this.labels,
    this.confidence,
  });

  final String visionSummary;
  final String ocrText;
  final List<String> labels;
  final String? confidence;
}

final class _PreparedImage {
  const _PreparedImage({
    required this.bytes,
    required this.mimeType,
    required this.resize,
    required this.originalByteLength,
    this.width,
    this.height,
  });

  final Uint8List bytes;
  final String mimeType;
  final String resize;
  final int originalByteLength;
  final int? width;
  final int? height;

  Map<String, Object?> toPayload({required bool redacted}) {
    return <String, Object?>{
      'mime_type': mimeType,
      'resize': resize,
      'original_byte_length': originalByteLength,
      'upload_byte_length': bytes.length,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (redacted) 'bytes': 'not_included',
    };
  }
}
