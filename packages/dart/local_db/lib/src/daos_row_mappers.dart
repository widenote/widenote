part of 'daos.dart';

EventLogEntry _eventFromRow(Row row) {
  return EventLogEntry(
    id: _text(row, 'id'),
    type: _text(row, 'type'),
    schemaVersion: _integer(row, 'schema_version'),
    actor: _text(row, 'actor'),
    status: _text(row, 'status'),
    privacy: _text(row, 'privacy'),
    sourceCaptureId: _nullableText(row, 'source_capture_id'),
    sourceEventId: _nullableText(row, 'source_event_id'),
    subjectKind: _nullableText(row, 'subject_kind'),
    subjectId: _nullableText(row, 'subject_id'),
    subjectRef: decodeJsonMap(_text(row, 'subject_ref_json')),
    packId: _nullableText(row, 'pack_id'),
    agentId: _nullableText(row, 'agent_id'),
    deviceId: _nullableText(row, 'device_id'),
    causationId: _nullableText(row, 'causation_id'),
    correlationId: _nullableText(row, 'correlation_id'),
    payload: decodeJsonMap(_text(row, 'payload_json')),
    createdAt: _dateTime(row, 'created_at'),
  );
}

CaptureRecord _captureFromRow(Row row) {
  return CaptureRecord(
    id: _text(row, 'id'),
    schemaVersion: _integer(row, 'schema_version'),
    sourceType: _text(row, 'source_type'),
    sourceId: _nullableText(row, 'source_id'),
    status: _text(row, 'status'),
    payload: decodeJsonMap(_text(row, 'payload_json')),
    createdAt: _dateTime(row, 'created_at'),
    updatedAt: _dateTime(row, 'updated_at'),
  );
}

AttachmentRecord _attachmentFromRow(Row row) {
  return AttachmentRecord(
    id: _text(row, 'id'),
    schemaVersion: _integer(row, 'schema_version'),
    captureId: _text(row, 'capture_id'),
    sourceEventId: _nullableText(row, 'source_event_id'),
    assetKind: _text(row, 'asset_kind'),
    mimeType: _nullableText(row, 'mime_type'),
    storagePath: _text(row, 'storage_path'),
    originalFileName: _nullableText(row, 'original_file_name'),
    sha256: _nullableText(row, 'sha256'),
    byteLength: _nullableInt(row, 'byte_length'),
    status: _text(row, 'status'),
    payload: decodeJsonMap(_text(row, 'payload_json')),
    createdAt: _dateTime(row, 'created_at'),
    updatedAt: _dateTime(row, 'updated_at'),
  );
}

MemoryItemRecord _memoryItemFromRow(Row row) {
  return MemoryItemRecord(
    id: _text(row, 'id'),
    key: _text(row, 'memory_key'),
    schemaVersion: _integer(row, 'schema_version'),
    sourceCaptureId: _nullableText(row, 'source_capture_id'),
    sourceEventId: _nullableText(row, 'source_event_id'),
    status: _text(row, 'status'),
    body: _text(row, 'body'),
    sourceRefs: decodeJsonList(_text(row, 'source_refs_json')),
    memoryType: _text(row, 'memory_type'),
    confidence: _text(row, 'confidence'),
    sensitivity: _text(row, 'sensitivity'),
    revision: _integer(row, 'revision'),
    tombstone: _bool(row, 'tombstone'),
    payload: decodeJsonMap(_text(row, 'payload_json')),
    createdAt: _dateTime(row, 'created_at'),
    updatedAt: _dateTime(row, 'updated_at'),
  );
}

MemoryCandidateRecord _memoryCandidateFromRow(Row row) {
  return MemoryCandidateRecord(
    id: _text(row, 'id'),
    key: _text(row, 'candidate_key'),
    schemaVersion: _integer(row, 'schema_version'),
    sourceCaptureId: _nullableText(row, 'source_capture_id'),
    sourceEventId: _nullableText(row, 'source_event_id'),
    status: _text(row, 'status'),
    body: _text(row, 'body'),
    sourceRefs: decodeJsonList(_text(row, 'source_refs_json')),
    memoryType: _text(row, 'memory_type'),
    confidence: _text(row, 'confidence'),
    sensitivity: _text(row, 'sensitivity'),
    payload: decodeJsonMap(_text(row, 'payload_json')),
    createdAt: _dateTime(row, 'created_at'),
    updatedAt: _dateTime(row, 'updated_at'),
  );
}

CardRecord _cardFromRow(Row row) {
  return CardRecord(
    id: _text(row, 'id'),
    schemaVersion: _integer(row, 'schema_version'),
    cardKind: _text(row, 'card_kind'),
    status: _text(row, 'status'),
    title: _text(row, 'title'),
    body: _text(row, 'body'),
    sourceRefs: decodeJsonList(_text(row, 'source_refs_json')),
    payload: decodeJsonMap(_text(row, 'payload_json')),
    createdAt: _dateTime(row, 'created_at'),
    updatedAt: _dateTime(row, 'updated_at'),
  );
}

InsightRecord _insightFromRow(Row row) {
  return InsightRecord(
    id: _text(row, 'id'),
    schemaVersion: _integer(row, 'schema_version'),
    insightKind: _text(row, 'insight_kind'),
    status: _text(row, 'status'),
    title: _text(row, 'title'),
    summary: _text(row, 'summary'),
    sourceRefs: decodeJsonList(_text(row, 'source_refs_json')),
    metricLabel: _nullableText(row, 'metric_label'),
    metricValue: _nullableNum(row, 'metric_value'),
    payload: decodeJsonMap(_text(row, 'payload_json')),
    createdAt: _dateTime(row, 'created_at'),
    updatedAt: _dateTime(row, 'updated_at'),
  );
}

