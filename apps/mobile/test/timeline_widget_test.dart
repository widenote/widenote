import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/app/widenote_app.dart';
import 'package:widenote_mobile/features/timeline/application/timeline_repository.dart';
import 'package:widenote_mobile/features/timeline/presentation/timeline_page.dart';
import 'package:widenote_mobile/l10n/l10n.dart';

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
    expect(find.byKey(const Key('timeline-item-evt-todo-1')), findsNothing);
    expect(
      find.text('Project Alpha insight keeps one cited claim.'),
      findsOneWidget,
    );
    expect(find.text('1 source-linked'), findsOneWidget);

    final semantics = tester.ensureSemantics();
    try {
      _expectButtonSemantics(tester, const Key('timeline-item-card-1'), 'Card');
    } finally {
      semantics.dispose();
    }

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
    expect(find.byKey(const Key('card-detail-page')), findsOneWidget);

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
    expect(find.byKey(const Key('card-detail-page')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-page')), findsOneWidget);
  });

  testWidgets('timeline system back unwinds search detail and source stacks', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    _seedTimeline(database);

    await _pumpApp(tester, database: database);

    await tester.tap(find.byKey(const Key('open-timeline-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-page')), findsOneWidget);

    await tester.tap(find.byKey(const Key('timeline-search-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-search-page')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('timeline-search-back'))).dx,
      lessThan(tester.getTopLeft(find.text('Search')).dx),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-page')), findsOneWidget);

    await tester.tap(find.byKey(const Key('timeline-search-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timeline-item-card-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('card-detail-page')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('card-detail-back'))).dx,
      lessThan(tester.getTopLeft(find.text('Card Detail')).dx),
    );

    final sourceRefButton = find.byKey(
      const Key('open-source-ref-capture-capture-1'),
    );
    await tester.ensureVisible(sourceRefButton);
    await tester.pumpAndSettle();
    await tester.tap(sourceRefButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-item-detail-page')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('card-detail-page')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-search-page')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-page')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('timeline-item-memory-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timeline-item-memory-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-item-detail-page')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('timeline-item-detail-back'))).dx,
      lessThan(tester.getTopLeft(find.text('Memory Detail')).dx),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-page')), findsOneWidget);
  });

  testWidgets('timeline renders saved capture before runtime event', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    final createdAt = DateTime.utc(2026, 7, 2, 10);
    database.captures.insert(
      CaptureRecord(
        id: 'capture-pending',
        sourceType: 'manual',
        status: 'Saved locally, processing',
        payload: const <String, Object?>{
          'text': 'A saved capture is still being processed.',
        },
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );

    await _pumpTimelinePage(
      tester,
      overrides: [
        localDatabaseProvider.overrideWithValue(database),
        timelineRepositoryProvider.overrideWithValue(
          LocalDbTimelineRepository(database),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('timeline-item-capture-pending')),
      findsOneWidget,
    );
    expect(
      find.text('A saved capture is still being processed.'),
      findsOneWidget,
    );
    expect(find.textContaining('Saved locally, processing'), findsOneWidget);
  });

  testWidgets('timeline opens structured insight detail with claim sources', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    _seedTimeline(database);

    await _pumpApp(tester, database: database);

    await tester.tap(find.byKey(const Key('open-timeline-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('timeline-item-insight-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('timeline-item-detail-page')), findsOneWidget);
    expect(find.text('Insight Detail'), findsOneWidget);
    expect(find.text('summary insight'), findsOneWidget);
    expect(
      find.byKey(
        const Key('timeline-detail-insight-1-insight-claim-claim.alpha'),
      ),
      findsOneWidget,
    );
    expect(
      find.text('Project Alpha insight keeps one cited claim.'),
      findsWidgets,
    );
    expect(find.text('1 source-linked'), findsOneWidget);
    expect(find.text('Capture: capture-1'), findsWidgets);
    expect(find.textContaining('/Users/guangmo/private'), findsNothing);
  });

  testWidgets(
    'timeline browse filters by type and disables local text search',
    (tester) async {
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

      expect(
        find.byKey(const Key('timeline-search-requires-retriever')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('timeline-item-todo-1')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('timeline-search-field')),
        '',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('timeline-filter-todo')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('timeline-item-todo-1')), findsOneWidget);
      expect(find.byKey(const Key('timeline-item-card-1')), findsNothing);

      await tester.tap(find.byKey(const Key('timeline-filter-insight')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('timeline-item-insight-1')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('timeline-search-field')),
        'No matching local item',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('timeline-search-requires-retriever')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('timeline-search-field')),
        '',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('timeline-filter-memory')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('timeline-item-memory-1')), findsOneWidget);
    },
  );

  testWidgets('timeline chrome and search filters render in Chinese', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    _seedTimeline(database);

    await _pumpApp(tester, database: database, locale: const Locale('zh'));

    await tester.tap(find.byKey(const Key('open-timeline-button')));
    await tester.pumpAndSettle();

    expect(find.text('时间线'), findsOneWidget);
    expect(find.text('浏览记录、卡片、记忆、洞察和待办。'), findsOneWidget);
    expect(find.text('1 个来源引用'), findsWidgets);
    expect(find.text('1 可溯源'), findsOneWidget);

    await tester.tap(find.byKey(const Key('timeline-search-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('timeline-search-page')), findsOneWidget);
    expect(find.text('搜索'), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('卡片'), findsOneWidget);
    expect(find.text('洞察'), findsOneWidget);

    final field = tester.widget<TextField>(
      find.byKey(const Key('timeline-search-field')),
    );
    expect(field.keyboardType, TextInputType.text);
    expect(field.textInputAction, TextInputAction.search);

    await tester.tap(find.byKey(const Key('timeline-filter-todo')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('timeline-item-todo-1')), findsOneWidget);
    expect(find.textContaining('待办 · 智能体建议'), findsOneWidget);
    expect(find.byKey(const Key('timeline-item-card-1')), findsNothing);
  });

  testWidgets(
    'timeline renders attachment artifact states and redacts raw paths',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = WideNoteLocalDatabase.inMemory();
      _seedArtifactTimeline(database);

      await _pumpApp(tester, database: database);

      await tester.tap(find.byKey(const Key('open-timeline-button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('timeline-item-capture-artifacts')),
        findsOneWidget,
      );
      expect(find.textContaining('status: ready'), findsOneWidget);
      expect(find.textContaining('status: pending'), findsOneWidget);
      expect(find.textContaining('status: Failed'), findsOneWidget);
      expect(find.textContaining('status: Blocked'), findsOneWidget);
      expect(find.textContaining('status: needs review'), findsOneWidget);
      expect(find.textContaining('/Users/guangmo/private'), findsNothing);
      expect(find.textContaining('DANGEROUS RAW PREVIEW'), findsNothing);

      await tester.tap(
        find.byKey(const Key('timeline-item-capture-artifacts')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('timeline-item-detail-page')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key(
            'timeline-detail-capture-artifacts-artifact-artifact-ready',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('attachment: artifact-photo-ready'),
        findsWidgets,
      );
      expect(find.textContaining('Whiteboard summary excerpt.'), findsWidgets);
      expect(find.textContaining('OCR pending for whiteboard.'), findsWidgets);
      expect(
        find.textContaining('OCR failed after platform error.'),
        findsWidgets,
      );
      expect(find.textContaining('/Users/guangmo/private'), findsNothing);
      expect(find.textContaining('DANGEROUS RAW PREVIEW'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpTimelinePage(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: TimelinePage()),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpApp(
  WidgetTester tester, {
  WideNoteLocalDatabase? database,
  Locale locale = const Locale('en'),
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
      child: WideNoteApp(locale: locale),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectButtonSemantics(
  WidgetTester tester,
  Key key,
  String labelFragment,
) {
  final data = tester.getSemantics(_semanticsForKey(key)).getSemanticsData();
  expect(data.flagsCollection.isButton, isTrue);
  expect(data.hasAction(SemanticsAction.tap), isTrue);
  expect(data.label, contains(labelFragment));
}

Finder _semanticsForKey(Key key) {
  final keyed = find.byKey(key);
  final descendant = find.descendant(
    of: keyed,
    matching: find.byType(Semantics),
  );
  if (descendant.evaluate().isNotEmpty) {
    return descendant.first;
  }
  return find.ancestor(of: keyed, matching: find.byType(Semantics)).first;
}

void _seedTimeline(WideNoteLocalDatabase database) {
  final captureAt = DateTime.utc(2026, 6, 24, 1);
  final memoryAt = DateTime.utc(2026, 6, 24, 2);
  final cardAt = DateTime.utc(2026, 6, 24, 3);
  final todoAt = DateTime.utc(2026, 6, 24, 4);

  database.eventLog.append(
    EventLogEntry(
      id: 'evt-capture-1',
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
      metricLabel: 'source-linked',
      metricValue: 1,
      payload: const <String, Object?>{
        'claims': <Object?>[
          <String, Object?>{
            'id': 'claim.alpha',
            'text': 'Project Alpha insight keeps one cited claim.',
            'source_refs': <Object?>[
              <String, Object?>{
                'kind': 'capture',
                'id': 'capture-1',
                'excerpt': 'Project Alpha kickoff notes.',
              },
            ],
          },
        ],
        'metrics': <Object?>[
          <String, Object?>{
            'label': 'source-linked',
            'value': 1,
            'source_refs': <Object?>[
              <String, Object?>{'kind': 'capture', 'id': 'capture-1'},
            ],
          },
        ],
        'source_refs': <Object?>[
          <String, Object?>{'kind': 'capture', 'id': 'capture-1'},
        ],
        'ui_blocks': <Object?>[
          <String, Object?>{'kind': 'claim_list'},
          <String, Object?>{'kind': 'metric_row'},
          <String, Object?>{'kind': 'source_refs'},
          <String, Object?>{'kind': 'note'},
        ],
      },
      createdAt: cardAt,
      updatedAt: cardAt,
    ),
  );
  database.eventLog.append(
    EventLogEntry(
      id: 'evt-todo-1',
      type: runtime.WnEventTypes.todoSuggested,
      actor: 'agent',
      causationId: 'evt-capture-1',
      subjectRef: const <String, Object?>{'kind': 'capture', 'id': 'capture-1'},
      payload: const <String, Object?>{
        'text': 'Follow up Project Alpha with Chen.',
        'source_event_id': 'evt-capture-1',
      },
      createdAt: todoAt,
    ),
  );
  database.todos.insert(
    TodoRecord(
      id: 'todo-1',
      sourceCaptureId: 'capture-1',
      sourceEventId: 'evt-todo-1',
      status: 'suggested',
      payload: const <String, Object?>{
        'title': 'Follow up Project Alpha with Chen.',
      },
      createdAt: todoAt,
      updatedAt: todoAt,
    ),
  );
}

void _seedArtifactTimeline(WideNoteLocalDatabase database) {
  final createdAt = DateTime.utc(2026, 6, 29, 3);
  database.eventLog.append(
    EventLogEntry(
      id: 'evt-capture-artifacts',
      type: runtime.WnEventTypes.captureCreated,
      actor: 'user',
      subjectRef: const <String, Object?>{
        'kind': 'capture',
        'id': 'capture-artifacts',
      },
      payload: const <String, Object?>{
        'text': 'Photo and voice attachments are saved as source material.',
      },
      createdAt: createdAt,
    ),
  );
  database.captures.insert(
    CaptureRecord(
      id: 'capture-artifacts',
      sourceType: 'manual',
      sourceId: 'evt-capture-artifacts',
      status: 'processed',
      payload: const <String, Object?>{
        'text': 'Photo and voice attachments are saved as source material.',
      },
      createdAt: createdAt,
      updatedAt: createdAt,
    ),
  );
  _insertAttachment(
    database,
    id: 'artifact-photo-ready',
    captureId: 'capture-artifacts',
    status: 'ready',
    previewText: 'Whiteboard image saved locally.',
    createdAt: createdAt,
  );
  _insertAttachment(
    database,
    id: 'artifact-photo-failed',
    captureId: 'capture-artifacts',
    status: 'ready',
    previewText: 'Second whiteboard image saved locally.',
    createdAt: createdAt.add(const Duration(minutes: 1)),
  );
  _insertAttachment(
    database,
    id: 'artifact-photo-blocked',
    captureId: 'capture-artifacts',
    status: 'blocked',
    previewText: 'preview_hidden',
    reviewReason: 'blocked_by_asset_safety',
    rawPreviewText: 'DANGEROUS RAW PREVIEW SHOULD NOT RENDER',
    createdAt: createdAt.add(const Duration(minutes: 2)),
  );
  _insertAttachment(
    database,
    id: 'artifact-voice-review',
    captureId: 'capture-artifacts',
    assetKind: 'voice',
    mimeType: 'audio/m4a',
    status: 'needs_review',
    previewText: 'Voice transcript waiting for user confirmation.',
    reviewReason: 'voice_transcript_requires_review',
    createdAt: createdAt.add(const Duration(minutes: 3)),
  );
  _insertArtifact(
    database,
    id: 'artifact-ready',
    captureId: 'capture-artifacts',
    attachmentId: 'artifact-photo-ready',
    artifactKind: 'vision_summary',
    status: 'active',
    body: 'Whiteboard summary excerpt.',
    createdAt: createdAt,
  );
  _insertArtifact(
    database,
    id: 'artifact-pending',
    captureId: 'capture-artifacts',
    attachmentId: 'artifact-photo-ready',
    artifactKind: 'ocr_text',
    status: 'pending',
    body: 'OCR pending for whiteboard.',
    createdAt: createdAt,
  );
  _insertArtifact(
    database,
    id: 'artifact-failed',
    captureId: 'capture-artifacts',
    attachmentId: 'artifact-photo-failed',
    artifactKind: 'ocr_text',
    status: 'failed',
    body: 'OCR failed after platform error.',
    createdAt: createdAt.add(const Duration(minutes: 1)),
  );
}

void _insertAttachment(
  WideNoteLocalDatabase database, {
  required String id,
  required String captureId,
  required String status,
  required String previewText,
  required DateTime createdAt,
  String assetKind = 'photo',
  String mimeType = 'image/jpeg',
  String? reviewReason,
  String? rawPreviewText,
}) {
  database.attachments.insert(
    AttachmentRecord(
      id: id,
      captureId: captureId,
      sourceEventId: 'evt-$captureId',
      assetKind: assetKind,
      mimeType: mimeType,
      storagePath: '/Users/guangmo/private/raw/$id',
      originalFileName: '$id.raw',
      sha256: '$id-sha256',
      status: status,
      payload: <String, Object?>{
        'preview_text': previewText,
        'review_reason': ?reviewReason,
        'raw_metadata': <String, Object?>{
          'local_path': '/Users/guangmo/private/raw/$id',
          'raw_preview_text': ?rawPreviewText,
        },
      },
      createdAt: createdAt,
      updatedAt: createdAt,
    ),
  );
}

void _insertArtifact(
  WideNoteLocalDatabase database, {
  required String id,
  required String captureId,
  required String attachmentId,
  required String artifactKind,
  required String status,
  required String body,
  required DateTime createdAt,
}) {
  database.derivedArtifacts.insert(
    DerivedArtifactRecord(
      id: id,
      sourceCaptureId: captureId,
      sourceAttachmentId: attachmentId,
      sourceEventId: 'evt-$captureId',
      artifactKind: artifactKind,
      status: status,
      title: artifactKind,
      body: body,
      mimeType: 'text/plain',
      storagePath: '/Users/guangmo/private/artifacts/$id.txt',
      sourceRefs: <Object?>[
        <String, Object?>{'kind': 'capture', 'id': captureId},
        <String, Object?>{'kind': 'file', 'id': attachmentId},
      ],
      generatorId: 'test.$artifactKind',
      generatorVersion: '1.0.0',
      createdAt: createdAt,
      updatedAt: createdAt,
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
