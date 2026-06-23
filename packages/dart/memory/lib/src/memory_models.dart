enum MemoryConfidence { low, medium, high }

enum MemorySensitivity { low, medium, high }

enum MemoryDurability { transient, durable }

enum MemoryType {
  preference,
  project,
  taskContext,
  person,
  health,
  finance,
  location,
  credential,
  insight,
}

enum MemoryItemStatus { active, deleted, superseded }

enum MemoryProposalStatus {
  pending,
  autoAccepted,
  needsReview,
  accepted,
  rejected,
  merged,
}

final class MemorySourceRef {
  const MemorySourceRef({
    required this.sourceType,
    required this.sourceId,
    this.excerpt,
    this.uri,
  });

  final String sourceType;
  final String sourceId;
  final String? excerpt;
  final Uri? uri;

  bool get hasEvidenceText => excerpt != null && excerpt!.trim().isNotEmpty;

  bool get hasEvidenceUri => uri != null && uri.toString().trim().isNotEmpty;

  bool get hasEvidence => hasEvidenceText || hasEvidenceUri;
}

final class MemoryTombstone {
  const MemoryTombstone({
    required this.deletedAt,
    required this.deletedBy,
    required this.reason,
  });

  final DateTime deletedAt;
  final String deletedBy;
  final String reason;
}

final class MemoryItem {
  const MemoryItem({
    required this.id,
    required this.key,
    required this.body,
    required this.evidence,
    required this.memoryType,
    required this.status,
    required this.confidence,
    required this.sensitivity,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    this.tombstone,
  });

  final String id;
  final String key;
  final String body;
  final List<MemorySourceRef> evidence;
  final MemoryType memoryType;
  final MemoryItemStatus status;
  final MemoryConfidence confidence;
  final MemorySensitivity sensitivity;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final MemoryTombstone? tombstone;

  bool get isDeleted => status == MemoryItemStatus.deleted;

  MemoryItem copyWith({
    String? id,
    String? key,
    String? body,
    List<MemorySourceRef>? evidence,
    MemoryType? memoryType,
    MemoryItemStatus? status,
    MemoryConfidence? confidence,
    MemorySensitivity? sensitivity,
    int? revision,
    DateTime? createdAt,
    DateTime? updatedAt,
    MemoryTombstone? tombstone,
  }) {
    return MemoryItem(
      id: id ?? this.id,
      key: key ?? this.key,
      body: body ?? this.body,
      evidence: evidence ?? this.evidence,
      memoryType: memoryType ?? this.memoryType,
      status: status ?? this.status,
      confidence: confidence ?? this.confidence,
      sensitivity: sensitivity ?? this.sensitivity,
      revision: revision ?? this.revision,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tombstone: tombstone ?? this.tombstone,
    );
  }
}

final class MemoryProposal {
  const MemoryProposal({
    required this.id,
    required this.key,
    required this.body,
    required this.evidence,
    required this.memoryType,
    required this.confidence,
    required this.sensitivity,
    this.durability = MemoryDurability.durable,
    this.status = MemoryProposalStatus.pending,
    this.policyReasons = const [],
    this.conflictingMemoryIds = const [],
  });

  final String id;
  final String key;
  final String body;
  final List<MemorySourceRef> evidence;
  final MemoryType memoryType;
  final MemoryConfidence confidence;
  final MemorySensitivity sensitivity;
  final MemoryDurability durability;
  final MemoryProposalStatus status;
  final List<String> policyReasons;
  final List<String> conflictingMemoryIds;

  bool get hasEvidence {
    return evidence.any((sourceRef) => sourceRef.hasEvidence);
  }

  MemoryProposal copyWith({
    String? id,
    String? key,
    String? body,
    List<MemorySourceRef>? evidence,
    MemoryType? memoryType,
    MemoryConfidence? confidence,
    MemorySensitivity? sensitivity,
    MemoryDurability? durability,
    MemoryProposalStatus? status,
    List<String>? policyReasons,
    List<String>? conflictingMemoryIds,
  }) {
    return MemoryProposal(
      id: id ?? this.id,
      key: key ?? this.key,
      body: body ?? this.body,
      evidence: evidence ?? this.evidence,
      memoryType: memoryType ?? this.memoryType,
      confidence: confidence ?? this.confidence,
      sensitivity: sensitivity ?? this.sensitivity,
      durability: durability ?? this.durability,
      status: status ?? this.status,
      policyReasons: policyReasons ?? this.policyReasons,
      conflictingMemoryIds: conflictingMemoryIds ?? this.conflictingMemoryIds,
    );
  }
}
