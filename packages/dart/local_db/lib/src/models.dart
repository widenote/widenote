import 'json.dart';

final class EventLogEntry {
  const EventLogEntry({
    required this.id,
    required this.type,
    required this.actor,
    required this.createdAt,
    this.schemaVersion = 1,
    this.status = 'recorded',
    this.privacy = 'local_only',
    this.sourceCaptureId,
    this.sourceEventId,
    this.subjectKind,
    this.subjectId,
    this.subjectRef = const <String, Object?>{},
    this.packId,
    this.agentId,
    this.deviceId,
    this.causationId,
    this.correlationId,
    this.payload = const <String, Object?>{},
  });

  final String id;
  final String type;
  final int schemaVersion;
  final String actor;
  final String status;
  final String privacy;
  final String? sourceCaptureId;
  final String? sourceEventId;
  final String? subjectKind;
  final String? subjectId;
  final JsonMap subjectRef;
  final String? packId;
  final String? agentId;
  final String? deviceId;
  final String? causationId;
  final String? correlationId;
  final JsonMap payload;
  final DateTime createdAt;

  String? get subjectRefKind => _jsonString(subjectRef, 'kind') ?? subjectKind;

  String? get subjectRefId => _jsonString(subjectRef, 'id') ?? subjectId;
}

final class CaptureRecord {
  const CaptureRecord({
    required this.id,
    required this.sourceType,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
    this.sourceId,
    this.status = 'created',
    this.payload = const <String, Object?>{},
  });

  final String id;
  final int schemaVersion;
  final String sourceType;
  final String? sourceId;
  final String status;
  final JsonMap payload;
  final DateTime createdAt;
  final DateTime updatedAt;
}

final class MemoryItemRecord {
  const MemoryItemRecord({
    required this.id,
    required this.key,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
    this.sourceCaptureId,
    this.sourceEventId,
    this.status = 'active',
    this.body = '',
    this.sourceRefs = const <Object?>[],
    this.memoryType = 'project',
    this.confidence = 'medium',
    this.sensitivity = 'low',
    this.revision = 1,
    this.tombstone = false,
    this.payload = const <String, Object?>{},
  });

  final String id;
  final String key;
  final int schemaVersion;
  final String? sourceCaptureId;
  final String? sourceEventId;
  final String status;
  final String body;
  final JsonList sourceRefs;
  final String memoryType;
  final String confidence;
  final String sensitivity;
  final int revision;
  final bool tombstone;
  final JsonMap payload;
  final DateTime createdAt;
  final DateTime updatedAt;
}

final class MemoryCandidateRecord {
  const MemoryCandidateRecord({
    required this.id,
    required this.key,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
    this.sourceCaptureId,
    this.sourceEventId,
    this.status = 'proposed',
    this.body = '',
    this.sourceRefs = const <Object?>[],
    this.memoryType = 'project',
    this.confidence = 'medium',
    this.sensitivity = 'low',
    this.payload = const <String, Object?>{},
  });

  final String id;
  final String key;
  final int schemaVersion;
  final String? sourceCaptureId;
  final String? sourceEventId;
  final String status;
  final String body;
  final JsonList sourceRefs;
  final String memoryType;
  final String confidence;
  final String sensitivity;
  final JsonMap payload;
  final DateTime createdAt;
  final DateTime updatedAt;
}

final class TodoRecord {
  const TodoRecord({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
    this.sourceCaptureId,
    this.sourceEventId,
    this.status = 'open',
    this.payload = const <String, Object?>{},
  });

  final String id;
  final int schemaVersion;
  final String? sourceCaptureId;
  final String? sourceEventId;
  final String status;
  final JsonMap payload;
  final DateTime createdAt;
  final DateTime updatedAt;

  TodoRecord copyWith({
    int? schemaVersion,
    String? sourceCaptureId,
    String? sourceEventId,
    String? status,
    JsonMap? payload,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TodoRecord(
      id: id,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      sourceCaptureId: sourceCaptureId ?? this.sourceCaptureId,
      sourceEventId: sourceEventId ?? this.sourceEventId,
      status: status ?? this.status,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

final class TraceEventRecord {
  const TraceEventRecord({
    required this.id,
    required this.name,
    required this.level,
    required this.createdAt,
    this.schemaVersion = 1,
    this.traceTypeOverride,
    this.runIdOverride,
    this.severityOverride,
    this.message = '',
    this.sourceEventId,
    this.sourceRunId,
    this.sourceTaskId,
    this.packId,
    this.agentId,
    this.parentTraceId,
    this.durationMs,
    this.status = 'ok',
    this.payload = const <String, Object?>{},
  });

  final String id;
  final String name;
  final String level;
  final int schemaVersion;
  final String? traceTypeOverride;
  final String? runIdOverride;
  final String? severityOverride;
  final String message;
  final String? sourceEventId;
  final String? sourceRunId;
  final String? sourceTaskId;
  final String? packId;
  final String? agentId;
  final String? parentTraceId;
  final num? durationMs;
  final String status;
  final JsonMap payload;
  final DateTime createdAt;

  String get traceType => traceTypeOverride ?? name;

  String? get runId => runIdOverride ?? sourceRunId;

  String get severity => severityOverride ?? level;

  String? get eventId => sourceEventId;

  String? get taskId => sourceTaskId;
}

String? _jsonString(JsonMap value, String key) {
  final result = value[key];
  return result is String ? result : null;
}
