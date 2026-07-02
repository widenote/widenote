import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/app/widenote_app.dart';
import 'package:widenote_mobile/features/location/application/location_settings_controller.dart';

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

    expect(find.text('Log Center'), findsWidgets);
    expect(find.text('Raw logs: 2'), findsWidgets);
    expect(find.text('Runs: 1'), findsWidgets);
    expect(find.text('Tasks: 0'), findsWidgets);
    expect(find.text('Failed: 0'), findsWidgets);
    expect(
      find.byKey(const Key('agent-platform-trace-trace-warning')),
      findsOneWidget,
    );
    expect(find.text('Permission denied by policy'), findsOneWidget);
  });

  testWidgets('trace console entry opens real raw log list', (tester) async {
    final database = WideNoteLocalDatabase.inMemory();
    _seedTraceEvents(database);
    await _pumpApp(tester, database);

    await tester.tap(find.byKey(const Key('tab-plugins')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trace-console-entry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trace-console-page')), findsOneWidget);
    expect(find.text('Local log summary'), findsOneWidget);
    expect(
      find.byKey(const Key('trace-console-raw-logs-entry')),
      findsOneWidget,
    );
    await _tap(tester, const Key('trace-console-raw-logs-entry-button'));
    expect(find.byKey(const Key('trace-raw-logs-page')), findsOneWidget);
    await _scrollTo(tester, const Key('trace-raw-text-box'));
    expect(find.byKey(const Key('trace-raw-text-box')), findsOneWidget);
    expect(find.textContaining('runtime.permission.denied'), findsOneWidget);
    expect(find.textContaining('pack_id: pack.default'), findsWidgets);
    expect(find.textContaining('agent_id: agent.capture_loop'), findsWidgets);
    expect(find.textContaining('duration_ms: 8'), findsWidgets);
  });

  testWidgets('raw log stream includes source references as text', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    _seedTraceEvents(database);
    await _pumpApp(tester, database);

    await tester.tap(find.byKey(const Key('tab-plugins')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trace-console-entry')));
    await tester.pumpAndSettle();

    await _tap(tester, const Key('trace-console-raw-logs-entry-button'));

    await _scrollTo(tester, const Key('trace-raw-text-box'));
    expect(find.byKey(const Key('trace-raw-text-box')), findsOneWidget);
    expect(
      find.textContaining('source_event_id: capture-source'),
      findsWidgets,
    );
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

    await _tap(tester, const Key('trace-console-raw-logs-entry-button'));
    await _scrollTo(tester, const Key('trace-raw-text-box'));
    expect(find.textContaining('No runtime logs yet.'), findsOneWidget);
    expect(find.textContaining('task-queued-capture'), findsNothing);
    expect(find.textContaining('fake executor'), findsNothing);
  });
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

Future<void> _pumpApp(
  WidgetTester tester,
  WideNoteLocalDatabase database,
) async {
  addTearDown(database.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(database),
        locationSettingsRepositoryProvider.overrideWithValue(
          InMemoryLocationSettingsRepository(),
        ),
      ],
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
        sourceEventId: 'capture-source',
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
