import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/app/widenote_app.dart';
import 'package:widenote_mobile/features/agent_status/application/agent_execution_status_controller.dart';
import 'package:widenote_mobile/features/agent_status/application/agent_status_platform.dart';
import 'package:widenote_mobile/features/agent_status/presentation/agent_execution_status_overlay.dart';
import 'package:widenote_mobile/features/location/application/location_settings_controller.dart';
import 'package:widenote_mobile/l10n/l10n.dart';

void main() {
  testWidgets(
    'overlay stays hidden when no current or recent Agent work exists',
    (tester) async {
      final database = WideNoteLocalDatabase.inMemory();
      await _pumpOverlay(tester, database);

      expect(find.byKey(const Key('agent-status-overlay')), findsNothing);
      expect(
        find.byKey(const Key('agent-status-platform-sync')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'overlay opens a redacted status sheet with active and attention counts',
    (tester) async {
      final database = WideNoteLocalDatabase.inMemory();
      final now = DateTime.utc(2026, 7, 3, 12);
      _insertTask(
        database,
        _task(
          'task-running',
          status: 'running',
          leasedUntil: now.add(const Duration(minutes: 3)),
          updatedAt: now,
        ),
      );
      _insertTask(
        database,
        _task(
          'task-retrying',
          status: 'queued',
          attempts: 1,
          scheduledAt: now.add(const Duration(minutes: 5)),
          updatedAt: now,
        ),
      );
      _insertTask(
        database,
        _task(
          'task-failed',
          status: 'failed',
          attempts: 2,
          updatedAt: now,
          error: 'raw private record SHOULD_NOT_RENDER',
        ),
      );
      await _pumpOverlay(tester, database, now: now);

      expect(find.byKey(const Key('agent-status-overlay')), findsOneWidget);
      expect(find.text('Agent work needs attention'), findsOneWidget);
      expect(
        find.textContaining('1 running / 0 queued / 1 retrying'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('agent-status-open-sheet')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('agent-status-sheet')), findsOneWidget);
      expect(find.text('Running: 1'), findsOneWidget);
      expect(find.text('Retrying: 1'), findsOneWidget);
      expect(find.text('Attention: 1'), findsOneWidget);
      expect(
        find.byKey(const Key('agent-status-item-task-failed')),
        findsOneWidget,
      );
      expect(
        find.text('Error details are kept in the local Log Center.'),
        findsOneWidget,
      );
      expect(find.textContaining('SHOULD_NOT_RENDER'), findsNothing);
    },
  );

  testWidgets('sheet opens the existing Log Center Agents child route', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    final now = DateTime.utc(2026, 7, 3, 12);
    _insertTask(
      database,
      _task(
        'task-running',
        status: 'running',
        leasedUntil: now.add(const Duration(minutes: 3)),
        updatedAt: now,
      ),
    );
    await _pumpApp(tester, database, now: now);

    await tester.tap(find.byKey(const Key('agent-status-open-sheet')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('agent-status-open-log-center')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trace-agents-page')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}

Future<void> _pumpOverlay(
  WidgetTester tester,
  WideNoteLocalDatabase database, {
  DateTime? now,
}) async {
  addTearDown(database.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(database),
        agentExecutionStatusNowProvider.overrideWithValue(
          () => now ?? DateTime.utc(2026, 7, 3, 12),
        ),
        agentStatusPlatformClientProvider.overrideWithValue(
          const _NoopPlatformClient(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AgentExecutionStatusLayer(
          showBottomNavigationBar: false,
          child: SizedBox(key: Key('agent-status-test-child')),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpApp(
  WidgetTester tester,
  WideNoteLocalDatabase database, {
  required DateTime now,
}) async {
  addTearDown(database.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(database),
        agentExecutionStatusNowProvider.overrideWithValue(() => now),
        agentStatusPlatformClientProvider.overrideWithValue(
          const _NoopPlatformClient(),
        ),
        locationSettingsRepositoryProvider.overrideWithValue(
          InMemoryLocationSettingsRepository(),
        ),
      ],
      child: const WideNoteApp(),
    ),
  );
  await tester.pumpAndSettle();
}

RuntimeTaskRecord _task(
  String id, {
  required String status,
  DateTime? updatedAt,
  DateTime? leasedUntil,
  DateTime? scheduledAt,
  int attempts = 0,
  String? error,
}) {
  final createdAt = DateTime.utc(2026, 7, 3, 11);
  return RuntimeTaskRecord(
    id: id,
    packId: 'pack.default',
    packVersion: '1.0.0',
    agentId: 'agent.capture_loop',
    handlerId: 'handler.capture',
    subscriptionId: 'subscription.capture',
    triggerEventId: 'event-$id',
    status: status,
    attempts: attempts,
    maxAttempts: 2,
    leasedUntil: leasedUntil,
    scheduledAt: scheduledAt,
    error: error,
    createdAt: createdAt,
    updatedAt: updatedAt ?? createdAt,
  );
}

void _insertTask(WideNoteLocalDatabase database, RuntimeTaskRecord task) {
  database.eventLog.append(
    EventLogEntry(
      id: task.triggerEventId,
      type: 'wn.capture.created',
      actor: 'user',
      createdAt: task.createdAt,
    ),
  );
  database.runtimeTasks.insert(task);
}

final class _NoopPlatformClient implements AgentStatusPlatformClient {
  const _NoopPlatformClient();

  @override
  Future<AgentStatusPlatformResult> sync(
    AgentStatusPlatformPayload payload,
  ) async {
    return const AgentStatusPlatformResult(
      notificationStatus: 'test',
      liveActivityStatus: 'test',
    );
  }
}
