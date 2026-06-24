import 'package:widenote_local_db/widenote_local_db.dart' as localdb;

import '../domain/capture_models.dart';
import '../media/capture_media.dart';

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
    }
  }

  void saveTodo(SourceTodo todo) {
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
  final sha256 = _string(attachment.rawMetadata['sha256']);
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

CaptureRecord _captureView(localdb.CaptureRecord record) {
  return CaptureRecord(
    id: record.id,
    body: _string(record.payload['text']) ?? '',
    createdAt: record.createdAt,
    status: record.status,
    sourceEventId:
        _string(record.payload['source_event_id']) ?? record.sourceId,
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

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value.whereType<String>().toList(growable: false);
}
