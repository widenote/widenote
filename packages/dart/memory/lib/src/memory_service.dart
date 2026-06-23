import 'memory_models.dart';
import 'memory_policy.dart';
import 'memory_repository.dart';

typedef MemoryClock = DateTime Function();
typedef MemoryIdFactory = String Function();

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
}

MemoryIdFactory _defaultIdFactory() {
  var nextId = 0;
  return () {
    nextId += 1;
    return 'memory_$nextId';
  };
}
