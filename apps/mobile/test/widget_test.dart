import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_mobile/features/capture/application/capture_agent_prompts.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_local_db/widenote_local_db.dart' as localdb;
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/app/model_client.dart';
import 'package:widenote_mobile/app/widenote_app.dart';
import 'package:widenote_mobile/features/capture/application/capture_controller.dart';
import 'package:widenote_mobile/features/capture/application/capture_input_controller.dart';
import 'package:widenote_mobile/features/capture/application/capture_orchestrator.dart';
import 'package:widenote_mobile/features/capture/application/capture_orchestrator_provider.dart';
import 'package:widenote_mobile/features/capture/domain/capture_models.dart';
import 'package:widenote_mobile/features/capture/media/capture_media.dart';
import 'package:widenote_mobile/features/location/application/location_settings_controller.dart';
import 'package:widenote_mobile/features/recap/application/daily_recap_repository.dart';

void main() {
  testWidgets(
    'switches between WideNote tabs and opens capture from center action',
    (tester) async {
      await _pumpApp(tester);

      expect(find.byKey(const Key('home-page')), findsOneWidget);

      await tester.tap(find.byKey(const Key('tab-chat')));
      await _pumpRouteChange(tester);
      expect(find.byKey(const Key('chat-page')), findsOneWidget);

      await tester.tap(find.byKey(const Key('tab-record-action')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-page')), findsOneWidget);
      expect(find.byKey(const Key('capture-sheet')), findsOneWidget);
      await tester.tap(find.byKey(const Key('capture-sheet-close-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('capture-sheet')), findsNothing);

      await tester.tap(find.byKey(const Key('tab-todos')));
      await _pumpRouteChange(tester);
      expect(find.byKey(const Key('todos-page')), findsOneWidget);

      await tester.tap(find.byKey(const Key('tab-plugins')));
      await _pumpRouteChange(tester);
      expect(find.byKey(const Key('plugins-page')), findsOneWidget);

      await tester.tap(find.byKey(const Key('tab-home')));
      await _pumpRouteChange(tester);
      expect(find.byKey(const Key('home-page')), findsOneWidget);
    },
  );

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

    await _scrollHomeTextIntoView(tester, 'captures: 1');
    expect(find.text('captures: 1'), findsOneWidget);
    expect(find.text('Memory: 1'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(Key('record-row-${record.id}')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    final recordRow = find.byKey(Key('record-row-${record.id}'));
    expect(recordRow, findsOneWidget);
    expect(
      find.descendant(of: recordRow, matching: find.text(captureText)),
      findsOneWidget,
    );
    expect(_readCaptureState(tester).cards, hasLength(2));
    expect(
      _readCaptureState(tester).insights,
      hasLength(greaterThanOrEqualTo(4)),
    );
  });

  testWidgets('home and todos hydrate from local DB after relaunch', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    await _pumpApp(tester, database: database, closeDatabase: false);

    const captureText = 'Review this capture after relaunch.';
    await _submitQuickCapture(tester, captureText);
    final stateBeforeRelaunch = _readCaptureState(tester);
    final todo = stateBeforeRelaunch.todos.single;

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await _pumpApp(tester, database: database, closeDatabase: false);

    await _scrollHomeTextIntoView(tester, 'captures: 1');
    expect(find.text('captures: 1'), findsOneWidget);
    expect(find.text('Memory: 1'), findsOneWidget);
    final hydrated = _readCaptureState(tester);
    expect(hydrated.records.single.body, captureText);
    expect(hydrated.todos.single.id, todo.id);
    expect(hydrated.todos.single.sourceRefs, isNotEmpty);
    expect(hydrated.cards, hasLength(2));
    expect(hydrated.insights, hasLength(greaterThanOrEqualTo(4)));

    await tester.scrollUntilVisible(
      find.text(captureText),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(captureText), findsOneWidget);
    await _openTab(tester, const Key('tab-todos'));
    expect(find.byKey(Key('todo-row-${todo.id}')), findsOneWidget);
    expect(find.text(captureText), findsOneWidget);
  });

  testWidgets('home pull-to-refresh rehydrates externally inserted captures', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    final createdAt = DateTime.utc(2026, 7, 2, 10, 30);
    await _pumpApp(
      tester,
      database: database,
      closeDatabase: false,
      overrides: [dailyRecapNowProvider.overrideWithValue(createdAt)],
    );

    expect(_readCaptureState(tester).records, isEmpty);
    expect(find.text('Externally inserted capture.'), findsNothing);
    expect(find.text('captures: 0'), findsOneWidget);

    database.captures.insert(
      localdb.CaptureRecord(
        id: 'home-refresh-capture',
        sourceType: 'manual',
        status: captureStatusProcessed,
        payload: const <String, Object?>{
          'text': 'Externally inserted capture.',
          'raw_text': 'Externally inserted capture.',
        },
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );

    await tester.drag(find.byKey(const Key('home-page')), const Offset(0, 320));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(_readCaptureState(tester).records.single.id, 'home-refresh-capture');
    expect(find.text('captures: 1'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('record-row-home-refresh-capture')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Externally inserted capture.'), findsOneWidget);
  });

  testWidgets('legacy todo rows hydrate without source_refs payload', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    final createdAt = DateTime.utc(2026, 7, 2, 7);
    database.todos.insert(
      localdb.TodoRecord(
        id: 'legacy-todo-row',
        sourceCaptureId: 'legacy-capture',
        sourceEventId: 'legacy-event',
        status: 'open',
        payload: const <String, Object?>{'title': 'Review legacy todo row'},
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );

    await _pumpApp(tester, database: database, closeDatabase: false);

    final todo = _readCaptureState(tester).todos.single;
    expect(todo.id, 'legacy-todo-row');
    expect(todo.sourceLabel, 'source: legacy-capture');
    expect(
      _sourceRefIds(todo.sourceRefs),
      containsAll(<String>['legacy-capture', 'legacy-event']),
    );
  });

  testWidgets('pending capture resumes processing after relaunch', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    final createdAt = DateTime.utc(2026, 7, 2, 8);
    database.captures.insert(
      localdb.CaptureRecord(
        id: 'capture-resume-processing',
        sourceType: 'manual',
        status: 'Saved locally, processing',
        payload: const <String, Object?>{
          'text': 'Resume this pending capture after relaunch.',
          'raw_text': 'Resume this pending capture after relaunch.',
        },
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    );

    await _pumpApp(tester, database: database, closeDatabase: false);

    final state = _readCaptureState(tester);
    expect(state.records.single.id, 'capture-resume-processing');
    expect(state.records.single.status, 'Processed locally');
    expect(state.memories, hasLength(1));
    expect(
      database.captures
          .readById('capture-resume-processing')!
          .payload['memory_generated'],
      isTrue,
    );
  });

  testWidgets('backup export counts persisted captures and todos', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    await _pumpApp(tester, database: database, closeDatabase: false);

    await _submitQuickCapture(tester, 'Review this capture in backup.');

    final backup = LocalBackupService(database).exportBackup();

    expect(backup.manifest.recordCounts['captures'], 1);
    expect(backup.manifest.recordCounts['todos'], 1);
    expect(
      backup.captures.single.payload['text'],
      'Review this capture in backup.',
    );
    expect(
      backup.todos.single.payload['title'],
      'Review this capture in backup.',
    );
  });

  testWidgets('quick capture creates record, auto-accepted Memory, and trace', (
    tester,
  ) async {
    await _pumpApp(tester);

    const captureText = 'Met Lin about WideNote source-linked todos.';

    await _submitQuickCapture(tester, captureText);

    final state = _readCaptureState(tester);
    final record = state.records.single;
    await tester.scrollUntilVisible(
      find.byKey(Key('record-row-${record.id}')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.descendant(
        of: find.byKey(Key('record-row-${record.id}')),
        matching: find.text(captureText),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(Key('record-row-${record.id}')),
        matching: find.textContaining(record.id),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(Key('record-row-${record.id}')),
        matching: find.textContaining('Processed'),
      ),
      findsOneWidget,
    );
    expect(state.cards, hasLength(2));
    expect(state.insights, hasLength(greaterThanOrEqualTo(4)));

    await _scrollHomeTextIntoView(tester, 'Memory: 1');
    expect(find.text('Memory: 1'), findsOneWidget);
    expect(find.text('Memory saved automatically'), findsNothing);
    expect(find.textContaining('auto-accepted'), findsNothing);
    expect(find.byKey(Key('card-row-${state.cards.first.id}')), findsNothing);
    expect(
      find.byKey(Key('insight-row-${state.insights.first.id}')),
      findsNothing,
    );
    expect(find.textContaining('runtime.run.completed'), findsNothing);

    final completedRuns = _readCaptureState(
      tester,
    ).traces.where((trace) => trace.label == 'runtime.run.completed');
    expect(
      completedRuns.map((trace) => '${trace.packId}/${trace.agentId}'),
      containsAll(<String>[
        'pack.default/agent.capture_loop',
        'pack.todo/agent.todo_loop',
        'pack.pkm_library/agent.pkm_profile_builder',
      ]),
    );
  });

  testWidgets('blank quick capture does not create a local record', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(_readCaptureState(tester).records, isEmpty);
    expect(_readCaptureState(tester).todos, isEmpty);
    await _scrollHomeTextIntoView(tester, 'captures: 0');
    expect(find.text('captures: 0'), findsOneWidget);
    expect(find.text('Memory: 0'), findsOneWidget);
    expect(find.textContaining('Processed locally'), findsNothing);

    await _submitQuickCapture(tester, '   ');

    expect(_readCaptureState(tester).records, isEmpty);
    expect(_readCaptureState(tester).todos, isEmpty);
    await _scrollHomeTextIntoView(tester, 'captures: 0');
    expect(find.text('captures: 0'), findsOneWidget);
    expect(find.text('Memory: 0'), findsOneWidget);
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

    await _openNewRecordSheet(tester);
    await tester.tap(find.byKey(const Key('add-camera-attachment-button')));
    await tester.pumpAndSettle();

    expect(find.text('Blocked photo sample.jpg'), findsOneWidget);
    expect(find.textContaining('Blocked attachment'), findsOneWidget);
    expect(find.textContaining('Preview hidden'), findsWidgets);
    expect(find.textContaining('DANGEROUS RAW PREVIEW'), findsNothing);

    await tester.tap(find.byKey(const Key('record-capture-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Remove blocked attachments before saving.'),
      findsOneWidget,
    );
    expect(_readCaptureState(tester).records, isEmpty);
  });

  testWidgets(
    'home keeps detailed cards, review, todos, and traces offscreen',
    (tester) async {
      await _pumpApp(tester);

      await tester.scrollUntilVisible(
        find.byKey(const Key('open-new-record-button')),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('open-new-record-button')), findsOneWidget);
      expect(
        find.byKey(const Key('start-background-recording-button')),
        findsOneWidget,
      );
      expect(find.text('No source-linked cards yet.'), findsNothing);
      expect(find.text('No source-linked insights yet.'), findsNothing);
      expect(find.text('Memory Review'), findsNothing);
      expect(find.text('Trace'), findsNothing);
      expect(find.text('Todo'), findsNothing);
    },
  );

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
    expect(find.textContaining('Failed'), findsOneWidget);

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

  testWidgets('missing model keeps raw capture and shows unavailable state', (
    tester,
  ) async {
    await _pumpApp(tester, modelClient: null);

    const captureText = 'Save the raw note even without a configured model.';
    await _submitQuickCapture(tester, captureText);

    await tester.scrollUntilVisible(
      find.text(captureText),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(captureText), findsOneWidget);
    expect(find.textContaining('Failed'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Configure a model provider or retry'),
      -120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.textContaining('Configure a model provider or retry'),
      findsOneWidget,
    );
    expect(find.textContaining('CapturePipelineException'), findsNothing);
    expect(find.textContaining('Memory proposal'), findsNothing);

    final state = _readCaptureState(tester);
    expect(state.records.single.body, captureText);
    expect(state.records.single.status, 'Saved locally, agent failed');
    expect(state.memories, isEmpty);
    expect(state.reviewCandidates, isEmpty);
    expect(state.cards, isEmpty);
    expect(state.insights, isEmpty);
    expect(state.todos, isEmpty);
  });

  testWidgets('quick capture stays available while processing', (tester) async {
    await _pumpApp(
      tester,
      overrides: [
        captureOrchestratorProvider.overrideWithValue(
          CaptureOrchestrator.local(model: const _HangingModel()),
        ),
      ],
    );

    await _openNewRecordSheet(tester);
    await tester.enterText(
      find.byKey(const Key('quick-capture-field')),
      'Keep one capture in flight.',
    );
    await tester.tap(find.byKey(const Key('record-capture-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    var state = _readCaptureState(tester);
    expect(state.isProcessing, isTrue);
    expect(state.records, hasLength(1));
    expect(state.records.single.status, 'Saved locally, processing');

    await tester.tap(find.byKey(const Key('tab-record-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final input = tester.widget<TextField>(
      find.byKey(const Key('quick-capture-field')),
    );
    expect(input.enabled, isTrue);

    await tester.enterText(
      find.byKey(const Key('quick-capture-field')),
      'Queue a second capture while the first is still running.',
    );
    unawaited(
      ProviderScope.containerOf(tester.element(find.byType(WideNoteApp)))
          .read(captureControllerProvider.notifier)
          .submitCapture(
            'Queue a second capture while the first is still running.',
          ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    state = _readCaptureState(tester);
    expect(state.isProcessing, isTrue);
    expect(state.records, hasLength(2));
    expect(
      state.records.map((record) => record.body),
      containsAll(<String>[
        'Keep one capture in flight.',
        'Queue a second capture while the first is still running.',
      ]),
    );
  });

  testWidgets('failed capture exposes per-record retry', (tester) async {
    final model = _SwitchingCaptureModel();
    await _pumpApp(tester, modelClient: model);

    const captureText = 'Retry this temporary model outage.';
    await _submitQuickCapture(tester, captureText);

    var state = _readCaptureState(tester);
    final failedRecord = state.records.single;
    expect(failedRecord.status, 'Saved locally, agent failed');
    final retryButton = find.byKey(Key('record-retry-${failedRecord.id}'));
    await tester.scrollUntilVisible(
      retryButton,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    model.failCaptureMemory = false;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(WideNoteApp)),
    );
    final controller = container.read(captureControllerProvider.notifier);
    await Future.wait(<Future<void>>[
      controller.retryCapture(failedRecord.id),
      controller.retryCapture(failedRecord.id),
    ]);
    await tester.pumpAndSettle();

    state = _readCaptureState(tester);
    expect(state.records.single.status, 'Processed locally');
    expect(state.memories, hasLength(1));
    expect(find.byKey(Key('record-retry-${failedRecord.id}')), findsNothing);
    expect(
      container
          .read(localDatabaseProvider)
          .captures
          .readById(failedRecord.id)!
          .payload['memory_generated'],
      isTrue,
    );
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
    expect(state.insights, hasLength(4));
    expect(state.todos, hasLength(1));
    await _scrollHomeTextIntoView(tester, 'captures: 1');
    expect(find.text('captures: 1'), findsOneWidget);
    expect(find.text('Memory: 1'), findsOneWidget);
    expect(find.text('insights: 4'), findsOneWidget);

    await ProviderScope.containerOf(tester.element(find.byType(WideNoteApp)))
        .read(captureControllerProvider.notifier)
        .submitCapture('Second follow-up for Chen.');
    ProviderScope.containerOf(
      tester.element(find.byType(WideNoteApp)),
    ).invalidate(dailyRecapProvider);
    await tester.pumpAndSettle();
    state = _readCaptureState(tester);
    expect(state.records, hasLength(2));
    expect(state.memories, hasLength(2));
    expect(state.cards, hasLength(4));
    expect(state.insights, hasLength(4));
    expect(state.todos, hasLength(2));
    await _scrollHomeTextIntoView(tester, 'captures: 2');
    expect(find.text('captures: 2'), findsOneWidget);
    expect(find.text('Memory: 2'), findsOneWidget);
    expect(find.text('insights: 4'), findsOneWidget);
  });

  testWidgets('sensitive Memory candidate stays out of the home surface', (
    tester,
  ) async {
    await _pumpApp(tester, modelClient: const _ReviewCaptureModel());

    const captureText = 'My API token should be reviewed before storage.';
    await _submitQuickCapture(tester, captureText);

    final stateBeforeReview = _readCaptureState(tester);
    final record = stateBeforeReview.records.single;
    final candidate = stateBeforeReview.reviewCandidates.single;
    expect(candidate.sourceLabel, 'capture: ${record.id}');
    expect(stateBeforeReview.cards, hasLength(1));
    expect(find.text('Memory Review'), findsNothing);
    expect(find.text('Memory saved'), findsNothing);
    expect(find.textContaining('review_only_type'), findsNothing);
    expect(stateBeforeReview.memories, isEmpty);
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
    expect(find.text(captureText), findsOneWidget);
    expect(find.text('Suggested action'), findsOneWidget);
    expect(find.text('source: ${record.id}'), findsNothing);
    expect(
      _visibleTextValues(tester).where(
        (text) => text.startsWith('source: ') && !text.contains('sample'),
      ),
      isEmpty,
    );
  });

  testWidgets(
    'default quick capture persists runtime event and trace through local DB',
    (tester) async {
      final database = WideNoteLocalDatabase.inMemory();
      final eventStore = LocalDbEventStore(database);
      final traceSink = LocalDbTraceSink(database);

      await _pumpApp(tester, database: database);

      await _submitQuickCapture(tester, 'Review mobile capture in SQLite.');

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
          runtime.WnEventTypes.artifactCreated,
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
            .where(
              (event) => event.type == runtime.WnEventTypes.artifactCreated,
            )
            .single
            .packId,
        'pack.pkm_library',
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
        containsAll(<String>['pack.default', 'pack.todo', 'pack.pkm_library']),
      );
      expect(
        database.traceEvents
            .readAll()
            .where((trace) => trace.name == 'runtime.run.completed')
            .map((trace) => trace.traceType),
        everyElement('run_completed'),
      );
      expect(database.memoryItems.readAll(status: 'active'), hasLength(1));
      final todoRecord = database.todos.readAll().single;
      final todoRefs = todoRecord.payload['source_refs']! as List<Object?>;
      expect(
        _sourceRefIds(todoRefs),
        containsAll(<String>[todoRecord.sourceCaptureId!, events.first.id]),
      );
      expect(database.cards.readAll(status: 'active'), hasLength(2));
      expect(
        database.insights.readAll(status: 'active'),
        hasLength(greaterThanOrEqualTo(4)),
      );
      final pkmArtifact = database.derivedArtifacts
          .readAll(artifactKind: 'pkm_profile_entry')
          .single;
      expect(pkmArtifact.sourceRefs, isNotEmpty);
      expect(
        pkmArtifact.generatorId,
        'pack.pkm_library/agent.pkm_profile_builder',
      );
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
    expect(find.text('Log Center'), findsOneWidget);
  });

  testWidgets('Chat page shows local conversation shell and composer', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _openTab(tester, const Key('tab-chat'));

    expect(find.byKey(const Key('chat-page')), findsOneWidget);
    expect(find.text('Conversations'), findsOneWidget);
    expect(find.text('No local sessions yet.'), findsOneWidget);
    expect(find.text('Local chat'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  WideNoteLocalDatabase? database,
  Locale locale = const Locale('en'),
  List<Override> overrides = const [],
  bool closeDatabase = true,
  runtime.ModelClient? modelClient = const _CaptureTestModel(),
}) async {
  final localDatabase = database ?? WideNoteLocalDatabase.inMemory();
  if (closeDatabase) {
    addTearDown(localDatabase.close);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(localDatabase),
        if (modelClient != null)
          modelClientProvider.overrideWithValue(modelClient),
        locationSettingsRepositoryProvider.overrideWithValue(
          InMemoryLocationSettingsRepository(),
        ),
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
    await _openNewRecordSheet(tester);
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
  if (text.trim().isEmpty &&
      find.byKey(const Key('capture-sheet')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('capture-sheet-close-button')));
    await tester.pumpAndSettle();
  }
}

Future<void> _openNewRecordSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tab-record-action')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('capture-sheet')), findsOneWidget);
}

Future<void> _openTab(WidgetTester tester, Key tabKey) async {
  await tester.tap(find.byKey(tabKey));
  await tester.pumpAndSettle();
}

Future<void> _pumpRouteChange(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
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

final class _CaptureTestModel implements runtime.ModelClient {
  const _CaptureTestModel({
    this.raw = const <String, Object?>{
      'memory_type': 'task_context',
      'confidence': 'high',
      'sensitivity': 'low',
      'durability': 'durable',
    },
  });

  final Map<String, Object?> raw;

  @override
  Future<runtime.ModelResponse> complete(runtime.ModelRequest request) async {
    if (request.context['prompt_ref'] == todoSuggestionPromptRef) {
      final title = _captureText(request.prompt);
      return runtime.ModelResponse(
        text: jsonEncode(<String, Object?>{
          'kind': 'action',
          'title': title,
          'confidence': 'high',
          'reason': 'explicit_action',
          'scheduled_at_label': null,
        }),
        raw: const <String, Object?>{
          'kind': 'action',
          'confidence': 'high',
          'reason': 'explicit_action',
        },
      );
    }
    return runtime.ModelResponse(text: _captureText(request.prompt), raw: raw);
  }
}

final class _ReviewCaptureModel extends _CaptureTestModel {
  const _ReviewCaptureModel()
    : super(
        raw: const <String, Object?>{
          'memory_type': 'credential',
          'confidence': 'high',
          'sensitivity': 'high',
          'durability': 'durable',
        },
      );
}

final class _SwitchingCaptureModel implements runtime.ModelClient {
  _SwitchingCaptureModel();

  bool failCaptureMemory = true;

  @override
  Future<runtime.ModelResponse> complete(runtime.ModelRequest request) async {
    if (failCaptureMemory &&
        request.prompt.contains(captureMemoryPromptCaptureTextMarker)) {
      throw StateError('temporary model outage');
    }
    return runtime.ModelResponse(
      text: _captureText(request.prompt),
      raw: const <String, Object?>{
        'memory_type': 'task_context',
        'confidence': 'high',
        'sensitivity': 'low',
        'durability': 'durable',
      },
    );
  }
}

String _captureText(String prompt) {
  final markerIndex = prompt.indexOf(captureMemoryPromptCaptureTextMarker);
  if (markerIndex == -1) {
    return prompt.replaceFirst('Summarize capture for Memory: ', '').trim();
  }
  return prompt
      .substring(markerIndex + captureMemoryPromptCaptureTextMarker.length)
      .trim();
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

Set<String> _sourceRefIds(List<Object?> sourceRefs) {
  return sourceRefs
      .whereType<Map>()
      .map((sourceRef) => sourceRef['id'])
      .whereType<String>()
      .toSet();
}
