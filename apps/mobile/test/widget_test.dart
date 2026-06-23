import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/app/widenote_app.dart';
import 'package:widenote_mobile/features/capture/application/capture_controller.dart';
import 'package:widenote_mobile/features/capture/application/capture_orchestrator.dart';

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

  testWidgets('quick capture creates record, auto-accepted Memory, and trace', (
    tester,
  ) async {
    await _pumpApp(tester);

    const captureText = 'Met Lin about WideNote source-linked todos.';

    await _submitQuickCapture(tester, captureText);

    expect(find.text(captureText), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('home-page')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.text('Memory 自动入库'), findsOneWidget);
    expect(find.textContaining('auto-accepted'), findsWidgets);

    await tester.drag(
      find.byKey(const Key('home-page')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('runtime.run.completed'), findsWidgets);
  });

  testWidgets('blank quick capture does not create a local record', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(find.text('idle'), findsOneWidget);
    expect(find.text('ready'), findsOneWidget);
    expect(find.text('2 linked'), findsOneWidget);
    expect(find.textContaining('Processed locally'), findsNothing);

    await _submitQuickCapture(tester, '   ');

    expect(find.text('idle'), findsOneWidget);
    expect(find.text('ready'), findsOneWidget);
    expect(find.text('2 linked'), findsOneWidget);
    expect(find.textContaining('Processed locally'), findsNothing);
  });

  testWidgets('raw capture stays visible when agent processing fails', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      overrides: [
        captureOrchestratorProvider.overrideWithValue(
          CaptureOrchestrator.local(model: const _FailingModel()),
        ),
      ],
    );

    const captureText = 'Preserve this raw note even when the agent fails.';
    await _submitQuickCapture(tester, captureText);

    expect(find.textContaining('Capture failed:'), findsOneWidget);
    expect(find.text('ready'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(captureText),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(captureText), findsOneWidget);
    expect(find.textContaining('Saved locally, agent failed'), findsOneWidget);
  });

  testWidgets('multiple captures update counters and linked todos', (
    tester,
  ) async {
    await _pumpApp(tester);

    await _submitQuickCapture(tester, 'First follow-up for Ada.');
    expect(find.text('1 processed'), findsOneWidget);
    expect(find.text('1 auto-accepted'), findsOneWidget);
    expect(find.text('3 linked'), findsOneWidget);

    await _submitQuickCapture(tester, 'Second follow-up for Chen.');
    expect(find.text('2 processed'), findsOneWidget);
    expect(find.text('2 auto-accepted'), findsOneWidget);
    expect(find.text('4 linked'), findsOneWidget);
  });

  testWidgets('sensitive capture can be accepted from Memory review', (
    tester,
  ) async {
    await _pumpApp(tester);

    const captureText = 'My API token should be reviewed before storage.';
    await _submitQuickCapture(tester, captureText);

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
      find.text('Memory 已入库'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Memory 已入库'), findsOneWidget);
    expect(find.textContaining('accepted'), findsWidgets);
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
    expect(find.text('Memory 已入库'), findsNothing);
  });

  testWidgets('generated todo appears on Todos tab with source link', (
    tester,
  ) async {
    await _pumpApp(tester);

    const captureText = 'Call Mina about launch review and sample todos.';
    await _submitQuickCapture(tester, captureText);
    await _openTab(tester, const Key('tab-todos'));

    expect(find.byKey(const Key('todos-page')), findsOneWidget);
    expect(find.text('Follow up: $captureText'), findsOneWidget);
    expect(find.text('suggested by agent'), findsOneWidget);
    expect(
      _visibleTextValues(tester).where(
        (text) => text.startsWith('source: ') && !text.contains('placeholder'),
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

      expect(events.map((event) => event.type), [
        runtime.WnEventTypes.captureCreated,
        runtime.WnEventTypes.memoryProposed,
        runtime.WnEventTypes.cardCreated,
        runtime.WnEventTypes.insightCreated,
        runtime.WnEventTypes.todoSuggested,
      ]);
      expect(
        events
            .where((event) => event.type == runtime.WnEventTypes.todoSuggested)
            .single
            .packId,
        'pack.todo',
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

  testWidgets('Chat page shows sessions and disabled input placeholder', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _openTab(tester, const Key('tab-chat'));

    expect(find.byKey(const Key('chat-page')), findsOneWidget);
    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('Daily review'), findsOneWidget);
    expect(find.text('Memory QA'), findsOneWidget);
    expect(find.text('Agent Pack sandbox'), findsOneWidget);
    expect(
      find.text('Ask WideNote about a record, Memory item, or pack run...'),
      findsOneWidget,
    );

    final input = tester.widget<TextField>(find.byType(TextField));
    expect(input.enabled, isFalse);
  });
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
      child: const WideNoteApp(),
    ),
  );
  await tester.pumpAndSettle();
  if (find.byKey(const Key('home-page')).evaluate().isEmpty) {
    await _openTab(tester, const Key('tab-home'));
  }
}

Future<void> _submitQuickCapture(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('quick-capture-field')), text);
  await tester.tap(find.byKey(const Key('record-capture-button')));
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
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  final center = tester.getCenter(finder);
  if (center.dy > 500) {
    await tester.drag(
      find.byType(Scrollable).first,
      Offset(0, -(center.dy - 440)),
    );
    await tester.pumpAndSettle();
  }
}

Iterable<String> _visibleTextValues(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data)
      .whereType<String>();
}

final class _FailingModel implements runtime.ModelClient {
  const _FailingModel();

  @override
  Future<runtime.ModelResponse> complete(runtime.ModelRequest request) {
    throw StateError('model unavailable');
  }
}
