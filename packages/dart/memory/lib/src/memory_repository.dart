import 'memory_models.dart';

abstract interface class MemoryRepository {
  Future<MemoryItem> saveItem(MemoryItem item);

  Future<MemoryProposal> saveProposal(MemoryProposal proposal);

  Future<MemoryItem?> findItemById(String id);

  Future<MemoryProposal?> findProposalById(String id);

  Future<List<MemoryItem>> listItems({MemoryItemStatus? status});

  Future<List<MemoryProposal>> listProposals({MemoryProposalStatus? status});

  Future<List<MemoryItem>> findConflictingItems(MemoryProposal proposal);
}

final class InMemoryMemoryRepository implements MemoryRepository {
  final Map<String, MemoryItem> _items = <String, MemoryItem>{};
  final Map<String, MemoryProposal> _proposals = <String, MemoryProposal>{};

  @override
  Future<MemoryItem> saveItem(MemoryItem item) async {
    _items[item.id] = item;
    return item;
  }

  @override
  Future<MemoryProposal> saveProposal(MemoryProposal proposal) async {
    _proposals[proposal.id] = proposal;
    return proposal;
  }

  @override
  Future<MemoryItem?> findItemById(String id) async {
    return _items[id];
  }

  @override
  Future<MemoryProposal?> findProposalById(String id) async {
    return _proposals[id];
  }

  @override
  Future<List<MemoryItem>> listItems({MemoryItemStatus? status}) async {
    return _items.values
        .where((item) {
          return status == null || item.status == status;
        })
        .toList(growable: false);
  }

  @override
  Future<List<MemoryProposal>> listProposals({
    MemoryProposalStatus? status,
  }) async {
    return _proposals.values
        .where((proposal) {
          return status == null || proposal.status == status;
        })
        .toList(growable: false);
  }

  @override
  Future<List<MemoryItem>> findConflictingItems(MemoryProposal proposal) async {
    return _items.values
        .where((item) {
          return item.status == MemoryItemStatus.active &&
              item.key == proposal.key &&
              item.body.trim() != proposal.body.trim();
        })
        .toList(growable: false);
  }
}
