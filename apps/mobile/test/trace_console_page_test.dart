import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/features/plugins/application/pack_catalog.dart';
import 'package:widenote_mobile/features/traces/application/trace_console_controller.dart';
import 'package:widenote_mobile/features/traces/presentation/trace_console_page.dart';
import 'package:widenote_mobile/l10n/l10n.dart';

void main() {
  test('trace snapshot counts distinct runs and warning-like rows', () {
    final database = WideNoteLocalDatabase.inMemory();
    final container = ProviderContainer(
      overrides: [localDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);

    database.traceEvents
      ..insert(_trace('trace-1', 'runtime.run.started'))
      ..insert(
        _trace(
          'trace-2',
          'runtime.handler.output',
          runId: 'run-1',
          severity: 'warning',
        ),
      )
      ..insert(
        _trace(
          'trace-3',
          'runtime.run.completed',
          runId: 'run-2',
          status: 'failed',
        ),
      );

    final snapshot = container.read(traceConsoleControllerProvider);

    expect(snapshot.runCount, 2);
    expect(snapshot.warningCount, 2);
    expect(snapshot.items.map((item) => item.id), <String>[
      'trace-3',
      'trace-2',
      'trace-1',
    ]);
  });

  testWidgets('agent console shows empty states and approval scaffold', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    await _pumpTraceConsole(tester, database);

    expect(find.byKey(const Key('trace-console-page')), findsOneWidget);
    expect(find.text('Log events: 0'), findsOneWidget);
    expect(find.text('Total: 0'), findsOneWidget);
    await _scrollTo(tester, const Key('trace-console-empty'));
    expect(find.byKey(const Key('trace-console-empty')), findsOneWidget);
    expect(find.byKey(const Key('approval-queue-empty')), findsOneWidget);
    expect(find.text('No pending local action approvals.'), findsOneWidget);
  });

  testWidgets('agent console renders traces and refreshes read model', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    await _pumpTraceConsole(tester, database);

    database.traceEvents.insert(_trace('trace-1', 'runtime.handler.output'));
    await tester.tap(find.byKey(const Key('trace-console-refresh-button')));
    await tester.pumpAndSettle();

    await _scrollTo(tester, const Key('trace-console-row-trace-1'));
    expect(find.byKey(const Key('trace-console-row-trace-1')), findsOneWidget);
    expect(find.text('runtime.handler.output'), findsOneWidget);

    await tester.tap(find.byKey(const Key('trace-console-row-trace-1')));
    await tester.pumpAndSettle();

    expect(find.text('pack: pack.default'), findsOneWidget);
    expect(find.text('agent: agent.capture_loop'), findsOneWidget);
  });

  testWidgets('agent console summarizes filters and run mode details', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    ensureBuiltInPackInstallations(database);
    _seedTriggerEvent(database);
    _seedRuntimeRecords(database);
    await _pumpTraceConsole(tester, database);

    expect(find.text('Total: 6'), findsOneWidget);
    expect(find.text('Active: 2'), findsOneWidget);
    expect(find.text('Failed: 2'), findsOneWidget);
    expect(find.text('Denied: 1'), findsOneWidget);
    expect(find.text('Blocked: 1'), findsOneWidget);

    await _tap(tester, const Key('agent-console-run-run-active'));
    expect(find.text('run mode: read-only'), findsOneWidget);
    expect(find.text('attempt: 1'), findsOneWidget);
    expect(find.text('2 outputs'), findsOneWidget);

    await _tap(tester, const Key('agent-console-filter-failed'));
    expect(
      find.byKey(const Key('agent-console-run-run-failed')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('agent-console-run-run-active')), findsNothing);
    expect(
      find.byKey(const Key('agent-console-task-task-failed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('agent-console-task-task-blocked')),
      findsNothing,
    );
  });

  testWidgets('agent console renders child delegation links and escalation', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    database.traceEvents
      ..insert(
        _trace(
          'trace-delegate-success',
          'runtime.delegation.succeeded',
          runId: 'run-parent',
          status: 'ok',
          message: 'Child delegation succeeded.',
          payload: const <String, Object?>{
            'trace_type': 'delegation',
            'child_delegation_id': 'delegate-1',
            'child_run_id': 'run-child-1',
            'child_status': 'succeeded',
            'input': 'SHOULD_NOT_RENDER',
            'instructions': 'SHOULD_NOT_RENDER',
          },
        ),
      )
      ..insert(
        _trace(
          'trace-delegate-rejected',
          'runtime.delegation.rejected',
          runId: 'run-parent',
          severity: 'warning',
          status: 'rejected',
          message: 'Child delegation rejected.',
          payload: const <String, Object?>{
            'trace_type': 'delegation',
            'child_delegation_id': 'delegate-2',
            'child_status': 'rejected',
            'violation_codes': <Object?>['run_mode_escalation'],
            'api_key': 'SHOULD_NOT_RENDER',
          },
        ),
      );

    await _pumpTraceConsole(tester, database);

    await _tap(tester, const Key('trace-console-row-trace-delegate-success'));
    expect(
      find.byKey(
        const Key('agent-console-child-delegation-trace-delegate-success'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('agent-console-child-run-trace-delegate-success')),
      findsOneWidget,
    );
    expect(find.text('child run: run-child-1'), findsOneWidget);
    expect(find.text('child status: succeeded'), findsOneWidget);

    await _tap(tester, const Key('trace-console-row-trace-delegate-rejected'));
    expect(find.text('child status: rejected'), findsOneWidget);
    expect(
      find.byKey(
        const Key(
          'agent-console-delegation-violations-trace-delegate-rejected',
        ),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('run_mode_escalation'), findsWidgets);
    expect(find.textContaining('SHOULD_NOT_RENDER'), findsNothing);
    expect(find.textContaining('api_key'), findsNothing);
    expect(find.textContaining('instructions'), findsNothing);
  });

  testWidgets('agent console redacts sensitive trace payload and errors', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    ensureBuiltInPackInstallations(database);
    _seedTriggerEvent(database);
    final now = DateTime.utc(2026, 6, 24, 12);
    database.runtimeTasks.insert(
      _task(
        'task-secret',
        status: 'failed',
        updatedAt: now,
        error: 'authorization token api_key=SHOULD_NOT_RENDER',
      ),
    );
    database.runtimeRuns.insert(
      _run(
        'run-secret',
        taskId: 'task-secret',
        status: 'failed',
        error: 'Bearer token SHOULD_NOT_RENDER',
        completedAt: now.add(const Duration(seconds: 2)),
      ),
    );
    database.traceEvents.insert(
      _trace(
        'trace-secret',
        'runtime.tool.failed',
        runId: 'run-secret',
        taskId: 'task-secret',
        eventId: 'capture-secret',
        severity: 'error',
        status: 'failed',
        message: 'authorization token SHOULD_NOT_RENDER',
        payload: const <String, Object?>{
          'safe': 'visible',
          'authorization': 'Bearer SHOULD_NOT_RENDER',
          'api_key': 'SHOULD_NOT_RENDER',
          'nested': <String, Object?>{'token': 'SHOULD_NOT_RENDER'},
        },
      ),
    );

    await _pumpTraceConsole(tester, database);
    await _tap(tester, const Key('agent-console-run-run-secret'));
    await _tap(tester, const Key('trace-console-row-trace-secret'));

    expect(find.textContaining('SHOULD_NOT_RENDER'), findsNothing);
    expect(find.textContaining('authorization'), findsNothing);
    expect(find.textContaining('api_key'), findsNothing);
    expect(find.textContaining('token'), findsNothing);
    expect(find.text('[redacted]'), findsWidgets);
    expect(find.textContaining('safe: visible'), findsOneWidget);
  });

  testWidgets('agent console source detail returns with system back', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    database.traceEvents.insert(
      _trace(
        'trace-source',
        'runtime.handler.output',
        eventId: 'capture-from-trace',
      ),
    );

    await _pumpTraceConsoleRouter(tester, database);
    await _tap(tester, const Key('trace-console-row-trace-source'));
    await _scrollTo(
      tester,
      const Key('trace-console-open-source-trace-source'),
    );
    await tester.tap(
      find.byKey(const Key('trace-console-open-source-trace-source')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trace-source-destination')), findsOneWidget);
    expect(find.text('capture-from-trace'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trace-console-page')), findsOneWidget);
    expect(find.byKey(const Key('trace-source-destination')), findsNothing);
  });
}

Future<void> _pumpTraceConsole(
  WidgetTester tester,
  WideNoteLocalDatabase database,
) async {
  addTearDown(database.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [localDatabaseProvider.overrideWithValue(database)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: TraceConsolePage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpTraceConsoleRouter(
  WidgetTester tester,
  WideNoteLocalDatabase database,
) async {
  addTearDown(database.close);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: TraceConsolePage()),
      ),
      GoRoute(
        path: '/timeline/items/:itemId',
        builder: (context, state) => Scaffold(
          key: const Key('trace-source-destination'),
          body: Text(state.pathParameters['itemId'] ?? ''),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [localDatabaseProvider.overrideWithValue(database)],
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await _scrollTo(tester, key);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  if (finder.evaluate().isNotEmpty) {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    return;
  }
  try {
    await tester.scrollUntilVisible(
      finder,
      220,
      scrollable: find.byType(Scrollable).first,
    );
  } catch (_) {
    await tester.scrollUntilVisible(
      finder,
      -220,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.pumpAndSettle();
}

void _seedRuntimeRecords(WideNoteLocalDatabase database) {
  final now = DateTime.utc(2026, 6, 24, 12);
  database.runtimeTasks
    ..insert(_task('task-active', status: 'running', updatedAt: now))
    ..insert(_task('task-failed', status: 'failed', updatedAt: now))
    ..insert(_task('task-denied', status: 'denied', updatedAt: now))
    ..insert(
      _task(
        'task-blocked',
        status: 'blocked',
        updatedAt: now,
        missingDependencyIds: const <Object?>['task-upstream'],
      ),
    );
  database.runtimeRuns
    ..insert(
      _run(
        'run-active',
        taskId: 'task-active',
        status: 'running',
        outputEventIds: const <Object?>['out-1', 'out-2'],
        payload: const <String, Object?>{'runtime_run_mode': 'readOnly'},
      ),
    )
    ..insert(
      _run(
        'run-failed',
        taskId: 'task-failed',
        status: 'failed',
        error: 'Model failed safely.',
        completedAt: now.add(const Duration(seconds: 4)),
        payload: const <String, Object?>{'runtime_run_mode': 'confirm'},
      ),
    );
  database.traceEvents.insert(
    _trace(
      'trace-run-failed',
      'runtime.run.failed',
      runId: 'run-failed',
      taskId: 'task-failed',
      eventId: 'capture-1',
      severity: 'error',
      status: 'failed',
    ),
  );
}

void _seedTriggerEvent(WideNoteLocalDatabase database) {
  database.eventLog.append(
    EventLogEntry(
      id: 'capture-1',
      type: 'wn.capture.created',
      actor: 'user',
      subjectKind: 'capture',
      subjectId: 'capture-1',
      createdAt: DateTime.utc(2026, 6, 24, 10),
    ),
  );
}

RuntimeTaskRecord _task(
  String id, {
  required String status,
  required DateTime updatedAt,
  String? error,
  List<Object?> missingDependencyIds = const <Object?>[],
}) {
  return RuntimeTaskRecord(
    id: id,
    packId: 'pack.default',
    packVersion: '0.1.0',
    agentId: 'agent.capture_loop',
    handlerId: 'agent.capture_loop',
    subscriptionId: 'sub.capture_created',
    triggerEventId: 'capture-1',
    identityKey: id,
    status: status,
    attempts: status == 'running' ? 1 : 2,
    maxAttempts: 2,
    missingDependencyIds: missingDependencyIds,
    error: error,
    createdAt: DateTime.utc(2026, 6, 24, 11),
    updatedAt: updatedAt,
  );
}

RuntimeRunRecord _run(
  String id, {
  required String taskId,
  required String status,
  DateTime? completedAt,
  String? error,
  List<Object?> outputEventIds = const <Object?>[],
  Map<String, Object?> payload = const <String, Object?>{},
}) {
  return RuntimeRunRecord(
    id: id,
    taskId: taskId,
    packId: 'pack.default',
    packVersion: '0.1.0',
    agentId: 'agent.capture_loop',
    handlerId: 'agent.capture_loop',
    status: status,
    startedAt: DateTime.utc(2026, 6, 24, 12),
    completedAt: completedAt,
    attempt: 1,
    outputEventIds: outputEventIds,
    error: error,
    payload: payload,
  );
}

TraceEventRecord _trace(
  String id,
  String type, {
  String runId = 'run-1',
  String? taskId,
  String? eventId,
  String severity = 'info',
  String status = 'ok',
  String message = 'Generated local output',
  Map<String, Object?> payload = const <String, Object?>{},
}) {
  return TraceEventRecord(
    id: id,
    name: type,
    level: 'info',
    traceTypeOverride: type,
    runIdOverride: runId,
    severityOverride: severity,
    status: status,
    message: message,
    sourceEventId: eventId,
    sourceTaskId: taskId,
    payload: payload,
    packId: 'pack.default',
    agentId: 'agent.capture_loop',
    durationMs: 4,
    createdAt: DateTime.utc(2026, 6, 24, 12),
  );
}
