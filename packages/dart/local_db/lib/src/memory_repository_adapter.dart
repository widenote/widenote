import 'package:widenote_memory/memory.dart' as memory;

import 'database.dart';
import 'json.dart';
import 'models.dart';

typedef LocalDbMemoryClock = DateTime Function();

final class LocalDbMemoryRepository implements memory.MemoryRepository {
  LocalDbMemoryRepository(this._database, {LocalDbMemoryClock? clock})
    : _clock = clock ?? DateTime.now;

  final WideNoteLocalDatabase _database;
  final LocalDbMemoryClock _clock;

  @override
  Future<memory.MemoryItem> saveItem(memory.MemoryItem item) async {
    _database.memoryItems.save(_itemRecord(item));
    return item;
  }

  @override
  Future<memory.MemoryProposal> saveProposal(
    memory.MemoryProposal proposal,
  ) async {
    final existing = _database.memoryCandidates.readById(proposal.id);
    _database.memoryCandidates.save(_candidateRecord(proposal, existing));
    return proposal;
  }

  @override
  Future<memory.MemoryItem?> findItemById(String id) async {
    final record = _database.memoryItems.readById(id);
    return record == null ? null : _itemFromRecord(record);
  }

  @override
  Future<memory.MemoryProposal?> findProposalById(String id) async {
    final record = _database.memoryCandidates.readById(id);
    return record == null ? null : _proposalFromRecord(record);
  }

  @override
  Future<List<memory.MemoryItem>> listItems({
    memory.MemoryItemStatus? status,
  }) async {
    return _database.memoryItems
        .readAll(status: status == null ? null : _itemStatusName(status))
        .map(_itemFromRecord)
        .toList(growable: false);
  }

  @override
  Future<List<memory.MemoryProposal>> listProposals({
    memory.MemoryProposalStatus? status,
  }) async {
    return _database.memoryCandidates
        .readAll(status: status == null ? null : _proposalStatusName(status))
        .map(_proposalFromRecord)
        .toList(growable: false);
  }

  @override
  Future<List<memory.MemoryItem>> findConflictingItems(
    memory.MemoryProposal proposal,
  ) async {
    return _database.memoryItems
        .readActiveByKey(proposal.key)
        .where((item) => item.body.trim() != proposal.body.trim())
        .map(_itemFromRecord)
        .toList(growable: false);
  }

