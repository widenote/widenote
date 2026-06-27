import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
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

  testWidgets('trace console shows empty state', (tester) async {
    final database = WideNoteLocalDatabase.inMemory();
    await _pumpTraceConsole(tester, database);

    expect(find.byKey(const Key('trace-console-page')), findsOneWidget);
    expect(find.byKey(const Key('trace-console-empty')), findsOneWidget);
    expect(find.text('Log events: 0'), findsOneWidget);
  });

  testWidgets('trace console renders traces and refreshes read model', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    await _pumpTraceConsole(tester, database);

    database.traceEvents.insert(_trace('trace-1', 'runtime.handler.output'));
    await tester.tap(find.byKey(const Key('trace-console-refresh-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trace-console-row-trace-1')), findsOneWidget);
    expect(find.text('runtime.handler.output'), findsOneWidget);
    expect(find.text('pack: pack.default'), findsOneWidget);
    expect(find.text('agent: agent.capture_loop'), findsOneWidget);
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: TraceConsolePage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

TraceEventRecord _trace(
  String id,
  String type, {
  String runId = 'run-1',
  String severity = 'info',
  String status = 'ok',
}) {
  return TraceEventRecord(
    id: id,
    name: type,
    level: 'info',
    traceTypeOverride: type,
    runIdOverride: runId,
    severityOverride: severity,
    status: status,
    message: 'Generated local output',
    packId: 'pack.default',
    agentId: 'agent.capture_loop',
    durationMs: 4,
    createdAt: DateTime.utc(2026, 6, 24, 12),
  );
}
