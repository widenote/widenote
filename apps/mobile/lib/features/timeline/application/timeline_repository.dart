import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_cards/widenote_cards.dart';
import 'package:widenote_local_db/widenote_local_db.dart';

import '../../../app/local_database.dart';

final timelineRepositoryProvider = Provider<TimelineRepository>((ref) {
  return LocalDbTimelineRepository(ref.watch(localDatabaseProvider));
});

final timelineSnapshotProvider = FutureProvider.autoDispose<TimelineSnapshot>((
  ref,
) {
  return ref.watch(timelineRepositoryProvider).loadSnapshot();
});

final timelineCardDetailProvider = FutureProvider.autoDispose
    .family<MemoryFirstCardDetail?, String>((ref, cardId) async {
      final snapshot = await ref
          .watch(timelineRepositoryProvider)
          .loadSnapshot();
      return snapshot.cardDetail(cardId);
    });

final timelineItemDetailProvider = FutureProvider.autoDispose
    .family<MemoryFirstTimelineItem?, String>((ref, itemId) async {
      final snapshot = await ref
          .watch(timelineRepositoryProvider)
          .loadSnapshot();
      return snapshot.itemById(itemId);
    });

abstract interface class TimelineRepository {
  Future<TimelineSnapshot> loadSnapshot();
}

final class TimelineSnapshot {
  const TimelineSnapshot(this.index);

  factory TimelineSnapshot.fromItems(Iterable<MemoryFirstTimelineItem> items) {
    return TimelineSnapshot(MemoryFirstBrowseIndex.build(items));
  }

  final MemoryFirstBrowseIndex index;

  bool get isEmpty => index.isEmpty;

  List<MemoryFirstTimelineDay> timeline([
    MemoryFirstTimelineFilter filter = const MemoryFirstTimelineFilter(),
  ]) {
    return index.timeline(filter);
  }

  List<MemoryFirstTimelineItem> search([
    MemoryFirstTimelineFilter filter = const MemoryFirstTimelineFilter(),
  ]) {
    return index.search(filter);
  }

  MemoryFirstTimelineItem? itemById(String itemId) {
    final direct = index.itemById(itemId);
    if (direct != null) {
      return direct;
    }
    for (final item in index.items) {
      if (item.sourceLinks.any((link) => link.id == itemId)) {
        return item;
      }
    }
    return null;
  }

  MemoryFirstCardDetail? cardDetail(String cardId) {
    return index.cardDetail(cardId);
  }
}

final class LocalDbTimelineRepository implements TimelineRepository {
  const LocalDbTimelineRepository(this._database);

  final WideNoteLocalDatabase _database;

  @override
  Future<TimelineSnapshot> loadSnapshot() async {
    return TimelineSnapshot.fromItems(<MemoryFirstTimelineItem>[
      ..._captureItems(),
      ..._cardItems(),
      ..._insightItems(),
      ..._memoryItems(),
      ..._todoRecordItems(),
    ]);
  }

  List<MemoryFirstTimelineItem> _captureItems() {
    return _database.eventLog
        .readByType(runtime.WnEventTypes.captureCreated, limit: 200)
        .map((event) {
          final body = _string(event.payload['text']) ?? 'Untitled capture';
          final captureId = event.subjectRefId ?? event.id;
          return MemoryFirstTimelineItem(
            id: captureId,
            kind: MemoryFirstTimelineItemKind.capture,
            title: 'Capture',
            body: body,
            createdAt: event.createdAt,
            status: event.status,
            sourceLinks: _linksWithSelf(
              kind: 'capture',
              id: captureId,
              excerpt: body,
              links: <SourceLink>[
                SourceLink(kind: 'event', id: event.id, excerpt: body),
              ],
            ),
            metadata: <String, Object?>{
              'event_type': event.type,
              'event_id': event.id,
            },
          );
        })
        .toList(growable: false);
  }

