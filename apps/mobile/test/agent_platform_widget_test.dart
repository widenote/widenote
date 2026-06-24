import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/app/widenote_app.dart';

void main() {
  testWidgets('plugins tab summarizes real local trace events', (tester) async {
    final database = WideNoteLocalDatabase.inMemory();
    _seedTraceEvents(database);
    await _pumpApp(tester, database);

    await tester.tap(find.byKey(const Key('tab-plugins')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('agent-platform-panel')),
      80,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Agent Observability'), findsOneWidget);
    expect(find.text('Trace events: 2'), findsWidgets);
    expect(find.text('Runs: 1'), findsWidgets);
    expect(find.text('Warnings: 1'), findsWidgets);
    expect(
      find.byKey(const Key('agent-platform-trace-trace-warning')),
      findsOneWidget,
    );
    expect(find.text('Permission denied by policy'), findsOneWidget);
  });

  testWidgets('trace console entry opens real trace list', (tester) async {
    final database = WideNoteLocalDatabase.inMemory();
    _seedTraceEvents(database);
    await _pumpApp(tester, database);

    await tester.tap(find.byKey(const Key('tab-plugins')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trace-console-entry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trace-console-page')), findsOneWidget);
    expect(find.text('Runtime summary'), findsOneWidget);
    expect(find.text('runtime.permission.denied'), findsOneWidget);
    expect(find.text('pack: pack.default'), findsWidgets);
    expect(find.text('agent: agent.capture_loop'), findsWidgets);
    expect(find.textContaining('duration: 8'), findsWidgets);
  });

  testWidgets('trace console renders empty state without fake runs', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    await _pumpApp(tester, database);

    await tester.tap(find.byKey(const Key('tab-plugins')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trace-console-entry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trace-console-empty')), findsOneWidget);
    expect(find.textContaining('task-queued-capture'), findsNothing);
    expect(find.textContaining('fake executor'), findsNothing);
  });
}

Future<void> _pumpApp(
  WidgetTester tester,
  WideNoteLocalDatabase database,
) async {
  addTearDown(database.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [localDatabaseProvider.overrideWithValue(database)],
      child: const WideNoteApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void _seedTraceEvents(WideNoteLocalDatabase database) {
  final now = DateTime.utc(2026, 6, 24, 12);
  database.traceEvents
    ..insert(
      TraceEventRecord(
        id: 'trace-ok',
        name: 'runtime.handler.output',
        level: 'info',
        traceTypeOverride: 'runtime.handler.output',
        runIdOverride: 'run-trace',
        severityOverride: 'info',
        message: 'Generated Memory proposal',
        packId: 'pack.default',
        agentId: 'agent.capture_loop',
        durationMs: 8,
        createdAt: now,
      ),
    )
    ..insert(
      TraceEventRecord(
        id: 'trace-warning',
        name: 'runtime.permission.denied',
        level: 'error',
        traceTypeOverride: 'runtime.permission.denied',
        runIdOverride: 'run-trace',
        severityOverride: 'error',
        status: 'denied',
        message: 'Permission denied by policy',
        packId: 'pack.default',
        agentId: 'agent.capture_loop',
        durationMs: 8,
        createdAt: now.add(const Duration(seconds: 1)),
      ),
    );
}
