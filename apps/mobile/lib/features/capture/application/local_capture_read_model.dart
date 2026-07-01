import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:widenote_local_db/widenote_local_db.dart' as localdb;

import '../domain/capture_models.dart';
import '../media/capture_media.dart';
import '../../location/domain/location_context.dart';

final class LocalCaptureReadModelStore {
  const LocalCaptureReadModelStore(this._database);

  final localdb.WideNoteLocalDatabase _database;

  CaptureState hydrate() {
    return CaptureState(
      records: _database.captures.readAll().reversed.map(_captureView).toList(),
      memories: _database.memoryItems
          .readAll(status: 'active')
          .where((record) => !record.tombstone)
          .toList()
          .reversed
          .map(_memoryView)
          .toList(),
      reviewCandidates: _database.memoryCandidates
          .readAll(status: 'needs_review')
          .reversed
          .map(_reviewCandidateView)
          .toList(),
      cards: _database.cards
          .readAll(status: 'active')
          .reversed
          .map(_cardView)
          .toList(),
      insights: _database.insights
          .readAll(status: 'active')
          .reversed
          .map(_insightView)
          .toList(),
      todos: _database.todos.readAll().reversed.map(_todoView).toList(),
      traces: _database.traceEvents.readAll().reversed.map(_traceView).toList(),
      isProcessing: false,
      errorMessage: null,
    );
  }

  void saveCapture(
    CaptureRecord record, {
    required List<CaptureAttachment> attachments,
  }) {
    _database.captures.save(_captureRecord(record, attachments));
    for (final attachment in attachments) {
      _database.attachments.save(_attachmentRecord(record, attachment));
      for (final artifact in _attachmentArtifacts(record, attachment)) {
        if (_shouldPreserveExistingArtifact(artifact)) {
          continue;
        }
        _database.derivedArtifacts.save(artifact);
      }
    }
  }

