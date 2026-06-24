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

final class AttachmentRecord {
  const AttachmentRecord({
    required this.id,
    required this.captureId,
    required this.assetKind,
    required this.storagePath,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
    this.sourceEventId,
    this.mimeType,
    this.originalFileName,
    this.sha256,
    this.byteLength,
    this.status = 'available',
    this.payload = const <String, Object?>{},
  });

  final String id;
  final int schemaVersion;
  final String captureId;
  final String? sourceEventId;
  final String assetKind;
  final String? mimeType;
  final String storagePath;
  final String? originalFileName;
  final String? sha256;
  final int? byteLength;
  final String status;
  final JsonMap payload;
  final DateTime createdAt;
  final DateTime updatedAt;

  AttachmentRecord copyWith({
    int? schemaVersion,
    String? captureId,
    String? sourceEventId,
    String? assetKind,
    String? mimeType,
    String? storagePath,
    String? originalFileName,
    String? sha256,
    int? byteLength,
    String? status,
    JsonMap? payload,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AttachmentRecord(
      id: id,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      captureId: captureId ?? this.captureId,
      sourceEventId: sourceEventId ?? this.sourceEventId,
      assetKind: assetKind ?? this.assetKind,
      mimeType: mimeType ?? this.mimeType,
      storagePath: storagePath ?? this.storagePath,
      originalFileName: originalFileName ?? this.originalFileName,
      sha256: sha256 ?? this.sha256,
      byteLength: byteLength ?? this.byteLength,
      status: status ?? this.status,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
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

  MemoryItemRecord copyWith({
    String? key,
    int? schemaVersion,
    String? sourceCaptureId,
    String? sourceEventId,
    String? status,
    String? body,
    JsonList? sourceRefs,
    String? memoryType,
    String? confidence,
    String? sensitivity,
    int? revision,
    bool? tombstone,
    JsonMap? payload,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MemoryItemRecord(
      id: id,
      key: key ?? this.key,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      sourceCaptureId: sourceCaptureId ?? this.sourceCaptureId,
      sourceEventId: sourceEventId ?? this.sourceEventId,
      status: status ?? this.status,
      body: body ?? this.body,
      sourceRefs: sourceRefs ?? this.sourceRefs,
      memoryType: memoryType ?? this.memoryType,
      confidence: confidence ?? this.confidence,
      sensitivity: sensitivity ?? this.sensitivity,
      revision: revision ?? this.revision,
      tombstone: tombstone ?? this.tombstone,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
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

  MemoryCandidateRecord copyWith({
    String? key,
    int? schemaVersion,
    String? sourceCaptureId,
    String? sourceEventId,
    String? status,
    String? body,
    JsonList? sourceRefs,
    String? memoryType,
    String? confidence,
    String? sensitivity,
    JsonMap? payload,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MemoryCandidateRecord(
      id: id,
      key: key ?? this.key,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      sourceCaptureId: sourceCaptureId ?? this.sourceCaptureId,
      sourceEventId: sourceEventId ?? this.sourceEventId,
      status: status ?? this.status,
      body: body ?? this.body,
      sourceRefs: sourceRefs ?? this.sourceRefs,
      memoryType: memoryType ?? this.memoryType,
      confidence: confidence ?? this.confidence,
      sensitivity: sensitivity ?? this.sensitivity,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

final class CardRecord {
  const CardRecord({
    required this.id,
    required this.cardKind,
    required this.title,
    required this.body,
    required this.sourceRefs,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
    this.status = 'active',
    this.payload = const <String, Object?>{},
  });

  final String id;
  final int schemaVersion;
  final String cardKind;
  final String status;
  final String title;
  final String body;
  final JsonList sourceRefs;
  final JsonMap payload;
  final DateTime createdAt;
  final DateTime updatedAt;

  CardRecord copyWith({
    int? schemaVersion,
    String? cardKind,
    String? status,
    String? title,
    String? body,
    JsonList? sourceRefs,
    JsonMap? payload,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CardRecord(
      id: id,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      cardKind: cardKind ?? this.cardKind,
      status: status ?? this.status,
      title: title ?? this.title,
      body: body ?? this.body,
      sourceRefs: sourceRefs ?? this.sourceRefs,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

final class InsightRecord {
  const InsightRecord({
    required this.id,
    required this.insightKind,
    required this.title,
    required this.summary,
    required this.sourceRefs,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
    this.status = 'active',
    this.metricLabel,
    this.metricValue,
    this.payload = const <String, Object?>{},
  });

  final String id;
  final int schemaVersion;
  final String insightKind;
  final String status;
  final String title;
  final String summary;
  final JsonList sourceRefs;
  final String? metricLabel;
  final num? metricValue;
  final JsonMap payload;
  final DateTime createdAt;
  final DateTime updatedAt;

  InsightRecord copyWith({
    int? schemaVersion,
    String? insightKind,
    String? status,
    String? title,
    String? summary,
    JsonList? sourceRefs,
    String? metricLabel,
    num? metricValue,
    JsonMap? payload,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InsightRecord(
      id: id,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      insightKind: insightKind ?? this.insightKind,
      status: status ?? this.status,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      sourceRefs: sourceRefs ?? this.sourceRefs,
      metricLabel: metricLabel ?? this.metricLabel,
      metricValue: metricValue ?? this.metricValue,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

final class ChatSessionRecord {
  const ChatSessionRecord({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
    this.status = 'active',
    this.payload = const <String, Object?>{},
  });

  final String id;
  final int schemaVersion;
  final String title;
  final String status;
  final JsonMap payload;
  final DateTime createdAt;
  final DateTime updatedAt;
}

final class ChatMessageRecord {
  const ChatMessageRecord({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.body,
    required this.createdAt,
    this.schemaVersion = 1,
    this.status = 'sent',
    this.sourceRefs = const <Object?>[],
    this.payload = const <String, Object?>{},
  });

  final String id;
  final int schemaVersion;
  final String sessionId;
  final String role;
  final String status;
  final String body;
  final JsonList sourceRefs;
  final JsonMap payload;
  final DateTime createdAt;
}

final class ModelProviderConfigRecord {
  const ModelProviderConfigRecord({
    required this.id,
    required this.providerKind,
    required this.displayName,
    required this.endpoint,
    required this.model,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
    this.status = 'active',
    this.isDefault = false,
    this.hasApiKey = false,
    this.apiKey = '',
    this.capabilities = const <Object?>[],
    this.payload = const <String, Object?>{},
  });

  final String id;
  final int schemaVersion;
  final String providerKind;
  final String displayName;
  final String endpoint;
  final String model;
  final String status;
  final bool isDefault;
  final bool hasApiKey;
  final String apiKey;
  final JsonList capabilities;
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
