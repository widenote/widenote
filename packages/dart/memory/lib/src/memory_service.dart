import 'memory_models.dart';
import 'memory_policy.dart';
import 'memory_repository.dart';

typedef MemoryClock = DateTime Function();
typedef MemoryIdFactory = String Function();

enum MemoryReviewAction { accepted, rejected, merged }

final class MemoryWriteResult {
  const MemoryWriteResult({
    required this.proposal,
    required this.decision,
    required this.conflicts,
    this.item,
  });

  final MemoryProposal proposal;
  final MemoryPolicyDecision decision;
  final List<MemoryItem> conflicts;
  final MemoryItem? item;

  bool get accepted => item != null;
  bool get needsReview => proposal.status == MemoryProposalStatus.needsReview;
}

final class MemoryReviewResult {
  const MemoryReviewResult({
    required this.proposal,
    required this.action,
    this.item,
  });

  final MemoryProposal proposal;
  final MemoryReviewAction action;
  final MemoryItem? item;

  bool get accepted => action == MemoryReviewAction.accepted && item != null;

  bool get rejected => action == MemoryReviewAction.rejected;

  bool get merged => action == MemoryReviewAction.merged && item != null;
}

final class MemoryService {
  MemoryService({
    required MemoryRepository repository,
    MemoryPolicy policy = const DefaultMemoryPolicy(),
    MemoryClock? clock,
    MemoryIdFactory? idFactory,
  }) : _repository = repository,
       _policy = policy,
       _clock = clock ?? DateTime.now,
       _idFactory = idFactory ?? _defaultIdFactory();

  final MemoryRepository _repository;
  final MemoryPolicy _policy;
  final MemoryClock _clock;
  final MemoryIdFactory _idFactory;

  Future<MemoryWriteResult> submitProposal(MemoryProposal proposal) async {
    final conflicts = await _repository.findConflictingItems(proposal);
    final decision = _policy.evaluate(
      proposal,
      MemoryPolicyContext(hasConflict: conflicts.isNotEmpty),
    );

    if (decision.shouldAutoAccept) {
      return _autoAccept(proposal, decision, conflicts);
    }

    return _routeToReview(proposal, decision, conflicts);
  }

  Future<List<MemoryProposal>> listReviewQueue() {
    return _repository.listProposals(status: MemoryProposalStatus.needsReview);
  }

  Future<MemoryReviewResult> acceptProposal(
    String proposalId, {
    String? editedBody,
  }) async {
    final proposal = await _requireProposal(proposalId);
    final body = _reviewBody(editedBody, proposal.body);
    final now = _clock();
    final item = MemoryItem(
      id: _idFactory(),
      key: proposal.key,
      body: body,
      evidence: proposal.evidence,
      memoryType: proposal.memoryType,
      status: MemoryItemStatus.active,
      confidence: proposal.confidence,
      sensitivity: proposal.sensitivity,
      revision: 1,
      createdAt: now,
      updatedAt: now,
    );
    final savedItem = await _repository.saveItem(item);
    final savedProposal = await _repository.saveProposal(
      proposal.copyWith(
        body: body,
        status: MemoryProposalStatus.accepted,
        policyReasons: _appendUnique(proposal.policyReasons, 'user_accepted'),
      ),
    );

    return MemoryReviewResult(
      proposal: savedProposal,
      action: MemoryReviewAction.accepted,
      item: savedItem,
    );
  }

  Future<MemoryReviewResult> rejectProposal(
    String proposalId, {
    String reason = 'user_rejected',
  }) async {
    final proposal = await _requireProposal(proposalId);
    final savedProposal = await _repository.saveProposal(
      proposal.copyWith(
        status: MemoryProposalStatus.rejected,
        policyReasons: _appendUnique(proposal.policyReasons, reason),
      ),
    );

    return MemoryReviewResult(
      proposal: savedProposal,
      action: MemoryReviewAction.rejected,
    );
  }

