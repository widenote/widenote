import 'package:widenote_core/widenote_core.dart';

abstract final class WnEventTypes {
  static const captureCreated = 'wn.capture.created';
  static const memoryProposed = 'wn.memory.proposed';
  static const memoryEdited = 'wn.memory.edited';
  static const memoryDeleted = 'wn.memory.deleted';
  static const memoryRestored = 'wn.memory.restored';
  static const cardCreated = 'wn.card.created';
  static const insightCreated = 'wn.insight.created';
  static const todoSuggested = 'wn.todo.suggested';
}

enum WnActor { user, agent, plugin, system }

enum WnPrivacy {
  localOnly('local_only'),
  encryptedSync('encrypted_sync'),
  remoteAllowed('remote_allowed');

  const WnPrivacy(this.wireName);

  final String wireName;

  static WnPrivacy fromWireName(String value) {
    return WnPrivacy.values.firstWhere(
      (privacy) => privacy.wireName == value,
      orElse: () => WnPrivacy.localOnly,
    );
  }
}

final class SubjectRef {
  const SubjectRef({required this.kind, required this.id});

  final String kind;
  final String id;

  JsonMap toJson() => <String, Object?>{'kind': kind, 'id': id};
}

final class WnEvent {
  const WnEvent({
    required this.id,
    required this.type,
    required this.schemaVersion,
    required this.actor,
    required this.payload,
    required this.privacy,
    required this.deviceId,
    required this.createdAt,
    this.packId,
    this.agentId,
    this.subjectRef,
    this.causationId,
    this.correlationId,
  });

  final String id;
  final String type;
  final int schemaVersion;
  final WnActor actor;
  final String? packId;
  final String? agentId;
  final SubjectRef? subjectRef;
  final JsonMap payload;
  final WnPrivacy privacy;
  final String? causationId;
  final String? correlationId;
  final String deviceId;
  final DateTime createdAt;

  JsonMap toJson() {
    return <String, Object?>{
      'id': id,
      'type': type,
      'schema_version': schemaVersion,
      'actor': actor.name,
      'pack_id': packId,
      'agent_id': agentId,
      'subject_ref': subjectRef?.toJson(),
      'payload': payload,
      'privacy': privacy.wireName,
      'causation_id': causationId,
      'correlation_id': correlationId,
      'device_id': deviceId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

final class WnEventDraft {
  const WnEventDraft({
    required this.type,
    required this.actor,
    this.schemaVersion = 1,
    this.payload = const <String, Object?>{},
    this.privacy = WnPrivacy.localOnly,
    this.packId,
    this.agentId,
    this.subjectRef,
    this.causationId,
    this.correlationId,
  });

  final String type;
  final int schemaVersion;
  final WnActor actor;
  final String? packId;
  final String? agentId;
  final SubjectRef? subjectRef;
  final JsonMap payload;
  final WnPrivacy privacy;
  final String? causationId;
  final String? correlationId;
}
