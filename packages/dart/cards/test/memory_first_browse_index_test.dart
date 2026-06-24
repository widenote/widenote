import 'package:test/test.dart';
import 'package:widenote_cards/widenote_cards.dart';

void main() {
  group('MemoryFirstBrowseIndex', () {
    test('groups source-linked items by local day newest first', () {
      final index = MemoryFirstBrowseIndex.build([
        _item(
          id: 'capture-1',
          kind: MemoryFirstTimelineItemKind.capture,
          body: 'First capture',
          createdAt: DateTime(2026, 6, 23, 9),
        ),
        _item(
          id: 'memory-1',
          kind: MemoryFirstTimelineItemKind.memory,
          body: 'Accepted Memory',
          createdAt: DateTime(2026, 6, 24, 9),
        ),
        _item(
          id: 'card-1',
          kind: MemoryFirstTimelineItemKind.card,
          body: 'Source card',
          createdAt: DateTime(2026, 6, 24, 10),
        ),
      ]);

      expect(index.items.map((item) => item.id), [
        'card-1',
        'memory-1',
        'capture-1',
      ]);
      expect(index.timeline().map((day) => day.label), [
        '2026-06-24',
        '2026-06-23',
      ]);
      expect(index.timeline().first.items.map((item) => item.id), [
        'card-1',
        'memory-1',
      ]);
    });

    test('filters by text and item kind without a persisted search index', () {
      final index = MemoryFirstBrowseIndex.build([
        _item(
          id: 'capture-1',
          kind: MemoryFirstTimelineItemKind.capture,
          title: 'Record',
          body: 'Met Lin about timeline search.',
        ),
        _item(
          id: 'memory-1',
          kind: MemoryFirstTimelineItemKind.memory,
          title: 'Memory',
          body: 'Lin prefers source-linked cards.',
        ),
        _item(
          id: 'todo-1',
          kind: MemoryFirstTimelineItemKind.todo,
          title: 'Todo',
          body: 'Follow up with Chen.',
        ),
      ]);

      expect(
        index
            .search(const MemoryFirstTimelineFilter(query: 'Lin source-linked'))
            .map((item) => item.id),
        ['memory-1'],
      );
      expect(
        index
            .search(
              const MemoryFirstTimelineFilter(
                query: 'follow',
                kinds: {MemoryFirstTimelineItemKind.todo},
              ),
            )
            .map((item) => item.id),
        ['todo-1'],
      );
      expect(
        index.search(
          const MemoryFirstTimelineFilter(
            query: 'follow',
            kinds: {MemoryFirstTimelineItemKind.memory},
          ),
        ),
        isEmpty,
      );
    });

    test('parses and deduplicates source refs from read-model json', () {
      final links = sourceLinksFromJsonList(<Object?>[
        const <String, Object?>{
          'kind': 'capture',
          'id': 'capture-1',
          'excerpt': 'raw capture',
        },
        const <String, Object?>{
          'source_type': 'capture',
          'source_id': 'capture-1',
          'evidence_text': 'duplicate',
        },
        const <String, Object?>{
          'source_type': 'memory',
          'source_id': 'memory-1',
          'uri': 'widenote://memory/memory-1',
        },
        const <String, Object?>{'kind': 'broken'},
      ]);

      expect(links.map(sourceLinkKey), [
        'capture:capture-1',
        'memory:memory-1',
      ]);
      expect(links.first.excerpt, 'raw capture');
      expect(links.last.uri.toString(), 'widenote://memory/memory-1');
    });

    test('builds card detail with related Memory, record, and todo', () {
      final index = MemoryFirstBrowseIndex.build([
        _item(
          id: 'card-1',
          kind: MemoryFirstTimelineItemKind.card,
          title: 'Card',
          body: 'Card body',
          links: const <SourceLink>[
            SourceLink(kind: 'capture', id: 'capture-1'),
            SourceLink(kind: 'memory', id: 'memory-1'),
          ],
        ),
        _item(
          id: 'capture-1',
          kind: MemoryFirstTimelineItemKind.capture,
          body: 'Raw capture',
          links: const <SourceLink>[
            SourceLink(kind: 'capture', id: 'capture-1'),
          ],
        ),
        _item(
          id: 'memory-1',
          kind: MemoryFirstTimelineItemKind.memory,
          body: 'Accepted Memory',
          links: const <SourceLink>[
            SourceLink(kind: 'memory', id: 'memory-1'),
            SourceLink(kind: 'capture', id: 'capture-1'),
          ],
        ),
        _item(
          id: 'todo-1',
          kind: MemoryFirstTimelineItemKind.todo,
          body: 'Follow up',
          links: const <SourceLink>[
            SourceLink(kind: 'capture', id: 'capture-1'),
          ],
        ),
      ]);

      final detail = index.cardDetail('card-1')!;

      expect(detail.card.body, 'Card body');
      expect(detail.relatedRecords.map((item) => item.id), ['capture-1']);
      expect(detail.relatedMemories.map((item) => item.id), ['memory-1']);
      expect(detail.relatedTodos.map((item) => item.id), ['todo-1']);
    });
  });
}

MemoryFirstTimelineItem _item({
  required String id,
  required MemoryFirstTimelineItemKind kind,
  String? title,
  String body = '',
  DateTime? createdAt,
  List<SourceLink>? links,
}) {
  return MemoryFirstTimelineItem(
    id: id,
    kind: kind,
    title: title ?? kind.name,
    body: body,
    createdAt: createdAt ?? DateTime(2026, 6, 24),
    sourceLinks: links ?? <SourceLink>[SourceLink(kind: kind.name, id: id)],
  );
}
