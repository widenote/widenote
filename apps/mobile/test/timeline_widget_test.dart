import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/app/widenote_app.dart';
import 'package:widenote_mobile/features/timeline/application/timeline_repository.dart';
import 'package:widenote_mobile/features/timeline/presentation/timeline_page.dart';

void main() {
  testWidgets('timeline renders loading and empty states', (tester) async {
    final completer = Completer<TimelineSnapshot>();

    await _pumpTimelinePage(
      tester,
      overrides: [
        timelineRepositoryProvider.overrideWithValue(
          _FutureTimelineRepository(completer.future),
        ),
      ],
    );

    expect(find.byKey(const Key('timeline-loading')), findsOneWidget);

    completer.complete(TimelineSnapshot.fromItems(const []));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('timeline-page')), findsOneWidget);
    expect(find.byKey(const Key('timeline-empty')), findsOneWidget);
    expect(find.text('No timeline items yet'), findsOneWidget);
  });

  testWidgets('timeline renders error state and retry action', (tester) async {
    await _pumpTimelinePage(
      tester,
      overrides: [
        timelineRepositoryProvider.overrideWithValue(
          const _ThrowingTimelineRepository(),
        ),
      ],
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('timeline-error')), findsOneWidget);
    expect(find.text('Timeline unavailable'), findsOneWidget);
    expect(find.byKey(const Key('timeline-retry-button')), findsOneWidget);
  });

  testWidgets('timeline opens card detail with refs and related items', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    _seedTimeline(database);

    await _pumpApp(tester, database: database);

    await tester.tap(find.byKey(const Key('open-timeline-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('timeline-page')), findsOneWidget);
    expect(find.byKey(const Key('timeline-item-card-1')), findsOneWidget);
    expect(find.byKey(const Key('timeline-item-capture-1')), findsOneWidget);
    expect(find.byKey(const Key('timeline-item-memory-1')), findsOneWidget);
    expect(find.byKey(const Key('timeline-item-todo-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('timeline-item-card-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('card-detail-page')), findsOneWidget);
    expect(find.byKey(const Key('card-detail-body')), findsOneWidget);
    expect(find.text('Project Alpha kickoff notes.'), findsWidgets);
    expect(
      find.byKey(const Key('source-ref-capture-capture-1')),
      findsOneWidget,
    );
    expect(find.text('Related records'), findsOneWidget);
    expect(find.text('Related Memory'), findsOneWidget);
    expect(find.text('Related todos'), findsOneWidget);
    expect(find.byKey(const Key('timeline-item-memory-1')), findsOneWidget);
    expect(find.byKey(const Key('timeline-item-todo-1')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('timeline-item-memory-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timeline-item-memory-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('timeline-item-detail-page')), findsOneWidget);
    expect(find.text('Memory Detail'), findsOneWidget);
    expect(find.text('Lin prefers source-linked cards.'), findsWidgets);

    await tester.tap(find.byKey(const Key('timeline-item-detail-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timeline-item-card-1')));
    await tester.pumpAndSettle();

    final sourceRefButton = find.byKey(
      const Key('open-source-ref-capture-capture-1'),
    );
    await tester.ensureVisible(sourceRefButton);
    await tester.pumpAndSettle();
    await tester.tap(sourceRefButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('timeline-item-detail-page')), findsOneWidget);
    expect(find.text('Capture Detail'), findsOneWidget);
    expect(find.text('Project Alpha kickoff notes.'), findsWidgets);

    await tester.tap(find.byKey(const Key('timeline-item-detail-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-page')), findsOneWidget);
  });

  testWidgets('search filters local cards Memory captures and todos', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    _seedTimeline(database);

    await _pumpApp(tester, database: database);

    await tester.tap(find.byKey(const Key('open-timeline-search-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('timeline-search-page')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('timeline-search-field')),
      'Follow up',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timeline-filter-todo')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('timeline-item-todo-1')), findsOneWidget);
    expect(find.byKey(const Key('timeline-item-card-1')), findsNothing);

    await tester.tap(find.byKey(const Key('timeline-filter-insight')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('timeline-search-field')),
      'source summary',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('timeline-item-insight-1')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('timeline-search-field')),
      'No matching local item',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('timeline-search-empty-results')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('timeline-filter-memory')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('timeline-search-field')),
      'source-linked cards',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('timeline-item-memory-1')), findsOneWidget);
  });
}

Future<void> _pumpTimelinePage(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: TimelinePage()),
    ),
  );
  await tester.pump();
}

