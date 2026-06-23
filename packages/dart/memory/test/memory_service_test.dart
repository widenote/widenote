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