ChatSessionRecord _chatSessionFromRow(Row row) {
  return ChatSessionRecord(
    id: _text(row, 'id'),
    schemaVersion: _integer(row, 'schema_version'),
    title: _text(row, 'title'),
    status: _text(row, 'status'),
    payload: decodeJsonMap(_text(row, 'payload_json')),
    createdAt: _dateTime(row, 'created_at'),
    updatedAt: _dateTime(row, 'updated_at'),
  );
}

ChatMessageRecord _chatMessageFromRow(Row row) {
  return ChatMessageRecord(
    id: _text(row, 'id'),
    schemaVersion: _integer(row, 'schema_version'),
    sessionId: _text(row, 'session_id'),
    role: _text(row, 'role'),
    status: _text(row, 'status'),
    body: _text(row, 'body'),
    sourceRefs: decodeJsonList(_text(row, 'source_refs_json')),
    payload: decodeJsonMap(_text(row, 'payload_json')),
    createdAt: _dateTime(row, 'created_at'),
  );
}

ModelProviderConfigRecord _modelProviderConfigFromRow(Row row) {
  return ModelProviderConfigRecord(
    id: _text(row, 'id'),
    schemaVersion: _integer(row, 'schema_version'),
    providerKind: _text(row, 'provider_kind'),
    displayName: _text(row, 'display_name'),
    endpoint: _text(row, 'endpoint'),
    model: _text(row, 'model'),
    status: _text(row, 'status'),
    isDefault: _bool(row, 'is_default'),
    hasApiKey: _bool(row, 'has_api_key'),
    apiKey: _text(row, 'api_key'),
    capabilities: decodeJsonList(_text(row, 'capabilities_json')),
    payload: decodeJsonMap(_text(row, 'payload_json')),
    createdAt: _dateTime(row, 'created_at'),
    updatedAt: _dateTime(row, 'updated_at'),
  );
}

TodoRecord _todoFromRow(Row row) {
  return TodoRecord(
    id: _text(row, 'id'),
    schemaVersion: _integer(row, 'schema_version'),
    sourceCaptureId: _nullableText(row, 'source_capture_id'),
    sourceEventId: _nullableText(row, 'source_event_id'),
    status: _text(row, 'status'),
    payload: decodeJsonMap(_text(row, 'payload_json')),
    createdAt: _dateTime(row, 'created_at'),
    updatedAt: _dateTime(row, 'updated_at'),
  );
}

TraceEventRecord _traceFromRow(Row row) {
  final traceType = _text(row, 'trace_type');
  final severity = _text(row, 'severity');
  return TraceEventRecord(
    id: _text(row, 'id'),
    name: _text(row, 'name'),
    level: _text(row, 'level'),
    traceTypeOverride: traceType.isEmpty ? null : traceType,
    runIdOverride: _nullableText(row, 'run_id'),
    severityOverride: severity.isEmpty ? null : severity,
    schemaVersion: _integer(row, 'schema_version'),
    message: _text(row, 'message'),
    sourceEventId: _nullableText(row, 'source_event_id'),
    sourceRunId: _nullableText(row, 'source_run_id'),
    sourceTaskId: _nullableText(row, 'source_task_id'),
    packId: _nullableText(row, 'pack_id'),
    agentId: _nullableText(row, 'agent_id'),
    parentTraceId: _nullableText(row, 'parent_trace_id'),
    durationMs: _nullableNum(row, 'duration_ms'),
    status: _text(row, 'status'),
    payload: decodeJsonMap(_text(row, 'payload_json')),
    createdAt: _dateTime(row, 'created_at'),
  );
}

String _encodeDateTime(DateTime value) => value.toUtc().toIso8601String();

int _encodeBool(bool value) => value ? 1 : 0;

JsonMap _eventSubjectRef(EventLogEntry event) {
  if (event.subjectRef.isNotEmpty) {
    return event.subjectRef;
  }
  final kind = event.subjectKind;
  final id = event.subjectId;
  if (kind == null || id == null) {
    return const <String, Object?>{};
  }
  return <String, Object?>{'kind': kind, 'id': id};
}

String? _eventSubjectKind(EventLogEntry event) {
  final kind = event.subjectRefKind;
  return kind ?? event.subjectKind;
}

String? _eventSubjectId(EventLogEntry event) {
  final id = event.subjectRefId;
  return id ?? event.subjectId;
}

DateTime _dateTime(Row row, String column) {
  return DateTime.parse(_text(row, column)).toUtc();
}

String _text(Row row, String column) => row[column] as String;

String? _nullableText(Row row, String column) => row[column] as String?;

int _integer(Row row, String column) => row[column] as int;

int? _nullableInt(Row row, String column) => row[column] as int?;

bool _bool(Row row, String column) => _integer(row, column) != 0;

num? _nullableNum(Row row, String column) => row[column] as num?;

JsonMap _mergeJson(JsonMap base, JsonMap updates) {
  return <String, Object?>{...base, ...updates};
}

JsonList _mergeJsonLists(JsonList first, JsonList second) {
  final seen = <String>{};
  final merged = <Object?>[];
  for (final value in <Object?>[...first, ...second]) {
    if (seen.add(value.toString())) {
      merged.add(value);
    }
  }
  return merged;
}

String _reviewBody(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(body, 'body', 'must not be empty');
  }
  return trimmed;
}

void _requireSourceRefs(JsonList refs, String name) {
  if (refs.isEmpty) {
    throw ArgumentError.value(refs, name, 'must not be empty');
  }
}