Future<void> _pumpApp(
  WidgetTester tester, {
  WideNoteLocalDatabase? database,
  List<Override> overrides = const [],
}) async {
  final localDatabase = database ?? WideNoteLocalDatabase.inMemory();
  addTearDown(localDatabase.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(localDatabase),
        ...overrides,
      ],
      child: const WideNoteApp(locale: Locale('en')),
    ),
  );
  await tester.pumpAndSettle();
}

void _seedTimeline(WideNoteLocalDatabase database) {
  final captureAt = DateTime.utc(2026, 6, 24, 1);
  final memoryAt = DateTime.utc(2026, 6, 24, 2);
  final cardAt = DateTime.utc(2026, 6, 24, 3);
  final todoAt = DateTime.utc(2026, 6, 24, 4);

  database.eventLog.append(
    EventLogEntry(
      id: 'capture-1',
      type: runtime.WnEventTypes.captureCreated,
      actor: 'user',
      subjectRef: const <String, Object?>{'kind': 'capture', 'id': 'capture-1'},
      payload: const <String, Object?>{'text': 'Project Alpha kickoff notes.'},
      createdAt: captureAt,
    ),
  );
  database.memoryItems.insert(
    MemoryItemRecord(
      id: 'memory-1',
      key: 'project.alpha',
      body: 'Lin prefers source-linked cards.',
      sourceRefs: const <Object?>[
        <String, Object?>{
          'kind': 'capture',
          'id': 'capture-1',
          'excerpt': 'Project Alpha kickoff notes.',
        },
      ],
      memoryType: 'project',
      confidence: 'high',
      createdAt: memoryAt,
      updatedAt: memoryAt,
    ),
  );
  database.cards.insert(
    CardRecord(
      id: 'card-1',
      cardKind: 'capture_summary',
      title: 'Card: Project Alpha',
      body: 'Project Alpha kickoff notes.',
      sourceRefs: const <Object?>[
        <String, Object?>{
          'kind': 'capture',
          'id': 'capture-1',
          'excerpt': 'Project Alpha kickoff notes.',
        },
        <String, Object?>{'kind': 'memory', 'id': 'memory-1'},
      ],
      createdAt: cardAt,
      updatedAt: cardAt,
    ),
  );
  database.insights.insert(
    InsightRecord(
      id: 'insight-1',
      insightKind: 'summary',
      title: 'Latest source summary',
      summary: 'Project Alpha now has a source-linked card.',
      sourceRefs: const <Object?>[
        <String, Object?>{'kind': 'capture', 'id': 'capture-1'},
      ],
      createdAt: cardAt,
      updatedAt: cardAt,
    ),
  );
  database.eventLog.append(
    EventLogEntry(
      id: 'todo-1',
      type: runtime.WnEventTypes.todoSuggested,
      actor: 'agent',
      causationId: 'capture-1',
      payload: const <String, Object?>{
        'text': 'Follow up Project Alpha with Chen.',
        'source_event_id': 'capture-1',
      },
      createdAt: todoAt,
    ),
  );
}

final class _FutureTimelineRepository implements TimelineRepository {
  const _FutureTimelineRepository(this._future);

  final Future<TimelineSnapshot> _future;

  @override
  Future<TimelineSnapshot> loadSnapshot() => _future;
}

final class _ThrowingTimelineRepository implements TimelineRepository {
  const _ThrowingTimelineRepository();

  @override
  Future<TimelineSnapshot> loadSnapshot() {
    throw StateError('read model unavailable');
  }
}