  void saveTodo(SourceTodo todo) {
    if (!todo.isSuggested) {
      return;
    }
    _database.todos.save(
      localdb.TodoRecord(
        id: todo.id,
        sourceCaptureId: todo.sourceCaptureId ?? _sourceId(todo.sourceLabel),
        sourceEventId: todo.sourceEventId,
        status: _todoStatus(todo.statusLabel),
        payload: <String, Object?>{
          'title': todo.title,
          'source_label': todo.sourceLabel,
          'status_label': todo.statusLabel,
        },
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  bool _shouldPreserveExistingArtifact(localdb.DerivedArtifactRecord artifact) {
    if (artifact.artifactKind != 'audio_transcript') {
      return false;
    }
    final existing = _database.derivedArtifacts.readById(artifact.id);
    if (existing == null || existing.status != 'active') {
      return false;
    }
    return existing.payload['provider_id'] is String;
  }
}

localdb.CaptureRecord _captureRecord(
  CaptureRecord record,
  List<CaptureAttachment> attachments,
) {
  return localdb.CaptureRecord(
    id: record.id,
    sourceType: attachments.isEmpty ? 'manual' : 'manual_with_attachments',
    sourceId: record.sourceEventId,
    status: record.status,
    payload: <String, Object?>{
      'text': record.body,
      if (record.sourceEventId != null) 'source_event_id': record.sourceEventId,
      if (record.locationContext != null)
        'location_context': record.locationContext!.toJson(),
      if (record.locationContext != null)
        'fact_metadata': <String, Object?>{
          'location': record.locationContext!.toFactMetadata(
            sourceCaptureId: record.id,
            sourceEventId: record.sourceEventId,
          ),
        },
      if (attachments.isNotEmpty)
        'attachments': attachments
            .map((attachment) => attachment.toEventPayload())
            .toList(growable: false),
      'attachment_count': attachments.length,
      'modalities': <String>[
        if (record.body.trim().isNotEmpty) 'text',
        for (final attachment in attachments) attachment.kind.wireName,
      ],
    },
    createdAt: record.createdAt,
    updatedAt: DateTime.now().toUtc(),
  );
}

localdb.AttachmentRecord _attachmentRecord(
  CaptureRecord record,
  CaptureAttachment attachment,
) {
  final sha256 = _attachmentSha256(attachment.rawMetadata);
  return localdb.AttachmentRecord(
    id: attachment.id,
    captureId: record.id,
    sourceEventId: record.sourceEventId,
    assetKind: attachment.kind.wireName,
    mimeType: attachment.mimeType,
    storagePath: attachment.sourceUri,
    originalFileName: attachment.displayName,
    sha256: sha256,
    byteLength: attachment.sizeBytes,
    status: attachment.state.wireName,
    payload: <String, Object?>{
      'preview_text': attachment.canRenderPreview
          ? attachment.previewText
          : 'preview_hidden',
      if (attachment.reviewReason != null)
        'review_reason': attachment.reviewReason,
      'raw_metadata': attachment.rawMetadata,
    },
    createdAt: attachment.createdAt,
    updatedAt: DateTime.now().toUtc(),
  );
}

List<localdb.DerivedArtifactRecord> _attachmentArtifacts(
  CaptureRecord record,
  CaptureAttachment attachment,
) {
  if (attachment.derivedArtifacts.isNotEmpty) {
    return attachment.derivedArtifacts
        .where(
          (artifact) =>
              artifact.status != AttachmentDerivedArtifactStatus.blocked &&
              artifact.status != AttachmentDerivedArtifactStatus.needsReview,
        )
        .map(
          (artifact) => _artifactRecordFromView(
            record: record,
            attachment: attachment,
            artifact: artifact,
          ),
        )
        .toList(growable: false);
  }
  if (!attachment.canRenderPreview) {
    return const <localdb.DerivedArtifactRecord>[];
  }
  return switch (attachment.kind) {
    CaptureAssetKind.voice => <localdb.DerivedArtifactRecord>[
      _transcriptArtifact(record, attachment),
    ],
    CaptureAssetKind.photo => <localdb.DerivedArtifactRecord>[
      _visionSummaryArtifact(record, attachment),
      _ocrArtifact(record, attachment),
    ],
    CaptureAssetKind.share => <localdb.DerivedArtifactRecord>[
      _sharedTextArtifact(record, attachment),
    ],
  };
}

localdb.DerivedArtifactRecord _artifactRecordFromView({
  required CaptureRecord record,
  required CaptureAttachment attachment,
  required AttachmentDerivedArtifact artifact,
}) {
  final body =
      _nonEmpty(artifact.excerpt) ??
      _nonEmpty(attachment.previewText) ??
      '${artifact.artifactKind} pending for ${attachment.displayName}.';
  return _artifactRecord(
    record: record,
    attachment: attachment,
    artifactKind: artifact.artifactKind,
    status: _artifactRecordStatus(artifact.status),
    title: _artifactTitle(artifact),
    body: body,
    confidence: artifact.status == AttachmentDerivedArtifactStatus.ready
        ? 'medium'
        : 'low',
    generatorId: 'capture.media.${artifact.artifactKind}',
    generatorVersion: '1.0.0',
    payload: <String, Object?>{
      'artifact_status': artifact.status.wireName,
      'source_label': artifact.sourceLabel,
      if (artifact.reason != null) 'reason': artifact.reason,
    },
  );
}

localdb.DerivedArtifactRecord _transcriptArtifact(
  CaptureRecord record,
  CaptureAttachment attachment,
) {
  final transcript = _metadataText(attachment.rawMetadata, const <String>[
    'transcript',
    'transcript_text',
    'recognized_text',
    'speech_text',
  ]);
  final status = _transcriptStatus(transcript);
  final body =
      transcript ??
      _nonEmpty(attachment.previewText) ??
      'Transcript pending for ${attachment.displayName}.';
  return _artifactRecord(
    record: record,
    attachment: attachment,
    artifactKind: 'audio_transcript',
    status: status,
    title: status == 'active' ? 'Audio transcript' : 'Audio transcript pending',
    body: body,
    confidence: transcript == null ? 'low' : 'medium',
    generatorId: 'capture.media.transcript',
    generatorVersion: '1.0.0',
    payload: <String, Object?>{
      'transcript_status': status,
      if (transcript == null) 'pending_reason': 'no_transcript_text',
      'metadata_status':
          _metadataString(attachment.rawMetadata, 'transcript_status') ??
          'unknown',
    },
  );
}

localdb.DerivedArtifactRecord _visionSummaryArtifact(
  CaptureRecord record,
  CaptureAttachment attachment,
) {
  final preview =
      _nonEmpty(attachment.previewText) ??
      'Image attachment saved locally as ${attachment.displayName}.';
  final adapterMetadata = _nestedMetadata(attachment.rawMetadata);
  return _artifactRecord(
    record: record,
    attachment: attachment,
    artifactKind: 'vision_summary',
    status: 'active',
    title: 'Image attachment summary',
    body: preview,
    confidence:
        _metadataText(attachment.rawMetadata, const <String>[
              'vision_summary',
              'caption',
              'image_caption',
            ]) ==
            null
        ? 'low'
        : 'medium',
    generatorId: 'capture.media.vision_summary',
    generatorVersion: '1.0.0',
    payload: <String, Object?>{
      'source': _metadataString(attachment.rawMetadata, 'source'),
      if (adapterMetadata['width'] != null) 'width': adapterMetadata['width'],
      if (adapterMetadata['height'] != null)
        'height': adapterMetadata['height'],
      'ocr_status': _ocrStatus(attachment.rawMetadata),
    },
  );
}

localdb.DerivedArtifactRecord _ocrArtifact(
  CaptureRecord record,
  CaptureAttachment attachment,
) {
  final text = _metadataText(attachment.rawMetadata, const <String>[
    'ocr_text',
    'recognized_text',
    'image_text',
  ]);
  final status = text == null ? 'pending' : 'active';
  final body = text ?? 'OCR pending for ${attachment.displayName}.';
  return _artifactRecord(
    record: record,
    attachment: attachment,
    artifactKind: 'ocr_text',
    status: status,
    title: status == 'active' ? 'Image OCR text' : 'Image OCR pending',
    body: body,
    confidence: text == null ? 'low' : 'medium',
    generatorId: 'capture.media.ocr',
    generatorVersion: '1.0.0',
    payload: <String, Object?>{
      'ocr_status': status,
      if (text == null) 'pending_reason': 'no_ocr_text',
    },
  );
}

localdb.DerivedArtifactRecord _sharedTextArtifact(
  CaptureRecord record,
  CaptureAttachment attachment,
) {
  final text =
      _metadataText(attachment.rawMetadata, const <String>[
        'shared_text',
        'text',
        'body',
      ]) ??
      _nonEmpty(attachment.previewText) ??
      'Shared attachment saved locally as ${attachment.displayName}.';
  return _artifactRecord(
    record: record,
    attachment: attachment,
    artifactKind: 'shared_text',
    status: 'active',
    title: 'Shared attachment text',
    body: text,
    confidence: 'medium',
    generatorId: 'capture.media.share',
    generatorVersion: '1.0.0',
    payload: const <String, Object?>{'source': 'share'},
  );
}

localdb.DerivedArtifactRecord _artifactRecord({
  required CaptureRecord record,
  required CaptureAttachment attachment,
  required String artifactKind,
  required String status,
  required String title,
  required String body,
  required String confidence,
  required String generatorId,
  required String generatorVersion,
  required Map<String, Object?> payload,
}) {
  final now = DateTime.now().toUtc();
  final contentHash = _stableContentHash(<String, Object?>{
    'capture_id': record.id,
    'attachment_id': attachment.id,
    'artifact_kind': artifactKind,
    'status': status,
    'body': body,
  });
  final sourceRefs = <Object?>[
    <String, Object?>{
      'kind': 'capture',
      'id': record.id,
      if (record.sourceEventId != null) 'event_id': record.sourceEventId,
      'excerpt': _excerpt(record.body),
    },
    <String, Object?>{
      'kind': 'file',
      'id': attachment.id,
      if (record.sourceEventId != null) 'event_id': record.sourceEventId,
      'excerpt': _excerpt(attachment.previewText),
    },
  ];
  return localdb.DerivedArtifactRecord(
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
    contentHash: contentHash,
    sourceRefs: sourceRefs,
    sensitivity: attachment.kind == CaptureAssetKind.voice ? 'medium' : 'low',
    confidence: confidence,
    generatorId: generatorId,
    generatorVersion: generatorVersion,
    payload: <String, Object?>{
      ...payload,
      'attachment_kind': attachment.kind.wireName,
      'attachment_state': attachment.state.wireName,
      'display_name': attachment.displayName,
    },
    createdAt: attachment.createdAt.toUtc(),
    updatedAt: now,
  );
}

String _artifactRecordStatus(AttachmentDerivedArtifactStatus status) {
  return switch (status) {
    AttachmentDerivedArtifactStatus.ready => 'active',
    AttachmentDerivedArtifactStatus.pending => 'pending',
    AttachmentDerivedArtifactStatus.failed => 'failed',
    AttachmentDerivedArtifactStatus.blocked => 'blocked',
    AttachmentDerivedArtifactStatus.needsReview => 'needs_review',
  };
}

String _artifactTitle(AttachmentDerivedArtifact artifact) {
  return switch (artifact.artifactKind) {
    'audio_transcript' =>
      artifact.status == AttachmentDerivedArtifactStatus.ready
          ? 'Audio transcript'
          : 'Audio transcript pending',
    'vision_summary' => 'Image attachment summary',
    'ocr_text' =>
      artifact.status == AttachmentDerivedArtifactStatus.ready
          ? 'Image OCR text'
          : 'Image OCR pending',
    'shared_text' => 'Shared attachment text',
    _ => artifact.artifactKind,
  };
}

String _transcriptStatus(String? transcript) {
  if (transcript != null) {
    return 'active';
  }
  return 'pending';
}

String _ocrStatus(Map<String, Object?> metadata) {
  if (_metadataText(metadata, const <String>[
        'ocr_text',
        'recognized_text',
        'image_text',
      ]) !=
      null) {
    return 'active';
  }
  return _metadataString(metadata, 'ocr_status') ?? 'pending';
}

String? _attachmentSha256(Map<String, Object?> metadata) {
  final topLevel = _string(metadata['sha256']);
  if (topLevel != null) {
    return topLevel;
  }
  final adapterMetadata = metadata['adapter_metadata'];
  if (adapterMetadata is Map) {
    return _string(adapterMetadata['sha256']);
  }
  return null;
}

String? _metadataText(Map<String, Object?> metadata, List<String> keys) {
  for (final key in keys) {
    final text = _metadataString(metadata, key);
    if (text != null) {
      return text;
    }
  }
  final adapterMetadata = _nestedMetadata(metadata);
  for (final key in keys) {
    final text = _string(adapterMetadata[key]);
    if (text != null) {
      return text;
    }
  }
  return null;
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

String _artifactId(String captureId, String attachmentId, String artifactKind) {
  return 'artifact.${_safeId(captureId)}.${_safeId(attachmentId)}.$artifactKind';
}

String _stableContentHash(Map<String, Object?> value) {
  return sha256.convert(utf8.encode(jsonEncode(value))).toString();
}

String _safeId(String value) {
  return value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_');
}

String _excerpt(String value) {
  final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.length <= 120) {
    return text;
  }
  return '${text.substring(0, 117)}...';
}

CaptureRecord _captureView(localdb.CaptureRecord record) {
  final rawLocation = record.payload['location_context'];
  return CaptureRecord(
    id: record.id,
    body: _string(record.payload['text']) ?? '',
    createdAt: record.createdAt,
    status: record.status,
    sourceEventId:
        _string(record.payload['source_event_id']) ?? record.sourceId,
    locationContext: rawLocation is Map
        ? CapturedLocationContext.fromJson(rawLocation.cast<String, Object?>())
        : null,
  );
}

CaptureMemoryItem _memoryView(localdb.MemoryItemRecord record) {
  return CaptureMemoryItem(
    id: record.id,
    title: 'memory.accepted',
    summary: record.body,
    sourceRecordId: _sourceLabel(
      kind: 'memory',
      id: record.id,
      sourceCaptureId: record.sourceCaptureId,
      sourceEventId: record.sourceEventId,
    ),
    confidenceLabel: '${record.confidence} confidence',
    statusLabel: 'accepted',
    needsReview: false,
  );
}

MemoryReviewCandidate _reviewCandidateView(
  localdb.MemoryCandidateRecord record,
) {
  return MemoryReviewCandidate(
    id: record.id,
    summary: record.body,
    sourceLabel: _sourceLabel(
      kind: 'memory_candidate',
      id: record.id,
      sourceCaptureId: record.sourceCaptureId,
      sourceEventId: record.sourceEventId,
    ),
    reasonLabel: _stringList(record.payload['policy_reasons']).isEmpty
        ? 'needs review'
        : _stringList(record.payload['policy_reasons']).join(', '),
    typeLabel:
        '${record.memoryType} · ${record.confidence} confidence · '
        '${record.sensitivity} sensitivity',
  );
}

SourceCard _cardView(localdb.CardRecord record) {
  return SourceCard(
    id: record.id,
    title: record.title,
    summary: record.body,
    sourceLabel: _sourceRefsLabel(record.sourceRefs),
    kindLabel: _cardKindLabel(record.cardKind),
    statusLabel: '${record.sourceRefs.length} source link(s)',
  );
}

SourceInsight _insightView(localdb.InsightRecord record) {
  return SourceInsight(
    id: record.id,
    title: record.title,
    summary: record.summary,
    sourceLabel: _sourceRefsLabel(record.sourceRefs),
    kindLabel: _insightKindLabel(record.insightKind),
    metricLabel: record.metricLabel == null || record.metricValue == null
        ? 'source-linked'
        : '${record.metricValue} ${record.metricLabel}',
  );
}

SourceTodo _todoView(localdb.TodoRecord record) {
  final title =
      _string(record.payload['title']) ??
      _string(record.payload['text']) ??
      'Review capture';
  return SourceTodo(
    id: record.id,
    title: title,
    sourceLabel:
        _string(record.payload['source_label']) ??
        _sourceLabel(
          kind: 'todo',
          id: record.id,
          sourceCaptureId: record.sourceCaptureId,
          sourceEventId: record.sourceEventId,
          sourcePrefix: 'source',
        ),
    statusLabel: _string(record.payload['status_label']) ?? record.status,
    sourceCaptureId: record.sourceCaptureId,
    sourceEventId: record.sourceEventId,
  );
}

TraceEvent _traceView(localdb.TraceEventRecord record) {
  return TraceEvent(
    id: record.id,
    label: record.name,
    detail: record.message,
    sourceRecordId: record.sourceEventId ?? record.id,
    timeLabel: _timeLabel(record.createdAt.toLocal()),
    packId: record.packId,
    agentId: record.agentId,
    runId: record.runId,
  );
}

String _sourceRefsLabel(List<Object?> refs) {
  if (refs.isEmpty) {
    return 'source: unknown';
  }
  final first = refs.first;
  if (first is! Map) {
    return 'source: unknown';
  }
  final kind = _string(first['kind']) ?? _string(first['source_type']);
  final id = _string(first['id']) ?? _string(first['source_id']);
  if (kind == null || id == null) {
    return 'source: unknown';
  }
  final extra = refs.length == 1 ? '' : ' +${refs.length - 1}';
  return 'source: $kind:$id$extra';
}

String _sourceLabel({
  required String kind,
  required String id,
  String? sourceCaptureId,
  String? sourceEventId,
  String sourcePrefix = 'event',
}) {
  if (sourcePrefix == 'source' && sourceCaptureId != null) {
    return 'source: $sourceCaptureId';
  }
  if (sourceEventId != null) {
    return 'event: $sourceEventId';
  }
  if (sourceCaptureId != null) {
    return 'capture: $sourceCaptureId';
  }
  return '$kind: $id';
}

String? _sourceId(String sourceLabel) {
  if (!sourceLabel.startsWith('source: ')) {
    return null;
  }
  final id = sourceLabel.substring('source: '.length).trim();
  return id.isEmpty ? null : id;
}

String _cardKindLabel(String kind) {
  return switch (kind) {
    'capture_summary' => 'capture card',
    'memory_summary' => 'Memory card',
    _ => kind,
  };
}

String _insightKindLabel(String kind) {
  return switch (kind) {
    'summary' => 'summary insight',
    'count' => 'count insight',
    'trend' => 'trend insight',
    'source_mix' => 'source mix insight',
    'action_pattern' => 'action pattern insight',
    'attachment_evidence' => 'attachment evidence insight',
    _ => kind,
  };
}

String _todoStatus(String statusLabel) {
  return switch (statusLabel) {
    'completed' => 'completed',
    _ => 'open',
  };
}

String _timeLabel(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute local';
}

String? _string(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return null;
}

String? _nonEmpty(String value) {
  final text = value.trim();
  return text.isEmpty ? null : text;
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value.whereType<String>().toList(growable: false);
}