  List<MemoryFirstTimelineItem> _cardItems() {
    return _database.cards
        .readAll(status: 'active', limit: 200)
        .map(
          (card) => MemoryFirstTimelineItem(
            id: card.id,
            kind: MemoryFirstTimelineItemKind.card,
            title: card.title,
            body: card.body,
            createdAt: card.createdAt,
            status: card.status,
            sourceLinks: sourceLinksOrSelf(
              kind: 'card',
              id: card.id,
              excerpt: card.body,
              links: sourceLinksFromJsonList(card.sourceRefs),
            ),
            metadata: <String, Object?>{'card_kind': card.cardKind},
          ),
        )
        .toList(growable: false);
  }

  List<MemoryFirstTimelineItem> _insightItems() {
    return _database.insights
        .readAll(status: 'active', limit: 200)
        .map(
          (insight) => MemoryFirstTimelineItem(
            id: insight.id,
            kind: MemoryFirstTimelineItemKind.insight,
            title: insight.title,
            body: insight.summary,
            createdAt: insight.createdAt,
            status: insight.status,
            sourceLinks: sourceLinksOrSelf(
              kind: 'insight',
              id: insight.id,
              excerpt: insight.summary,
              links: sourceLinksFromJsonList(insight.sourceRefs),
            ),
            metadata: <String, Object?>{
              'insight_kind': insight.insightKind,
              if (insight.metricLabel != null)
                'metric_label': insight.metricLabel,
              if (insight.metricValue != null)
                'metric_value': insight.metricValue,
            },
          ),
        )
        .toList(growable: false);
  }

  List<MemoryFirstTimelineItem> _memoryItems() {
    return _database.memoryItems
        .readAll(status: 'active', limit: 200)
        .where((item) => !item.tombstone && item.body.trim().isNotEmpty)
        .map(
          (item) => MemoryFirstTimelineItem(
            id: item.id,
            kind: MemoryFirstTimelineItemKind.memory,
            title: 'Memory',
            body: item.body,
            createdAt: item.updatedAt,
            status: item.status,
            sourceLinks: _linksWithSelf(
              kind: 'memory',
              id: item.id,
              excerpt: item.body,
              links: <SourceLink>[
                ...sourceLinksFromJsonList(item.sourceRefs),
                if (item.sourceEventId != null)
                  SourceLink(kind: 'event', id: item.sourceEventId!),
                if (item.sourceCaptureId != null)
                  SourceLink(kind: 'capture', id: item.sourceCaptureId!),
              ],
            ),
            metadata: <String, Object?>{
              'memory_key': item.key,
              'memory_type': item.memoryType,
              'confidence': item.confidence,
              'sensitivity': item.sensitivity,
            },
          ),
        )
        .toList(growable: false);
  }

  List<MemoryFirstTimelineItem> _todoRecordItems() {
    return _database.todos
        .readAll(limit: 200)
        .map((todo) {
          final body =
              _string(todo.payload['title']) ??
              _string(todo.payload['text']) ??
              'Untitled todo';
          return MemoryFirstTimelineItem(
            id: todo.id,
            kind: MemoryFirstTimelineItemKind.todo,
            title: 'Todo',
            body: body,
            createdAt: todo.updatedAt,
            status: todo.status,
            sourceLinks: _linksWithSelf(
              kind: 'todo',
              id: todo.id,
              excerpt: body,
              links: <SourceLink>[
                if (todo.sourceEventId != null)
                  SourceLink(kind: 'event', id: todo.sourceEventId!),
                if (todo.sourceCaptureId != null)
                  SourceLink(kind: 'capture', id: todo.sourceCaptureId!),
              ],
            ),
            metadata: <String, Object?>{'record_type': 'todo'},
          );
        })
        .toList(growable: false);
  }
}

List<SourceLink> _linksWithSelf({
  required String kind,
  required String id,
  String? excerpt,
  List<SourceLink> links = const <SourceLink>[],
}) {
  return dedupeSourceLinks(<SourceLink>[
    SourceLink(kind: kind, id: id, excerpt: excerpt),
    ...links,
  ]);
}

String? _string(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}
