import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/app/widenote_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('phase-one local journey works through real app routes', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);

    await _pumpApp(tester, database);

    const captureText = 'Integration journey captures source-linked todos.';
    await _submitCapture(tester, captureText);
    await _waitFor(
      tester,
      () => database.todos.readAll().isNotEmpty,
      description: 'initial capture todo',
      diagnostics: () => _databaseDiagnostics(database),
    );

    final capture = database.captures.readAll().single;
    final todo = database.todos.readAll().single;
    expect(capture.payload['text'], captureText);
    expect(database.memoryItems.readAll(status: 'active'), hasLength(1));
    expect(database.cards.readAll(status: 'active'), hasLength(2));
    expect(database.insights.readAll(status: 'active'), hasLength(3));
    expect(database.traceEvents.readAll(), isNotEmpty);
    expect(todo.sourceCaptureId, capture.id);

    await tester.tap(find.byKey(const Key('tab-todos')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('todo-row-${todo.id}')), findsOneWidget);

    await tester.tap(find.byKey(Key('todo-source-${todo.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-item-detail-page')), findsOneWidget);
    expect(find.text('Capture Detail'), findsOneWidget);
    expect(find.text(captureText), findsWidgets);

    await tester.tap(find.byKey(const Key('tab-todos')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('todo-checkbox-${todo.id}')));
    await tester.pumpAndSettle();
    expect(database.todos.readById(todo.id)!.status, 'completed');
    expect(find.byKey(Key('todo-row-${todo.id}')), findsNothing);

    await tester.tap(find.byKey(const Key('tab-plugins')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('permission-gate-entry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('permission-gate-page')), findsOneWidget);
    expect(
      database.permissionGrants
          .readByPackAndPermission('pack.default', 'model.complete')!
          .status,
      'granted',
    );
    await tester.tap(
      find.byKey(
        const Key('permission-action-revoke-pack.default-model.complete'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      database.permissionGrants
          .readByPackAndPermission('pack.default', 'model.complete')!
          .status,
      'revoked',
    );
    final memoryCountBeforeBlockedCapture = database.memoryItems
        .readAll(status: 'active')
        .length;
    const blockedCaptureText =
        'Capture after revoking model.complete keeps raw input only.';
    await tester.tap(find.byKey(const Key('tab-home')));
    await tester.pumpAndSettle();
    await _submitCapture(tester, blockedCaptureText);
    await _waitFor(
      tester,
      () =>
          database.captures.readAll().any(
            (record) => record.payload['text'] == blockedCaptureText,
          ) &&
          database.traceEvents.readAll().any(
            (trace) => trace.name == 'runtime.permission.denied',
          ),
      description: 'blocked capture raw record and denied trace',
      diagnostics: () => _databaseDiagnostics(database),
    );
    expect(
      database.captures.readAll().map((record) => record.payload['text']),
      contains(blockedCaptureText),
    );
    expect(
      database.memoryItems.readAll(status: 'active'),
      hasLength(memoryCountBeforeBlockedCapture),
    );
    expect(
      database.traceEvents.readAll().map((trace) => trace.name),
      contains('runtime.permission.denied'),
    );

    await tester.tap(find.byKey(const Key('tab-plugins')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('permission-gate-entry')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('script.execute'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const Key('permission-action-deferred-community packs-script.execute'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('tab-plugins')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-entry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('backup-page')), findsOneWidget);
    await tester.tap(find.byKey(const Key('backup-export-button')));
    await tester.pumpAndSettle();
    expect(find.text('captures: 2'), findsOneWidget);
    expect(find.text('todos: 1'), findsOneWidget);
    expect(find.textContaining('"backup_mode": "safe"'), findsOneWidget);
    expect(
      find.byKey(const Key('backup-full-export-disabled-button')),
      findsNothing,
    );

    final eventTypes = database.eventLog.readAll().map((event) => event.type);
    expect(
      eventTypes,
      containsAll(<String>[
        runtime.WnEventTypes.captureCreated,
        runtime.WnEventTypes.memoryProposed,
        runtime.WnEventTypes.cardCreated,
        runtime.WnEventTypes.insightCreated,
        runtime.WnEventTypes.todoSuggested,
      ]),
    );
  });

  testWidgets(
    'safe backup restores through real app route and remains usable',
    (tester) async {
      final source = WideNoteLocalDatabase.inMemory();
      addTearDown(source.close);
      await _pumpApp(tester, source);

      const restoredCaptureText =
          'Restorable backup journey keeps source-linked local context.';
      await _submitCapture(tester, restoredCaptureText);
      await _waitFor(
        tester,
        () => source.todos.readAll().isNotEmpty,
        description: 'source backup todo',
        diagnostics: () => _databaseDiagnostics(source),
      );
      final backupJson = LocalBackupService(source).exportJson();

      final target = WideNoteLocalDatabase.inMemory();
      addTearDown(target.close);
      await _pumpApp(tester, target);

      await tester.tap(find.byKey(const Key('tab-plugins')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('backup-entry')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('backup-import-field')),
        backupJson,
      );
      await tester.pumpAndSettle();
      await _unfocus(tester);
      await tester.ensureVisible(find.byKey(const Key('backup-import-button')));
      await tester.tap(find.byKey(const Key('backup-import-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('backup-inline-outcome')), findsOneWidget);
      expect(target.captures.readAll(), hasLength(1));
      expect(target.memoryItems.readAll(status: 'active'), hasLength(1));
      expect(target.todos.readAll(), hasLength(1));

      await tester.tap(find.byKey(const Key('tab-home')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-page')), findsOneWidget);
      expect(
        target.captures.readAll().single.payload['text'],
        restoredCaptureText,
      );

      await tester.tap(find.byKey(const Key('open-memory-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('memory-page')), findsOneWidget);
      expect(
        target.memoryItems.readAll(status: 'active').single.body,
        isNotEmpty,
      );

      await tester.tap(find.byKey(const Key('tab-todos')));
      await tester.pumpAndSettle();
      final restoredTodo = target.todos.readAll().single;
      expect(find.byKey(Key('todo-row-${restoredTodo.id}')), findsOneWidget);

      await tester.tap(find.byKey(const Key('tab-chat')));
      await tester.pumpAndSettle();
      await _sendChat(tester, 'What local context was restored?');
      expect(target.chatMessages.readAll(), hasLength(2));
      expect(find.textContaining(restoredCaptureText), findsWidgets);

      await tester.tap(find.byKey(const Key('tab-home')));
      await tester.pumpAndSettle();
      await _submitCapture(
        tester,
        'Fresh capture after safe restore still runs the local pipeline.',
      );
      await _waitFor(
        tester,
        () => target.memoryItems.readAll(status: 'active').length == 2,
        description: 'post-restore capture pipeline',
        diagnostics: () => _databaseDiagnostics(target),
      );
      expect(target.captures.readAll(), hasLength(2));
      expect(target.memoryItems.readAll(status: 'active'), hasLength(2));
    },
  );
}

Future<void> _pumpApp(
  WidgetTester tester,
  WideNoteLocalDatabase database,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [localDatabaseProvider.overrideWithValue(database)],
      child: const WideNoteApp(locale: Locale('en')),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _submitCapture(WidgetTester tester, String text) async {
  final field = find.byKey(const Key('quick-capture-field'));
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  await _unfocus(tester);
  await tester.ensureVisible(find.byKey(const Key('record-capture-button')));
  await tester.tap(find.byKey(const Key('record-capture-button')));
  await tester.pump();
}

Future<void> _sendChat(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('chat-input-field')), text);
  await _unfocus(tester);
  await tester.ensureVisible(find.byKey(const Key('chat-send-button')));
  await tester.tap(find.byKey(const Key('chat-send-button')));
  await tester.pumpAndSettle();
}

Future<void> _unfocus(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

Future<void> _waitFor(
  WidgetTester tester,
  bool Function() condition, {
  required String description,
  String Function()? diagnostics,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      final suffix = diagnostics == null ? '' : ' ${diagnostics()}';
      throw TestFailure('Timed out waiting for $description.$suffix');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

String _databaseDiagnostics(WideNoteLocalDatabase database) {
  final captureStatuses = database.captures
      .readAll()
      .map((capture) => '${capture.id}:${capture.status}')
      .join(',');
  final eventTypes = database.eventLog
      .readAll()
      .map((event) => event.type)
      .join(',');
  final traceNames = database.traceEvents
      .readAll()
      .map((trace) => trace.name)
      .join(',');
  final permissions = database.permissionGrants
      .readAll()
      .map((grant) => '${grant.packId}:${grant.permissionId}:${grant.status}')
      .join(',');
  return 'captures=${database.captures.readAll().length} '
      'captureStatuses=[$captureStatuses] '
      'todos=${database.todos.readAll().length} '
      'memories=${database.memoryItems.readAll(status: 'active').length} '
      'permissions=[$permissions] '
      'events=[$eventTypes] traces=[$traceNames]';
}
