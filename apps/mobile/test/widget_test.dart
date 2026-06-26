import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/app/widenote_app.dart';
import 'package:widenote_mobile/features/capture/application/capture_controller.dart';
import 'package:widenote_mobile/features/capture/application/capture_input_controller.dart';
import 'package:widenote_mobile/features/capture/application/capture_orchestrator.dart';
import 'package:widenote_mobile/features/capture/domain/capture_models.dart';
import 'package:widenote_mobile/features/capture/media/capture_media.dart';

void main() {
  testWidgets('switches between the four WideNote tabs', (tester) async {
    await _pumpApp(tester);

    expect(find.byKey(const Key('home-page')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-chat')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-page')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-todos')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('todos-page')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-plugins')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plugins-page')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-page')), findsOneWidget);
  });

  testWidgets('captured state remains visible after visiting all four tabs', (
    tester,
  ) async {
    await _pumpApp(tester);

    const captureText = 'Keep this capture visible across tab changes.';
    await _submitQuickCapture(tester, captureText);

    final state = _readCaptureState(tester);
    final record = state.records.single;
    expect(record.body, captureText);

    await _openTab(tester, const Key('tab-chat'));
    await _openTab(tester, const Key('tab-todos'));
    await _openTab(tester, const Key('tab-plugins'));
    await _openTab(tester, const Key('tab-home'));

    await _scrollHomeTextIntoView(tester, '1 processed');
    expect(find.text('1 processed'), findsOneWidget);
    expect(find.text('1 accepted'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(Key('record-row-${record.id}')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(Key('record-row-${record.id}')), findsOneWidget);
    expect(find.text(captureText), findsOneWidget);
    expect(_readCaptureState(tester).cards, hasLength(2));
    expect(_readCaptureState(tester).insights, hasLength(3));
  });

  testWidgets('home and todos hydrate from local DB after relaunch', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    await _pumpApp(tester, database: database, closeDatabase: false);

    const captureText = 'Hydrate this capture after relaunch.';
    await _submitQuickCapture(tester, captureText);
    final stateBeforeRelaunch = _readCaptureState(tester);
    final todo = stateBeforeRelaunch.todos.single;

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await _pumpApp(tester, database: database, closeDatabase: false);

    await _scrollHomeTextIntoView(tester, '1 processed');
    expect(find.text('1 processed'), findsOneWidget);
    expect(find.text('1 accepted'), findsOneWidget);
    expect(find.text('1 linked'), findsOneWidget);
    final hydrated = _readCaptureState(tester);
    expect(hydrated.records.single.body, captureText);
    expect(hydrated.todos.single.id, todo.id);
    expect(hydrated.cards, hasLength(2));
    expect(hydrated.insights, hasLength(3));

    await tester.scrollUntilVisible(
      find.text(captureText),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(captureText), findsOneWidget);
    await _openTab(tester, const Key('tab-todos'));
    expect(find.byKey(Key('todo-row-${todo.id}')), findsOneWidget);
    expect(find.text('Follow up: $captureText'), findsOneWidget);
  });

  testWidgets('backup export counts persisted captures and todos', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    await _pumpApp(tester, database: database, closeDatabase: false);

    await _submitQuickCapture(tester, 'Count this capture in backup.');

    final backup = LocalBackupService(database).exportBackup();

    expect(backup.manifest.recordCounts['captures'], 1);
    expect(backup.manifest.recordCounts['todos'], 1);
    expect(
      backup.captures.single.payload['text'],
      'Count this capture in backup.',
    );
    expect(backup.todos.single.payload['title'], startsWith('Follow up:'));
  });

  testWidgets('quick capture creates record, auto-accepted Memory, and trace', (
    tester,
  ) async {
    await _pumpApp(tester);

    const captureText = 'Met Lin about WideNote source-linked todos.';

    await _submitQuickCapture(tester, captureText);

    await tester.scrollUntilVisible(
      find.text(captureText),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(captureText), findsOneWidget);
    final state = _readCaptureState(tester);
    expect(state.cards, hasLength(2));
    expect(state.insights, hasLength(3));

    await tester.scrollUntilVisible(
      find.byKey(Key('card-row-${state.cards.first.id}')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('source:'), findsWidgets);

    await tester.scrollUntilVisible(
      find.byKey(Key('insight-row-${state.insights.first.id}')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('summary insight'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Memory saved automatically'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Memory saved automatically'), findsOneWidget);
    expect(find.textContaining('auto-accepted'), findsWidgets);

    await tester.scrollUntilVisible(
      find.textContaining('runtime.run.completed').first,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('runtime.run.completed'), findsWidgets);
    expect(
      find.textContaining('pack.default · agent.capture_loop'),
      findsWidgets,
    );
    expect(find.textContaining('pack.todo · agent.todo_loop'), findsWidgets);

    final completedRuns = _readCaptureState(
      tester,
    ).traces.where((trace) => trace.label == 'runtime.run.completed');
    expect(
      completedRuns.map((trace) => '${trace.packId}/${trace.agentId}'),
      containsAll(<String>[
        'pack.default/agent.capture_loop',
        'pack.todo/agent.todo_loop',
      ]),
    );
  });

  testWidgets('blank quick capture does not create a local record', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(_readCaptureState(tester).records, isEmpty);
    expect(_readCaptureState(tester).todos, isEmpty);
    await _scrollHomeTextIntoView(tester, 'idle');
    expect(find.text('idle'), findsOneWidget);
    expect(find.text('ready'), findsOneWidget);
    expect(find.text('0 linked'), findsOneWidget);
    expect(find.textContaining('Processed locally'), findsNothing);

    await _submitQuickCapture(tester, '   ');

    expect(_readCaptureState(tester).records, isEmpty);
    expect(_readCaptureState(tester).todos, isEmpty);
    await _scrollHomeTextIntoView(tester, 'idle');
    expect(find.text('idle'), findsOneWidget);
    expect(find.text('ready'), findsOneWidget);
    expect(find.text('0 linked'), findsOneWidget);
    expect(find.textContaining('Processed locally'), findsNothing);
    expect(_readCaptureState(tester).cards, isEmpty);
    expect(_readCaptureState(tester).insights, isEmpty);
  });

  testWidgets('home record rows open timeline item details', (tester) async {
    await _pumpApp(tester);

    const captureText = 'Open this source-linked record from home.';
    await _submitQuickCapture(tester, captureText);

    final record = _readCaptureState(tester).records.single;
    final row = find.byKey(Key('record-row-${record.id}'));
    await tester.scrollUntilVisible(
      row,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(row), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: row, matching: find.text(captureText)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('timeline-item-detail-page')), findsOneWidget);
    expect(find.text('Capture Detail'), findsOneWidget);
    expect(find.text(captureText), findsWidgets);
  });

  testWidgets('attachment-only capture falls back to attachment name', (
    tester,
  ) async {
    await _pumpApp(tester);

    final attachment = CaptureAttachment(
      id: 'empty-preview-photo',
      kind: CaptureAssetKind.photo,
      displayName: 'Empty preview.jpg',
      mimeType: 'image/jpeg',
      sourceUri: 'fake://camera/empty-preview.jpg',
      createdAt: DateTime.utc(2026, 6, 24, 12),
      state: CaptureAttachmentState.ready,
      rawMetadata: const <String, Object?>{'adapter': 'test'},
    );

    await ProviderScope.containerOf(tester.element(find.byType(WideNoteApp)))
        .read(captureControllerProvider.notifier)
        .submitCapture('', attachments: <CaptureAttachment>[attachment]);
    await tester.pumpAndSettle();

    final state = _readCaptureState(tester);
    expect(state.records.single.body, 'photo: Empty preview.jpg');
    expect(state.memories.single.summary, contains('photo: Empty preview.jpg'));
  });

  testWidgets('blocked photo attachment hides raw preview and blocks submit', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      overrides: [
        photoCaptureAdapterProvider.overrideWithValue(
          const FakePhotoCaptureAdapter(mode: FakePhotoMode.dangerous),
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('add-camera-attachment-button')));
    await tester.pumpAndSettle();

    expect(find.text('Blocked photo sample.jpg'), findsOneWidget);
    expect(find.textContaining('Blocked attachment'), findsOneWidget);
    expect(find.textContaining('Preview hidden'), findsOneWidget);
    expect(find.textContaining('DANGEROUS RAW PREVIEW'), findsNothing);

    await tester.tap(find.byKey(const Key('record-capture-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Remove blocked attachments before saving.'),
      findsOneWidget,
    );
    expect(_readCaptureState(tester).records, isEmpty);
  });

  testWidgets('home shows card and insight empty states', (tester) async {
    await _pumpApp(tester);

    await tester.scrollUntilVisible(
      find.text('No source-linked cards yet.'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('No source-linked cards yet.'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('No source-linked insights yet.'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('No source-linked insights yet.'), findsOneWidget);
  });

  testWidgets('raw capture stays visible when agent processing fails', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      overrides: [
        captureOrchestratorProvider.overrideWithValue(
          CaptureOrchestrator.local(eventStore: _FailingEventStore()),
        ),
      ],
    );

    const captureText = 'Preserve this raw note even when the agent fails.';
    await _submitQuickCapture(tester, captureText);

    expect(_readCaptureInputState(tester).isBusy, isFalse);
    await tester.scrollUntilVisible(
      find.text(captureText),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(captureText), findsOneWidget);
    expect(find.textContaining('Saved locally, agent failed'), findsOneWidget);

    final state = _readCaptureState(tester);
    expect(state.records.single.body, captureText);
    expect(state.records.single.status, 'Saved locally, agent failed');
    expect(state.memories, isEmpty);
    expect(state.reviewCandidates, isEmpty);
    expect(state.traces, isEmpty);
    expect(state.cards, isEmpty);
    expect(state.insights, isEmpty);
    expect(state.todos, isEmpty);
  });

  testWidgets('quick capture input is locked while processing', (tester) async {
    await _pumpApp(
      tester,
      overrides: [
        captureOrchestratorProvider.overrideWithValue(
          CaptureOrchestrator.local(model: const _HangingModel()),
        ),
      ],
    );

    await tester.enterText(
      find.byKey(const Key('quick-capture-field')),
      'Keep one capture in flight.',
    );
    await tester.tap(find.byKey(const Key('record-capture-button')));
    await tester.pump();

    final input = tester.widget<TextField>(
      find.byKey(const Key('quick-capture-field')),
    );
    expect(input.enabled, isFalse);
    expect(find.text('Processing'), findsWidgets);
  });

  testWidgets('multiple captures update counters and linked todos', (
    tester,
  ) async {
    await _pumpApp(tester);

    await _submitQuickCapture(tester, 'First follow-up for Ada.');
    var state = _readCaptureState(tester);
    expect(state.records, hasLength(1));
    expect(state.memories, hasLength(1));
    expect(state.cards, hasLength(2));
    expect(state.insights, hasLength(3));
    expect(state.todos, hasLength(1));
    await _scrollHomeTextIntoView(tester, '1 processed');
    expect(find.text('1 processed'), findsOneWidget);
    expect(find.text('1 accepted'), findsOneWidget);
    expect(find.text('2 cards'), findsOneWidget);
    expect(find.text('3 source-linked'), findsOneWidget);
    expect(find.text('1 linked'), findsOneWidget);

    await ProviderScope.containerOf(tester.element(find.byType(WideNoteApp)))
        .read(captureControllerProvider.notifier)
        .submitCapture('Second follow-up for Chen.');
    await tester.pumpAndSettle();
    state = _readCaptureState(tester);
    expect(state.records, hasLength(2));
    expect(state.memories, hasLength(2));
    expect(state.cards, hasLength(4));
    expect(state.insights, hasLength(3));
    expect(state.todos, hasLength(2));
    await _scrollHomeTextIntoView(tester, '2 processed');
    expect(find.text('2 processed'), findsOneWidget);
    expect(find.text('2 accepted'), findsOneWidget);
    expect(find.text('4 cards'), findsOneWidget);
    expect(find.text('3 source-linked'), findsOneWidget);
    expect(find.text('2 linked'), findsOneWidget);
  });

  testWidgets('sensitive capture can be accepted from Memory review', (
    tester,
  ) async {
    await _pumpApp(tester);

    const captureText = 'My API token should be reviewed before storage.';
    await _submitQuickCapture(tester, captureText);

    final stateBeforeReview = _readCaptureState(tester);
    final record = stateBeforeReview.records.single;
    final candidate = stateBeforeReview.reviewCandidates.single;
    expect(candidate.sourceLabel, 'capture: ${record.id}');
    expect(stateBeforeReview.cards, hasLength(1));

    await tester.scrollUntilVisible(
      find.text('Memory Review'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('review_only_type'), findsOneWidget);

    await _scrollHomeActionIntoView(
      tester,
      find.widgetWithText(FilledButton, 'Accept'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Accept'));
    await tester.pumpAndSettle();

    expect(find.text('Memory Review'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Memory saved'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Memory saved'), findsOneWidget);
    expect(find.textContaining('accepted'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('1 accepted'),
      -120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1 accepted'), findsOneWidget);
    expect(find.text('1 auto-accepted'), findsNothing);

    final stateAfterReview = _readCaptureState(tester);
    expect(stateAfterReview.records.single.body, captureText);
    expect(
      stateAfterReview.memories.single.sourceRecordId,
      'capture: ${record.id}',
    );
    expect(stateAfterReview.cards, hasLength(2));
    expect(stateAfterReview.insights, hasLength(3));
  });

  testWidgets('review candidate can be edited before acceptance', (
    tester,
  ) async {
    await _pumpApp(tester);

    await _submitQuickCapture(
      tester,
      'Doctor said medication timing should be checked.',
    );
    await tester.scrollUntilVisible(
      find.text('Memory Review'),
      120,
      scrollable: find.byType(Scrollable).first,
    );

    await _scrollHomeActionIntoView(
      tester,
      find.widgetWithText(OutlinedButton, 'Edit'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('memory-review-edit-field')),
      'Medication timing needs a user-confirmed follow-up.',
    );
    await tester.tap(find.byKey(const Key('memory-review-edit-save')));
    await tester.pumpAndSettle();

    expect(find.text('Memory Review'), findsNothing);
    final state = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('home-page'))),
    ).read(captureControllerProvider);
    expect(state.reviewCandidates, isEmpty);
    expect(
      state.memories.single.summary,
      'Medication timing needs a user-confirmed follow-up.',
    );
    expect(state.cards, hasLength(2));
    expect(state.insights, hasLength(3));
  });

  testWidgets('review candidate can be rejected without creating Memory', (
    tester,
  ) async {
    await _pumpApp(tester);

    await _submitQuickCapture(
      tester,
      'Salary and bank details should stay out of automatic Memory.',
    );
    await tester.scrollUntilVisible(
      find.text('Memory Review'),
      120,
      scrollable: find.byType(Scrollable).first,
    );

    await _scrollHomeActionIntoView(
      tester,
      find.widgetWithText(TextButton, 'Reject'),
    );
    await tester.tap(find.widgetWithText(TextButton, 'Reject'));
    await tester.pumpAndSettle();

    expect(find.text('Memory Review'), findsNothing);
    expect(find.text('Memory saved'), findsNothing);
    expect(_readCaptureState(tester).todos, isEmpty);

    await _openTab(tester, const Key('tab-todos'));
    expect(find.byKey(const Key('todos-page')), findsOneWidget);
    expect(find.textContaining('Salary and bank details'), findsNothing);
  });

  testWidgets('generated todo appears on Todos tab with source link', (
    tester,
  ) async {
    await _pumpApp(tester);

    const captureText = 'Call Mina about launch review and sample todos.';
    await _submitQuickCapture(tester, captureText);

    final state = _readCaptureState(tester);
    final record = state.records.single;
    final todo = state.todos.first;
    expect(todo.sourceLabel, 'source: ${record.id}');

    await _openTab(tester, const Key('tab-todos'));

    expect(find.byKey(const Key('todos-page')), findsOneWidget);
    expect(find.byKey(Key('todo-row-${todo.id}')), findsOneWidget);
    expect(find.text('Follow up: $captureText'), findsOneWidget);
    expect(find.text('suggested by agent'), findsOneWidget);
    expect(find.text('source: ${record.id}'), findsOneWidget);
    expect(
      _visibleTextValues(tester).where(
        (text) => text.startsWith('source: ') && !text.contains('sample'),
      ),
      isNotEmpty,
    );
  });

  testWidgets(
    'default quick capture persists runtime event and trace through local DB',
    (tester) async {
      final database = WideNoteLocalDatabase.inMemory();
      final eventStore = LocalDbEventStore(database);
      final traceSink = LocalDbTraceSink(database);

      await _pumpApp(tester, database: database);

      await _submitQuickCapture(tester, 'Persist mobile capture to SQLite.');

      final events = await eventStore.readAll();
      final traces = await traceSink.readAll();

      final eventTypes = events.map((event) => event.type).toList();
      expect(eventTypes.take(2), [
        runtime.WnEventTypes.captureCreated,
        runtime.WnEventTypes.memoryProposed,
      ]);
      expect(
        eventTypes,
        containsAll(<String>[
          runtime.WnEventTypes.cardCreated,
          runtime.WnEventTypes.insightCreated,
          runtime.WnEventTypes.todoSuggested,
        ]),
      );
      expect(
        events
            .where((event) => event.type == runtime.WnEventTypes.todoSuggested)
            .single
            .packId,
        'pack.todo',
      );
      expect(
        events
            .where((event) => event.type == runtime.WnEventTypes.cardCreated)
            .single
            .payload['source_refs'],
        isA<List>(),
      );
      expect(
        events
            .where((event) => event.type == runtime.WnEventTypes.insightCreated)
            .single
            .payload['source_refs'],
        isA<List>(),
      );
      expect(
        traces
            .where((trace) => trace.name == 'runtime.run.completed')
            .map((trace) => trace.packId),
        containsAll(<String>['pack.default', 'pack.todo']),
      );
      expect(
        database.traceEvents
            .readAll()
            .where((trace) => trace.name == 'runtime.run.completed')
            .map((trace) => trace.traceType),
        everyElement('run_completed'),
      );
      expect(database.memoryItems.readAll(status: 'active'), hasLength(1));
      expect(database.cards.readAll(status: 'active'), hasLength(2));
      expect(database.insights.readAll(status: 'active'), hasLength(3));
      expect(
        (database.cards.readAll(status: 'active').first.sourceRefs.first
            as Map)['kind'],
        isNotNull,
      );
    },
  );

  testWidgets('Plugins page shows core control entries', (tester) async {
    await _pumpApp(tester);
    await _openTab(tester, const Key('tab-plugins'));

    expect(find.byKey(const Key('plugins-page')), findsOneWidget);
    expect(find.text('Pack Library'), findsOneWidget);
    expect(find.text('Permission Gate'), findsOneWidget);
    expect(find.text('Model Provider'), findsOneWidget);
    expect(find.text('Backup'), findsOneWidget);
    expect(find.text('Trace Console'), findsOneWidget);
  });

  testWidgets('Chat page shows local conversation shell and composer', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _openTab(tester, const Key('tab-chat'));

    expect(find.byKey(const Key('chat-page')), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('No local sessions yet.'), findsOneWidget);
    expect(find.text('Local chat'), findsOneWidget);
    expect(
      find.text('Ask a question about records, Memory, or todos.'),
      findsOneWidget,
    );
    expect(find.text('Ask'), findsOneWidget);

    final input = tester.widget<TextField>(find.byType(TextField));
    expect(input.enabled, isTrue);
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  WideNoteLocalDatabase? database,
  Locale locale = const Locale('en'),
  List<Override> overrides = const [],
  bool closeDatabase = true,
}) async {
  final localDatabase = database ?? WideNoteLocalDatabase.inMemory();
  if (closeDatabase) {
    addTearDown(localDatabase.close);
  }
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
  if (find.byKey(const Key('home-page')).evaluate().isEmpty) {
    await _openTab(tester, const Key('tab-home'));
  }
}

Future<void> _submitQuickCapture(WidgetTester tester, String text) async {
  final input = find.byKey(const Key('quick-capture-field'));
  if (input.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      input,
      -120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(input);
  await tester.pumpAndSettle();
  await tester.enterText(input, text);
  final recordButton = find.byKey(const Key('record-capture-button'));
  if (recordButton.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      recordButton,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(recordButton);
  await tester.pumpAndSettle();
  await tester.tap(recordButton);
  await tester.pumpAndSettle();
}

Future<void> _openTab(WidgetTester tester, Key tabKey) async {
  await tester.tap(find.byKey(tabKey));
  await tester.pumpAndSettle();
}

Future<void> _scrollHomeActionIntoView(
  WidgetTester tester,
  Finder finder,
) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _scrollHomeTextIntoView(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

CaptureState _readCaptureState(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byType(WideNoteApp)),
  ).read(captureControllerProvider);
}

CaptureInputState _readCaptureInputState(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byType(WideNoteApp)),
  ).read(captureInputControllerProvider);
}

Iterable<String> _visibleTextValues(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data)
      .whereType<String>();
}

final class _FailingEventStore implements runtime.EventStore {
  @override
  Future<void> append(runtime.WnEvent event) {
    throw StateError('event store unavailable');
  }

  @override
  Future<void> appendAll(Iterable<runtime.WnEvent> events) {
    throw StateError('event store unavailable');
  }

  @override
  Future<List<runtime.WnEvent>> readAll() async => const <runtime.WnEvent>[];

  @override
  Future<runtime.WnEvent?> readById(String id) async => null;

  @override
  Future<List<runtime.WnEvent>> readByType(String type) async =>
      const <runtime.WnEvent>[];
}

final class _HangingModel implements runtime.ModelClient {
  const _HangingModel();

  @override
  Future<runtime.ModelResponse> complete(runtime.ModelRequest request) {
    return Completer<runtime.ModelResponse>().future;
  }
}
