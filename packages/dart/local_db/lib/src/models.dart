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

final class DerivedArtifactRecord {
  const DerivedArtifactRecord({
    required this.id,
    required this.sourceCaptureId,
    required this.artifactKind,
    required this.title,
    required this.body,
    required this.sourceRefs,
    required this.generatorId,
    required this.generatorVersion,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
    this.sourceAttachmentId,
    this.sourceEventId,
    this.status = 'active',
    this.mimeType,
    this.storagePath,
    this.contentHash,
    this.sensitivity = 'low',
    this.confidence = 'medium',
    this.payload = const <String, Object?>{},
    this.invalidatedAt,
  });

  final String id;
  final int schemaVersion;
  final String sourceCaptureId;
  final String? sourceAttachmentId;
  final String? sourceEventId;
  final String artifactKind;
  final String status;
  final String title;
  final String body;
  final String? mimeType;
  final String? storagePath;
  final String? contentHash;
  final JsonList sourceRefs;
  final String sensitivity;
  final String confidence;
  final String generatorId;
  final String generatorVersion;
  final JsonMap payload;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? invalidatedAt;

  DerivedArtifactRecord copyWith({
    int? schemaVersion,
    String? sourceCaptureId,
    String? sourceAttachmentId,
    String? sourceEventId,
    String? artifactKind,
    String? status,
    String? title,
    String? body,
    String? mimeType,
    String? storagePath,
    String? contentHash,
    JsonList? sourceRefs,
    String? sensitivity,
    String? confidence,
    String? generatorId,
    String? generatorVersion,
    JsonMap? payload,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? invalidatedAt,
    bool clearInvalidatedAt = false,
  }) {
    return DerivedArtifactRecord(
      id: id,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      sourceCaptureId: sourceCaptureId ?? this.sourceCaptureId,
      sourceAttachmentId: sourceAttachmentId ?? this.sourceAttachmentId,
      sourceEventId: sourceEventId ?? this.sourceEventId,
      artifactKind: artifactKind ?? this.artifactKind,
      status: status ?? this.status,
      title: title ?? this.title,
      body: body ?? this.body,
      mimeType: mimeType ?? this.mimeType,
      storagePath: storagePath ?? this.storagePath,
      contentHash: contentHash ?? this.contentHash,
      sourceRefs: sourceRefs ?? this.sourceRefs,
      sensitivity: sensitivity ?? this.sensitivity,
      confidence: confidence ?? this.confidence,
      generatorId: generatorId ?? this.generatorId,
      generatorVersion: generatorVersion ?? this.generatorVersion,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      invalidatedAt: clearInvalidatedAt
          ? null
          : invalidatedAt ?? this.invalidatedAt,
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

  ChatSessionRecord copyWith({
    int? schemaVersion,
    String? title,
    String? status,
    JsonMap? payload,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatSessionRecord(
      id: id,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      title: title ?? this.title,
      status: status ?? this.status,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
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

final class RuntimeTaskRecord {
  const RuntimeTaskRecord({
    required this.id,
    required this.packId,
    required this.packVersion,
    required this.agentId,
    required this.handlerId,
    required this.subscriptionId,
    required this.triggerEventId,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
    this.identityKey = '',
    this.status = 'queued',
    this.dependencyTaskIds = const <Object?>[],
    this.missingDependencyIds = const <Object?>[],
    this.attempts = 0,
    this.maxAttempts = 1,
    this.leaseOwner,
    this.leasedUntil,
    this.error,
    this.payload = const <String, Object?>{},
  });

  final String id;
  final int schemaVersion;
  final String packId;
  final String packVersion;
  final String agentId;
  final String handlerId;
  final String subscriptionId;
  final String triggerEventId;
  final String identityKey;
  final String status;
  final JsonList dependencyTaskIds;
  final JsonList missingDependencyIds;
  final int attempts;
  final int maxAttempts;
  final String? leaseOwner;
  final DateTime? leasedUntil;
  final String? error;
  final JsonMap payload;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get effectiveIdentityKey {
    if (identityKey.trim().isNotEmpty) {
      return identityKey;
    }
    return runtimeTaskIdentityKey(
      triggerEventId: triggerEventId,
      subscriptionId: subscriptionId,
      packId: packId,
      packVersion: packVersion,
      handlerId: handlerId,
    );
  }

  RuntimeTaskRecord copyWith({
    int? schemaVersion,
    String? packId,
    String? packVersion,
    String? agentId,
    String? handlerId,
    String? subscriptionId,
    String? triggerEventId,
    String? identityKey,
    String? status,
    JsonList? dependencyTaskIds,
    JsonList? missingDependencyIds,
    int? attempts,
    int? maxAttempts,
    String? leaseOwner,
    DateTime? leasedUntil,
    String? error,
    JsonMap? payload,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearLease = false,
    bool clearError = false,
  }) {
    return RuntimeTaskRecord(
      id: id,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      packId: packId ?? this.packId,
      packVersion: packVersion ?? this.packVersion,
      agentId: agentId ?? this.agentId,
      handlerId: handlerId ?? this.handlerId,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      triggerEventId: triggerEventId ?? this.triggerEventId,
      identityKey: identityKey ?? this.identityKey,
      status: status ?? this.status,
      dependencyTaskIds: dependencyTaskIds ?? this.dependencyTaskIds,
      missingDependencyIds: missingDependencyIds ?? this.missingDependencyIds,
      attempts: attempts ?? this.attempts,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      leaseOwner: clearLease ? null : leaseOwner ?? this.leaseOwner,
      leasedUntil: clearLease ? null : leasedUntil ?? this.leasedUntil,
      error: clearError ? null : error ?? this.error,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

String runtimeTaskIdentityKey({
  required String triggerEventId,
  required String subscriptionId,
  required String packId,
  required String packVersion,
  required String handlerId,
}) {
  return [
    'event:$triggerEventId',
    'subscription:$subscriptionId',
    'pack:$packId@$packVersion',
    'handler:$handlerId',
  ].join('|');
}

final class RuntimeRunRecord {
  const RuntimeRunRecord({
    required this.id,
    required this.taskId,
    required this.packId,
    required this.packVersion,
    required this.agentId,
    required this.handlerId,
    required this.status,
    required this.startedAt,
    required this.attempt,
    this.schemaVersion = 1,
    this.completedAt,
    this.outputEventIds = const <Object?>[],
    this.error,
    this.payload = const <String, Object?>{},
  });

  final String id;
  final int schemaVersion;
  final String taskId;
  final String packId;
  final String packVersion;
  final String agentId;
  final String handlerId;
  final String status;
  final DateTime startedAt;
  final int attempt;
  final DateTime? completedAt;
  final JsonList outputEventIds;
  final String? error;
  final JsonMap payload;

  RuntimeRunRecord copyWith({
    int? schemaVersion,
    String? taskId,
    String? packId,
    String? packVersion,
    String? agentId,
    String? handlerId,
    String? status,
    DateTime? startedAt,
    int? attempt,
    DateTime? completedAt,
    JsonList? outputEventIds,
    String? error,
    JsonMap? payload,
    bool clearCompletedAt = false,
    bool clearError = false,
  }) {
    return RuntimeRunRecord(
      id: id,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      taskId: taskId ?? this.taskId,
      packId: packId ?? this.packId,
      packVersion: packVersion ?? this.packVersion,
      agentId: agentId ?? this.agentId,
      handlerId: handlerId ?? this.handlerId,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      attempt: attempt ?? this.attempt,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      outputEventIds: outputEventIds ?? this.outputEventIds,
      error: clearError ? null : error ?? this.error,
      payload: payload ?? this.payload,
    );
  }
}

final class PackInstallationRecord {
  const PackInstallationRecord({
    required this.packId,
    required this.name,
    required this.version,
    required this.publisher,
    required this.edition,
    required this.installedAt,
    required this.updatedAt,
    this.schemaVersion = 1,
    this.status = 'disabled',
    this.runtimeStatus = 'idle',
    this.entrypointKind = 'native',
    this.requestedPermissions = const <Object?>[],
    this.enabledSubscriptionIds = const <Object?>[],
    this.manifest = const <String, Object?>{},
    this.payload = const <String, Object?>{},
  });

  final String packId;
  final int schemaVersion;
  final String name;
  final String version;
  final String publisher;
  final String edition;
  final String status;
  final String runtimeStatus;
  final String entrypointKind;
  final JsonList requestedPermissions;
  final JsonList enabledSubscriptionIds;
  final JsonMap manifest;
  final JsonMap payload;
  final DateTime installedAt;
  final DateTime updatedAt;

  PackInstallationRecord copyWith({
    int? schemaVersion,
    String? name,
    String? version,
    String? publisher,
    String? edition,
    String? status,
    String? runtimeStatus,
    String? entrypointKind,
    JsonList? requestedPermissions,
    JsonList? enabledSubscriptionIds,
    JsonMap? manifest,
    JsonMap? payload,
    DateTime? installedAt,
    DateTime? updatedAt,
  }) {
    return PackInstallationRecord(
      packId: packId,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      name: name ?? this.name,
      version: version ?? this.version,
      publisher: publisher ?? this.publisher,
      edition: edition ?? this.edition,
      status: status ?? this.status,
      runtimeStatus: runtimeStatus ?? this.runtimeStatus,
      entrypointKind: entrypointKind ?? this.entrypointKind,
      requestedPermissions: requestedPermissions ?? this.requestedPermissions,
      enabledSubscriptionIds:
          enabledSubscriptionIds ?? this.enabledSubscriptionIds,
      manifest: manifest ?? this.manifest,
      payload: payload ?? this.payload,
      installedAt: installedAt ?? this.installedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

final class PermissionGrantRecord {
  const PermissionGrantRecord({
    required this.id,
    required this.packId,
    required this.permissionId,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
    this.status = 'granted',
    this.grantKind = 'user',
    this.sourceEventId,
    this.grantedAt,
    this.revokedAt,
    this.reason,
    this.payload = const <String, Object?>{},
  });

  final String id;
  final int schemaVersion;
  final String packId;
  final String permissionId;
  final String status;
  final String grantKind;
  final String? sourceEventId;
  final DateTime? grantedAt;
  final DateTime? revokedAt;
  final String? reason;
  final JsonMap payload;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => status == 'granted';

  PermissionGrantRecord copyWith({
    int? schemaVersion,
    String? packId,
    String? permissionId,
    String? status,
    String? grantKind,
    String? sourceEventId,
    DateTime? grantedAt,
    DateTime? revokedAt,
    String? reason,
    JsonMap? payload,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearGrantTime = false,
    bool clearRevokedAt = false,
    bool clearReason = false,
  }) {
    return PermissionGrantRecord(
      id: id,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      packId: packId ?? this.packId,
      permissionId: permissionId ?? this.permissionId,
      status: status ?? this.status,
      grantKind: grantKind ?? this.grantKind,
      sourceEventId: sourceEventId ?? this.sourceEventId,
      grantedAt: clearGrantTime ? null : grantedAt ?? this.grantedAt,
      revokedAt: clearRevokedAt ? null : revokedAt ?? this.revokedAt,
      reason: clearReason ? null : reason ?? this.reason,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

final class RuntimeApprovalRecord {
  const RuntimeApprovalRecord({
    required this.id,
    required this.packId,
    required this.agentId,
    required this.taskId,
    required this.runId,
    required this.toolName,
    required this.runMode,
    required this.toolAccess,
    required this.toolRisk,
    required this.isExternal,
    required this.requestedAt,
    this.schemaVersion = 1,
    this.requiredPermissions = const <Object?>[],
    this.inputKeys = const <Object?>[],
    this.sourceRefs = const <Object?>[],
    this.actionSummary = '',
    this.status = 'pending',
    this.expiresAt,
    this.decidedAt,
    this.decision,
    this.reason,
    this.payload = const <String, Object?>{},
  });

  final String id;
  final int schemaVersion;
  final String packId;
  final String agentId;
  final String taskId;
  final String runId;
  final String toolName;
  final String runMode;
  final String toolAccess;
  final String toolRisk;
  final bool isExternal;
  final JsonList requiredPermissions;
  final JsonList inputKeys;
  final JsonList sourceRefs;
  final String actionSummary;
  final String status;
  final DateTime requestedAt;
  final DateTime? expiresAt;
  final DateTime? decidedAt;
  final String? decision;
  final String? reason;
  final JsonMap payload;

  bool get isPending => status == 'pending';

  bool isPendingAt(DateTime now) {
    if (!isPending) {
      return false;
    }
    final expires = expiresAt;
    return expires == null || expires.isAfter(now.toUtc());
  }

  RuntimeApprovalRecord copyWith({
    int? schemaVersion,
    String? packId,
    String? agentId,
    String? taskId,
    String? runId,
    String? toolName,
    String? runMode,
    String? toolAccess,
    String? toolRisk,
    bool? isExternal,
    JsonList? requiredPermissions,
    JsonList? inputKeys,
    JsonList? sourceRefs,
    String? actionSummary,
    String? status,
    DateTime? requestedAt,
    DateTime? expiresAt,
    DateTime? decidedAt,
    String? decision,
    String? reason,
    JsonMap? payload,
    bool clearExpiresAt = false,
    bool clearDecidedAt = false,
    bool clearDecision = false,
    bool clearReason = false,
  }) {
    return RuntimeApprovalRecord(
      id: id,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      packId: packId ?? this.packId,
      agentId: agentId ?? this.agentId,
      taskId: taskId ?? this.taskId,
      runId: runId ?? this.runId,
      toolName: toolName ?? this.toolName,
      runMode: runMode ?? this.runMode,
      toolAccess: toolAccess ?? this.toolAccess,
      toolRisk: toolRisk ?? this.toolRisk,
      isExternal: isExternal ?? this.isExternal,
      requiredPermissions: requiredPermissions ?? this.requiredPermissions,
      inputKeys: inputKeys ?? this.inputKeys,
      sourceRefs: sourceRefs ?? this.sourceRefs,
      actionSummary: actionSummary ?? this.actionSummary,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      expiresAt: clearExpiresAt ? null : expiresAt ?? this.expiresAt,
      decidedAt: clearDecidedAt ? null : decidedAt ?? this.decidedAt,
      decision: clearDecision ? null : decision ?? this.decision,
      reason: clearReason ? null : reason ?? this.reason,
      payload: payload ?? this.payload,
    );
  }
}

final class ContextPacketCacheRecord {
  const ContextPacketCacheRecord({
    required this.id,
    required this.surface,
    required this.permissionScope,
    required this.disclosureLevel,
    required this.generatorId,
    required this.generatorVersion,
    required this.promptVersion,
    required this.cacheKey,
    required this.packet,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
    this.requestRef = const <String, Object?>{},
    this.subjectRef = const <String, Object?>{},
    this.sourceRefs = const <Object?>[],
    this.sourceVersions = const <Object?>[],
    this.packId,
    this.packVersion,
    this.agentId,
    this.localDate,
    this.privacyProfile = 'default',
    this.invalidationKeys = const <Object?>[],
    this.status = 'active',
    this.expiresAt,
    this.invalidatedAt,
  });

  final String id;
  final int schemaVersion;
  final String surface;
  final JsonMap requestRef;
  final JsonMap subjectRef;
  final JsonList sourceRefs;
  final JsonList sourceVersions;
  final String permissionScope;
  final String disclosureLevel;
  final String generatorId;
  final String generatorVersion;
  final String promptVersion;
  final String? packId;
  final String? packVersion;
  final String? agentId;
  final String? localDate;
  final String privacyProfile;
  final JsonList invalidationKeys;
  final String cacheKey;
  final String status;
  final JsonMap packet;
  final DateTime? expiresAt;
  final DateTime? invalidatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool isReusableAt(DateTime now) {
    if (status != 'active' || invalidatedAt != null) {
      return false;
    }
    final expires = expiresAt;
    return expires == null || expires.isAfter(now.toUtc());
  }

  ContextPacketCacheRecord copyWith({
    int? schemaVersion,
    String? surface,
    JsonMap? requestRef,
    JsonMap? subjectRef,
    JsonList? sourceRefs,
    JsonList? sourceVersions,
    String? permissionScope,
    String? disclosureLevel,
    String? generatorId,
    String? generatorVersion,
    String? promptVersion,
    String? packId,
    String? packVersion,
    String? agentId,
    String? localDate,
    String? privacyProfile,
    JsonList? invalidationKeys,
    String? cacheKey,
    String? status,
    JsonMap? packet,
    DateTime? expiresAt,
    DateTime? invalidatedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearExpiresAt = false,
    bool clearInvalidatedAt = false,
  }) {
    return ContextPacketCacheRecord(
      id: id,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      surface: surface ?? this.surface,
      requestRef: requestRef ?? this.requestRef,
      subjectRef: subjectRef ?? this.subjectRef,
      sourceRefs: sourceRefs ?? this.sourceRefs,
      sourceVersions: sourceVersions ?? this.sourceVersions,
      permissionScope: permissionScope ?? this.permissionScope,
      disclosureLevel: disclosureLevel ?? this.disclosureLevel,
      generatorId: generatorId ?? this.generatorId,
      generatorVersion: generatorVersion ?? this.generatorVersion,
      promptVersion: promptVersion ?? this.promptVersion,
      packId: packId ?? this.packId,
      packVersion: packVersion ?? this.packVersion,
      agentId: agentId ?? this.agentId,
      localDate: localDate ?? this.localDate,
      privacyProfile: privacyProfile ?? this.privacyProfile,
      invalidationKeys: invalidationKeys ?? this.invalidationKeys,
      cacheKey: cacheKey ?? this.cacheKey,
      status: status ?? this.status,
      packet: packet ?? this.packet,
      expiresAt: clearExpiresAt ? null : expiresAt ?? this.expiresAt,
      invalidatedAt: clearInvalidatedAt
          ? null
          : invalidatedAt ?? this.invalidatedAt,
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
