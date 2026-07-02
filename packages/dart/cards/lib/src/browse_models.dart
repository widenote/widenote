import 'models.dart';

enum MemoryFirstTimelineItemKind { capture, card, insight, memory, todo }

final class MemoryFirstTimelineItem {
  MemoryFirstTimelineItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.sourceLinks,
    this.status = 'active',
    this.metadata = const <String, Object?>{},
  }) {
    if (sourceLinks.isEmpty) {
      throw ArgumentError.value(
        sourceLinks,
        'sourceLinks',
        'must not be empty',
      );
    }
  }

  final String id;
  final MemoryFirstTimelineItemKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final List<SourceLink> sourceLinks;
  final String status;
  final CardJsonMap metadata;

  bool get isSourceLinked => sourceLinks.isNotEmpty;
}

final class MemoryFirstTimelineDay {
  const MemoryFirstTimelineDay({
    required this.day,
    required this.label,
    required this.items,
  });

  final DateTime day;
  final String label;
  final List<MemoryFirstTimelineItem> items;
}

final class MemoryFirstTimelineFilter {
  const MemoryFirstTimelineFilter({
    this.query = '',
    this.kinds = const <MemoryFirstTimelineItemKind>{},
  });

  /// Reserved for model-backed retrieval.
  ///
  /// `MemoryFirstBrowseIndex.search` intentionally ignores this value so this
  /// package does not perform local substring matching over user text.
  final String query;
  final Set<MemoryFirstTimelineItemKind> kinds;

  bool get isEmpty => query.trim().isEmpty && kinds.isEmpty;
}

final class MemoryFirstCardDetail {
  const MemoryFirstCardDetail({required this.card, required this.relatedItems});

  final MemoryFirstTimelineItem card;
  final List<MemoryFirstTimelineItem> relatedItems;

  Iterable<MemoryFirstTimelineItem> get relatedRecords {
    return relatedItems.where(
      (item) => item.kind == MemoryFirstTimelineItemKind.capture,
    );
  }

  Iterable<MemoryFirstTimelineItem> get relatedMemories {
    return relatedItems.where(
      (item) => item.kind == MemoryFirstTimelineItemKind.memory,
    );
  }

  Iterable<MemoryFirstTimelineItem> get relatedTodos {
    return relatedItems.where(
      (item) => item.kind == MemoryFirstTimelineItemKind.todo,
    );
  }
}