  MemoryItemRecord _itemRecord(memory.MemoryItem item) {
    final existing = _database.memoryItems.readById(item.id);
    final payload = <String, Object?>{
      ...?existing?.payload,
      if (item.tombstone != null)
        'tombstone': <String, Object?>{
          'deleted_at': item.tombstone!.deletedAt.toUtc().toIso8601String(),
          'deleted_by': item.tombstone!.deletedBy,
          'reason': item.tombstone!.reason,
        },
    };

    return MemoryItemRecord(
      id: item.id,
      key: item.key,
      sourceCaptureId: _sourceId(item.evidence, 'capture'),
      sourceEventId: _sourceId(item.evidence, 'event'),
      status: _itemStatusName(item.status),
      body: item.body,
      sourceRefs: _sourceRefsToJson(item.evidence),
      memoryType: _memoryTypeName(item.memoryType),
      confidence: item.confidence.name,
      sensitivity: item.sensitivity.name,
      revision: item.revision,
      tombstone: item.tombstone != null,
      payload: payload,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
  }

  MemoryCandidateRecord _candidateRecord(
    memory.MemoryProposal proposal,
    MemoryCandidateRecord? existing,
  ) {
    final now = _clock().toUtc();
    return MemoryCandidateRecord(
      id: proposal.id,
      key: proposal.key,
      sourceCaptureId: _sourceId(proposal.evidence, 'capture'),
      sourceEventId: _sourceId(proposal.evidence, 'event'),
      status: _proposalStatusName(proposal.status),
      body: proposal.body,
      sourceRefs: _sourceRefsToJson(proposal.evidence),
      memoryType: _memoryTypeName(proposal.memoryType),
      confidence: proposal.confidence.name,
      sensitivity: proposal.sensitivity.name,
      payload: <String, Object?>{
        ...?existing?.payload,
        'durability': _durabilityName(proposal.durability),
        'policy_reasons': proposal.policyReasons,
        'conflicting_memory_ids': proposal.conflictingMemoryIds,
      },
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
  }
}

memory.MemoryItem _itemFromRecord(MemoryItemRecord record) {
  return memory.MemoryItem(
    id: record.id,
    key: record.key,
    body: record.body,
    evidence: _sourceRefsFromJson(record.sourceRefs),
    memoryType: _memoryType(record.memoryType),
    status: _itemStatus(record.status),
    confidence: _confidence(record.confidence),
    sensitivity: _sensitivity(record.sensitivity),
    revision: record.revision,
    createdAt: record.createdAt,
    updatedAt: record.updatedAt,
    tombstone: record.tombstone ? _tombstone(record.payload) : null,
  );
}

memory.MemoryProposal _proposalFromRecord(MemoryCandidateRecord record) {
  return memory.MemoryProposal(
    id: record.id,
    key: record.key,
    body: record.body,
    evidence: _sourceRefsFromJson(record.sourceRefs),
    memoryType: _memoryType(record.memoryType),
    confidence: _confidence(record.confidence),
    sensitivity: _sensitivity(record.sensitivity),
    durability: _durability(_string(record.payload['durability'])),
    status: _proposalStatus(record.status),
    policyReasons: _stringList(record.payload['policy_reasons']),
    conflictingMemoryIds: _stringList(record.payload['conflicting_memory_ids']),
  );
}

JsonList _sourceRefsToJson(List<memory.MemorySourceRef> refs) {
  return <Object?>[
    for (final ref in refs)
      <String, Object?>{
        'kind': ref.sourceType,
        'id': ref.sourceId,
        'source_type': ref.sourceType,
        'source_id': ref.sourceId,
        if (ref.excerpt != null) 'excerpt': ref.excerpt,
        if (ref.excerpt != null) 'evidence_text': ref.excerpt,
        if (ref.uri != null) 'uri': ref.uri.toString(),
      },
  ];
}

List<memory.MemorySourceRef> _sourceRefsFromJson(JsonList refs) {
  return refs
      .whereType<Map>()
      .map((ref) {
        final sourceType =
            _string(ref['source_type']) ?? _string(ref['kind']) ?? 'record';
        final sourceId =
            _string(ref['source_id']) ??
            _string(ref['id']) ??
            _string(ref['event_id']) ??
            'unknown';
        final uriValue = _string(ref['uri']);
        return memory.MemorySourceRef(
          sourceType: sourceType,
          sourceId: sourceId,
          excerpt: _string(ref['excerpt']) ?? _string(ref['evidence_text']),
          uri: uriValue == null ? null : Uri.tryParse(uriValue),
        );
      })
      .toList(growable: false);
}

String? _sourceId(List<memory.MemorySourceRef> refs, String sourceType) {
  for (final ref in refs) {
    if (ref.sourceType == sourceType) {
      return ref.sourceId;
    }
  }
  return null;
}

memory.MemoryTombstone? _tombstone(JsonMap payload) {
  final value = payload['tombstone'];
  if (value is! Map) {
    return null;
  }
  final deletedAt = _string(value['deleted_at']);
  final deletedBy = _string(value['deleted_by']);
  final reason = _string(value['reason']);
  if (deletedAt == null || deletedBy == null || reason == null) {
    return null;
  }
  return memory.MemoryTombstone(
    deletedAt: DateTime.parse(deletedAt).toUtc(),
    deletedBy: deletedBy,
    reason: reason,
  );
}

String _itemStatusName(memory.MemoryItemStatus status) => status.name;

memory.MemoryItemStatus _itemStatus(String value) {
  return switch (value) {
    'deleted' => memory.MemoryItemStatus.deleted,
    'superseded' => memory.MemoryItemStatus.superseded,
    _ => memory.MemoryItemStatus.active,
  };
}

String _proposalStatusName(memory.MemoryProposalStatus status) {
  return switch (status) {
    memory.MemoryProposalStatus.autoAccepted => 'auto_accepted',
    memory.MemoryProposalStatus.needsReview => 'needs_review',
    memory.MemoryProposalStatus.pending => 'pending',
    memory.MemoryProposalStatus.accepted => 'accepted',
    memory.MemoryProposalStatus.rejected => 'rejected',
    memory.MemoryProposalStatus.merged => 'merged',
  };
}

memory.MemoryProposalStatus _proposalStatus(String value) {
  return switch (value) {
    'auto_accepted' => memory.MemoryProposalStatus.autoAccepted,
    'needs_review' => memory.MemoryProposalStatus.needsReview,
    'accepted' => memory.MemoryProposalStatus.accepted,
    'rejected' => memory.MemoryProposalStatus.rejected,
    'merged' => memory.MemoryProposalStatus.merged,
    _ => memory.MemoryProposalStatus.pending,
  };
}

String _memoryTypeName(memory.MemoryType type) {
  return switch (type) {
    memory.MemoryType.taskContext => 'task_context',
    _ => type.name,
  };
}

memory.MemoryType _memoryType(String value) {
  return switch (value) {
    'preference' => memory.MemoryType.preference,
    'project' => memory.MemoryType.project,
    'task_context' => memory.MemoryType.taskContext,
    'taskContext' => memory.MemoryType.taskContext,
    'person' => memory.MemoryType.person,
    'health' => memory.MemoryType.health,
    'finance' => memory.MemoryType.finance,
    'location' => memory.MemoryType.location,
    'credential' => memory.MemoryType.credential,
    'insight' => memory.MemoryType.insight,
    _ => memory.MemoryType.project,
  };
}

memory.MemoryConfidence _confidence(String value) {
  return switch (value) {
    'low' => memory.MemoryConfidence.low,
    'high' => memory.MemoryConfidence.high,
    _ => memory.MemoryConfidence.medium,
  };
}

memory.MemorySensitivity _sensitivity(String value) {
  return switch (value) {
    'medium' => memory.MemorySensitivity.medium,
    'high' => memory.MemorySensitivity.high,
    _ => memory.MemorySensitivity.low,
  };
}

String _durabilityName(memory.MemoryDurability durability) {
  return switch (durability) {
    memory.MemoryDurability.transient => 'transient',
    memory.MemoryDurability.durable => 'durable',
  };
}

memory.MemoryDurability _durability(String? value) {
  return switch (value) {
    'transient' => memory.MemoryDurability.transient,
    _ => memory.MemoryDurability.durable,
  };
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
