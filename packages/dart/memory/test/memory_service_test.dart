import 'package:test/test.dart';
import 'package:widenote_memory/memory.dart';

void main() {
  group('MemoryService', () {
    test('auto-accepts supported durable memory', () async {
      final repository = InMemoryMemoryRepository();
      final service = MemoryService(
        repository: repository,
        clock: () => DateTime.utc(2026, 6, 23),
        idFactory: _sequenceIds('memory'),
      );

      final medium = await service.submitProposal(_proposal());
      final high = await service.submitProposal(
        _proposal(
          id: 'proposal-2',
          key: 'preference.theme',
          body: 'The user prefers dark themes.',
          confidence: MemoryConfidence.high,
        ),
      );

      expect(medium.accepted, isTrue);
      expect(medium.proposal.status, MemoryProposalStatus.autoAccepted);
      expect(medium.item, isNotNull);
      expect(medium.item!.status, MemoryItemStatus.active);
      expect(medium.item!.confidence, MemoryConfidence.medium);
      expect(medium.item!.sensitivity, MemorySensitivity.low);
      expect(medium.item!.evidence.single.sourceId, 'record-1');
      expect(medium.item!.revision, 1);
      expect(medium.item!.tombstone, isNull);
      expect(high.accepted, isTrue);
      expect(high.item!.confidence, MemoryConfidence.high);
    });

    test(
      'routes sensitive, low-confidence, or unsupported proposals to review',
      () async {
        final repository = InMemoryMemoryRepository();
        final service = MemoryService(repository: repository);

        final missingEvidence = await service.submitProposal(
          _proposal(id: 'missing-evidence', evidence: const []),
        );
        final sensitive = await service.submitProposal(
          _proposal(
            id: 'sensitive',
            key: 'health.medication',
            memoryType: MemoryType.health,
            sensitivity: MemorySensitivity.high,
          ),
        );
        final reviewOnlyType = await service.submitProposal(
          _proposal(
            id: 'review-only',
            key: 'finance.account',
            memoryType: MemoryType.finance,
            sensitivity: MemorySensitivity.low,
          ),
        );
        final lowConfidence = await service.submitProposal(
          _proposal(
            id: 'low-confidence',
            key: 'preference.color',
            confidence: MemoryConfidence.low,
          ),
        );

        expect(missingEvidence.needsReview, isTrue);
        expect(missingEvidence.decision.reasons, contains('missing_evidence'));
        expect(sensitive.needsReview, isTrue);
        expect(sensitive.decision.reasons, contains('sensitive'));
        expect(reviewOnlyType.needsReview, isTrue);
        expect(reviewOnlyType.decision.reasons, contains('review_only_type'));
        expect(lowConfidence.needsReview, isTrue);
        expect(lowConfidence.decision.reasons, contains('low_confidence'));
        expect(await repository.listItems(), isEmpty);
        expect(
          await repository.listProposals(
            status: MemoryProposalStatus.needsReview,
          ),
          hasLength(4),
        );
      },
    );

    test('routes empty source refs to review', () async {
      final repository = InMemoryMemoryRepository();
      final service = MemoryService(repository: repository);

      final result = await service.submitProposal(
        _proposal(
          evidence: const [
            MemorySourceRef(sourceType: 'record', sourceId: 'record-empty'),
          ],
        ),
      );

      expect(result.needsReview, isTrue);
      expect(result.decision.reasons, contains('missing_evidence'));
      expect(await repository.listItems(), isEmpty);
    });

    test('accepts a reviewed proposal into durable Memory', () async {
      final repository = InMemoryMemoryRepository();
      final service = MemoryService(
        repository: repository,
        clock: () => DateTime.utc(2026, 6, 23, 3),
        idFactory: _sequenceIds('memory'),
      );

      final routed = await service.submitProposal(
        _proposal(id: 'review-me', confidence: MemoryConfidence.low),
      );
      final queue = await service.listReviewQueue();
      final accepted = await service.acceptProposal('review-me');

      expect(routed.needsReview, isTrue);
      expect(queue.single.id, 'review-me');
      expect(accepted.accepted, isTrue);
      expect(accepted.item!.id, 'memory-1');
      expect(accepted.item!.body, 'The user prefers concise editor layouts.');
      expect(accepted.proposal.status, MemoryProposalStatus.accepted);
      expect(accepted.proposal.policyReasons, contains('user_accepted'));
      expect(await service.listReviewQueue(), isEmpty);
    });

    test('edits a reviewed proposal before accepting it', () async {
      final repository = InMemoryMemoryRepository();
      final service = MemoryService(
        repository: repository,
        idFactory: () => 'memory-edited',
      );

      await service.submitProposal(
        _proposal(id: 'edit-me', confidence: MemoryConfidence.low),
      );
      final accepted = await service.acceptProposal(
        'edit-me',
        editedBody: 'The user prefers dense editor layouts.',
      );

      expect(accepted.item!.id, 'memory-edited');
      expect(accepted.item!.body, 'The user prefers dense editor layouts.');
      expect(accepted.proposal.body, 'The user prefers dense editor layouts.');
      expect(accepted.proposal.status, MemoryProposalStatus.accepted);
    });

    test('rejects a reviewed proposal without creating Memory', () async {
      final repository = InMemoryMemoryRepository();
      final service = MemoryService(repository: repository);

      await service.submitProposal(
        _proposal(id: 'reject-me', confidence: MemoryConfidence.low),
      );
      final rejected = await service.rejectProposal('reject-me');

      expect(rejected.rejected, isTrue);
      expect(rejected.proposal.status, MemoryProposalStatus.rejected);
      expect(rejected.proposal.policyReasons, contains('user_rejected'));
      expect(await repository.listItems(), isEmpty);
      expect(await service.listReviewQueue(), isEmpty);
    });

    test('accepts source refs with uri evidence', () async {
      final repository = InMemoryMemoryRepository();
      final service = MemoryService(
        repository: repository,
        idFactory: _sequenceIds('memory'),
      );

      final result = await service.submitProposal(
        _proposal(
          evidence: [
            MemorySourceRef(
              sourceType: 'record',
              sourceId: 'record-link',
              uri: Uri.parse('widenote://records/record-link'),
            ),
          ],
        ),
      );

      expect(result.accepted, isTrue);
      expect(result.item!.evidence.single.uri, isNotNull);
    });

    test('routes transient proposals to review', () async {
      final repository = InMemoryMemoryRepository();
      final service = MemoryService(repository: repository);

      final result = await service.submitProposal(
        _proposal(id: 'transient', durability: MemoryDurability.transient),
      );

      expect(result.needsReview, isTrue);
      expect(result.decision.reasons, contains('not_durable'));
      expect(await repository.listItems(), isEmpty);
    });

    test('never auto-accepts credential memory', () async {
      final repository = InMemoryMemoryRepository();
      final service = MemoryService(repository: repository);

      final result = await service.submitProposal(
        _proposal(
          id: 'credential',
          key: 'credential.api_token',
          body: 'The user keeps an API token in the dev keychain.',
          memoryType: MemoryType.credential,
          confidence: MemoryConfidence.high,
          sensitivity: MemorySensitivity.low,
        ),
      );

      expect(result.needsReview, isTrue);
      expect(result.decision.reasons, contains('review_only_type'));
      expect(await repository.listItems(), isEmpty);
    });

    test('routes conflicting proposals to review', () async {
      final repository = InMemoryMemoryRepository();
      final service = MemoryService(
        repository: repository,
        idFactory: _sequenceIds('memory'),
      );

      final accepted = await service.submitProposal(
        _proposal(
          id: 'original',
          key: 'preference.drink',
          body: 'The user prefers coffee.',
        ),
      );
      final conflict = await service.submitProposal(
        _proposal(
          id: 'conflict',
          key: 'preference.drink',
          body: 'The user prefers tea.',
        ),
      );

      expect(accepted.accepted, isTrue);
      expect(conflict.accepted, isFalse);
      expect(conflict.needsReview, isTrue);
      expect(conflict.decision.reasons, contains('conflict'));
      expect(conflict.proposal.conflictingMemoryIds, ['memory-1']);
      expect(
        await repository.listItems(status: MemoryItemStatus.active),
        hasLength(1),
      );
    });

    test('merges a reviewed conflict into an existing Memory item', () async {
      final repository = InMemoryMemoryRepository();
      final service = MemoryService(
        repository: repository,
        clock: _sequenceClock([
          DateTime.utc(2026, 6, 23, 4),
          DateTime.utc(2026, 6, 23, 5),
        ]),
        idFactory: _sequenceIds('memory'),
      );

      final original = await service.submitProposal(
        _proposal(
          id: 'original',
          key: 'preference.drink',
          body: 'The user prefers coffee.',
        ),
      );
      await service.submitProposal(
        _proposal(
          id: 'conflict',
          key: 'preference.drink',
          body: 'The user prefers tea.',
          evidence: const [
            MemorySourceRef(
              sourceType: 'record',
              sourceId: 'record-2',
              excerpt: 'I drink tea at night.',
            ),
          ],
        ),
      );
      final merged = await service.mergeProposal(
        'conflict',
        targetMemoryId: original.item!.id,
        mergedBody: 'The user prefers coffee during work and tea at night.',
      );

      expect(merged.merged, isTrue);
      expect(merged.item!.id, original.item!.id);
      expect(merged.item!.revision, 2);
      expect(
        merged.item!.body,
        'The user prefers coffee during work and tea at night.',
      );
      expect(merged.proposal.status, MemoryProposalStatus.merged);
      expect(merged.proposal.conflictingMemoryIds, contains(original.item!.id));
      expect(merged.item!.evidence, hasLength(2));
    });

    test('same key with same body does not conflict', () async {
      final repository = InMemoryMemoryRepository();
      final service = MemoryService(
        repository: repository,
        idFactory: _sequenceIds('memory'),
      );

      final original = await service.submitProposal(
        _proposal(
          id: 'original',
          key: 'preference.drink',
          body: 'The user prefers coffee.',
        ),
      );
      final repeated = await service.submitProposal(
        _proposal(
          id: 'repeated',
          key: 'preference.drink',
          body: 'The user prefers coffee.',
        ),
      );

      expect(original.accepted, isTrue);
      expect(repeated.accepted, isTrue);
      expect(repeated.conflicts, isEmpty);
      expect(repeated.decision.reasons, isNot(contains('conflict')));
    });

    test('deletes memory with a tombstone revision', () async {
      final repository = InMemoryMemoryRepository();
      final service = MemoryService(
        repository: repository,
        clock: _sequenceClock([
          DateTime.utc(2026, 6, 23, 1),
          DateTime.utc(2026, 6, 23, 2),
        ]),
        idFactory: () => 'memory-1',
      );

      final accepted = await service.submitProposal(_proposal());
      final deleted = await service.tombstoneMemory(
        accepted.item!.id,
        deletedBy: 'user',
        reason: 'incorrect',
      );

      expect(deleted.status, MemoryItemStatus.deleted);
      expect(deleted.revision, 2);
      expect(deleted.tombstone, isNotNull);
      expect(deleted.tombstone!.deletedBy, 'user');
      expect(deleted.tombstone!.reason, 'incorrect');
      expect(
        await repository.listItems(status: MemoryItemStatus.active),
        isEmpty,
      );
    });
  });
}

MemoryProposal _proposal({
  String id = 'proposal-1',
  String key = 'preference.editor',
  String body = 'The user prefers concise editor layouts.',
  List<MemorySourceRef>? evidence,
  MemoryType memoryType = MemoryType.preference,
  MemoryConfidence confidence = MemoryConfidence.medium,
  MemorySensitivity sensitivity = MemorySensitivity.low,
  MemoryDurability durability = MemoryDurability.durable,
}) {
  return MemoryProposal(
    id: id,
    key: key,
    body: body,
    evidence:
        evidence ??
        const [
          MemorySourceRef(
            sourceType: 'record',
            sourceId: 'record-1',
            excerpt: 'I prefer concise editor layouts.',
          ),
        ],
    memoryType: memoryType,
    confidence: confidence,
    sensitivity: sensitivity,
    durability: durability,
  );
}

MemoryIdFactory _sequenceIds(String prefix) {
  var next = 0;
  return () {
    next += 1;
    return '$prefix-$next';
  };
}

MemoryClock _sequenceClock(List<DateTime> values) {
  var index = 0;
  return () {
    final value = values[index];
    if (index < values.length - 1) {
      index += 1;
    }
    return value;
  };
}