  Future<MemoryReviewResult> mergeProposal(
    String proposalId, {
    required String targetMemoryId,
    String? mergedBody,
  }) async {
    final proposal = await _requireProposal(proposalId);
    final target = await _repository.findItemById(targetMemoryId);
    if (target == null || target.status != MemoryItemStatus.active) {
      throw StateError('Active Memory item not found: $targetMemoryId');
    }

    final now = _clock();
    final body = _reviewBody(mergedBody, proposal.body);
    final mergedItem = target.copyWith(
      body: body,
      evidence: _mergeEvidence(target.evidence, proposal.evidence),
      confidence: proposal.confidence,
      sensitivity: proposal.sensitivity,
      revision: target.revision + 1,
      updatedAt: now,
    );
    final savedItem = await _repository.saveItem(mergedItem);
    final savedProposal = await _repository.saveProposal(
      proposal.copyWith(
        body: body,
        status: MemoryProposalStatus.merged,
        policyReasons: _appendUnique(proposal.policyReasons, 'user_merged'),
        conflictingMemoryIds: _appendUnique(
          proposal.conflictingMemoryIds,
          targetMemoryId,
        ),
      ),
    );

    return MemoryReviewResult(
      proposal: savedProposal,
      action: MemoryReviewAction.merged,
      item: savedItem,
    );
  }

  Future<MemoryItem> tombstoneMemory(
    String id, {
    required String deletedBy,
    required String reason,
  }) async {
    final existing = await _repository.findItemById(id);
    if (existing == null) {
      throw StateError('Memory item not found: $id');
    }

    final now = _clock();
    final deleted = existing.copyWith(
      status: MemoryItemStatus.deleted,
      revision: existing.revision + 1,
      updatedAt: now,
      tombstone: MemoryTombstone(
        deletedAt: now,
        deletedBy: deletedBy,
        reason: reason,
      ),
    );
    return _repository.saveItem(deleted);
  }

  Future<MemoryWriteResult> _autoAccept(
    MemoryProposal proposal,
    MemoryPolicyDecision decision,
    List<MemoryItem> conflicts,
  ) async {
    final now = _clock();
    final item = MemoryItem(
      id: _idFactory(),
      key: proposal.key,
      body: proposal.body,
      evidence: proposal.evidence,
      memoryType: proposal.memoryType,
      status: MemoryItemStatus.active,
      confidence: proposal.confidence,
      sensitivity: proposal.sensitivity,
      revision: 1,
      createdAt: now,
      updatedAt: now,
    );
    final savedItem = await _repository.saveItem(item);
    final savedProposal = await _repository.saveProposal(
      proposal.copyWith(
        status: MemoryProposalStatus.autoAccepted,
        policyReasons: decision.reasons,
      ),
    );

    return MemoryWriteResult(
      proposal: savedProposal,
      decision: decision,
      conflicts: conflicts,
      item: savedItem,
    );
  }

  Future<MemoryWriteResult> _routeToReview(
    MemoryProposal proposal,
    MemoryPolicyDecision decision,
    List<MemoryItem> conflicts,
  ) async {
    final savedProposal = await _repository.saveProposal(
      proposal.copyWith(
        status: MemoryProposalStatus.needsReview,
        policyReasons: decision.reasons,
        conflictingMemoryIds: conflicts.map((item) => item.id).toList(),
      ),
    );

    return MemoryWriteResult(
      proposal: savedProposal,
      decision: decision,
      conflicts: conflicts,
    );
  }

  Future<MemoryProposal> _requireProposal(String proposalId) async {
    final proposal = await _repository.findProposalById(proposalId);
    if (proposal == null) {
      throw StateError('Memory proposal not found: $proposalId');
    }
    if (proposal.status != MemoryProposalStatus.needsReview) {
      throw StateError(
        'Memory proposal is not awaiting review: '
        '$proposalId (${proposal.status.name})',
      );
    }
    return proposal;
  }
}

MemoryIdFactory _defaultIdFactory() {
  var nextId = 0;
  return () {
    nextId += 1;
    return 'memory_$nextId';
  };
}

String _reviewBody(String? editedBody, String fallback) {
  if (editedBody == null) {
    return fallback;
  }
  final trimmed = editedBody.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(editedBody, 'editedBody', 'must not be empty');
  }
  return trimmed;
}

List<String> _appendUnique(List<String> values, String value) {
  if (values.contains(value)) {
    return values;
  }
  return <String>[...values, value];
}

List<MemorySourceRef> _mergeEvidence(
  List<MemorySourceRef> existing,
  List<MemorySourceRef> incoming,
) {
  final seen = <String>{
    for (final ref in existing)
      '${ref.sourceType}:${ref.sourceId}:${ref.excerpt ?? ''}:${ref.uri ?? ''}',
  };
  final merged = <MemorySourceRef>[...existing];
  for (final ref in incoming) {
    final key =
        '${ref.sourceType}:${ref.sourceId}:${ref.excerpt ?? ''}:${ref.uri ?? ''}';
    if (seen.add(key)) {
      merged.add(ref);
    }
  }
  return merged;
}
