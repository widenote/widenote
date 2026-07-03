import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/features/agent_status/application/agent_execution_status_controller.dart';
import 'package:widenote_mobile/features/agent_status/application/agent_status_platform.dart';

void main() {
  test(
    'projection derives active, retrying, recovering, and attention state',
    () {
      final database = WideNoteLocalDatabase.inMemory();
      final now = DateTime.utc(2026, 7, 3, 12);
      final container = ProviderContainer(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          agentExecutionStatusNowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      _insertTask(
        database,
        _task(
          'task-running',
          status: 'running',
          updatedAt: now.subtract(const Duration(seconds: 15)),
          leasedUntil: now.add(const Duration(minutes: 2)),
        ),
      );
      _insertTask(
        database,
        _task(
          'task-queued',
          status: 'queued',
          updatedAt: now.subtract(const Duration(seconds: 12)),
        ),
      );
      _insertTask(
        database,
        _task(
          'task-retrying',
          status: 'queued',
          attempts: 1,
          scheduledAt: now.add(const Duration(minutes: 4)),
          updatedAt: now.subtract(const Duration(seconds: 10)),
        ),
      );
      _insertTask(
        database,
        _task(
          'task-recovering',
          status: 'running',
          attempts: 1,
          updatedAt: now.subtract(const Duration(minutes: 4)),
          leasedUntil: now.subtract(const Duration(seconds: 1)),
        ),
      );
      _insertTask(
        database,
        _task(
          'task-failed',
          status: 'failed',
          attempts: 2,
          updatedAt: now.subtract(const Duration(minutes: 2)),
          error: 'secret raw prompt SHOULD_NOT_RENDER',
        ),
      );

      final snapshot = container.read(agentExecutionStatusControllerProvider);

      expect(snapshot.runningCount, 1);
      expect(snapshot.queuedCount, 1);
      expect(snapshot.retryingCount, 1);
      expect(snapshot.recoveringCount, 1);
      expect(snapshot.failedCount, 1);
      expect(snapshot.overallStatus, AgentExecutionOverallStatus.attention);
      expect(snapshot.primaryItem?.taskId, 'task-failed');
      expect(snapshot.primaryItem?.hasError, isTrue);

      final payload = AgentStatusPlatformPayload.fromSnapshot(
        snapshot,
        labels: const AgentStatusPlatformLabels(
          title: 'Agent work needs attention',
          body: '1 running / 1 queued / 2 retrying / 1 need attention',
        ),
      );
      expect(payload.toJson().toString(), isNot(contains('SHOULD_NOT_RENDER')));
      expect(payload.toJson(), isNot(containsPair('items', anything)));
      expect(payload.failedCount, 1);
      expect(payload.items.map((item) => item.taskId), contains('task-failed'));
    },
  );

  test(
    'old terminal successes are hidden while recent completion is visible',
    () {
      final database = WideNoteLocalDatabase.inMemory();
      final now = DateTime.utc(2026, 7, 3, 12);
      final container = ProviderContainer(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          agentExecutionStatusNowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      _insertTask(
        database,
        _task(
          'task-old-success',
          status: 'succeeded',
          updatedAt: now.subtract(const Duration(minutes: 30)),
        ),
      );
      _insertTask(
        database,
        _task(
          'task-recent-success',
          status: 'succeeded',
          updatedAt: now.subtract(const Duration(minutes: 3)),
        ),
      );

      final snapshot = container.read(agentExecutionStatusControllerProvider);

      expect(snapshot.succeededCount, 1);
      expect(snapshot.overallStatus, AgentExecutionOverallStatus.completed);
      expect(
        snapshot.items.map((item) => item.taskId),
        isNot(contains('task-old-success')),
      );
      expect(
        snapshot.items.map((item) => item.taskId),
        contains('task-recent-success'),
      );
    },
  );

  test('stale running task without retry budget needs attention', () {
    final database = WideNoteLocalDatabase.inMemory();
    final now = DateTime.utc(2026, 7, 3, 12);
    final container = ProviderContainer(
      overrides: [
        localDatabaseProvider.overrideWithValue(database),
        agentExecutionStatusNowProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);

    _insertTask(
      database,
      _task(
        'task-stale-exhausted',
        status: 'running',
        attempts: 2,
        maxAttempts: 2,
        leasedUntil: now.subtract(const Duration(seconds: 1)),
        updatedAt: now.subtract(const Duration(minutes: 4)),
      ),
    );

    final snapshot = container.read(agentExecutionStatusControllerProvider);

    expect(snapshot.recoveringCount, 0);
    expect(snapshot.failedCount, 1);
    expect(snapshot.overallStatus, AgentExecutionOverallStatus.attention);
    expect(snapshot.items.single.kind, AgentExecutionStatusKind.failed);
  });

  test('counts all visible tasks instead of truncating the aggregate', () {
    final database = WideNoteLocalDatabase.inMemory();
    final now = DateTime.utc(2026, 7, 3, 12);
    final container = ProviderContainer(
      overrides: [
        localDatabaseProvider.overrideWithValue(database),
        agentExecutionStatusNowProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);

    for (var index = 0; index < 25; index += 1) {
      _insertTask(
        database,
        _task(
          'task-running-$index',
          status: 'running',
          leasedUntil: now.add(const Duration(minutes: 5)),
          updatedAt: now.subtract(Duration(seconds: index)),
        ),
      );
    }

    final snapshot = container.read(agentExecutionStatusControllerProvider);

    expect(snapshot.runningCount, 25);
    expect(snapshot.activeCount, 25);
    expect(snapshot.items, hasLength(25));
  });

  test(
    'platform sync dedupes repeated payloads and handles platform failures',
    () async {
      final client = _RecordingPlatformClient(
        result: const AgentStatusPlatformResult(
          notificationStatus: 'scheduled',
          liveActivityStatus: 'started',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          agentStatusPlatformClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);

      final snapshot = AgentExecutionStatusSnapshot(
        generatedAt: DateTime.utc(2026, 7, 3, 12),
        items: [
          AgentExecutionStatusItem(
            id: 'task-running',
            taskId: 'task-running',
            packId: 'pack.default',
            agentId: 'agent.capture_loop',
            status: 'running',
            kind: AgentExecutionStatusKind.running,
            attempts: 1,
            maxAttempts: 2,
            createdAt: DateTime.utc(2026, 7, 3, 11, 59),
            updatedAt: DateTime.utc(2026, 7, 3, 12),
            missingDependencyCount: 0,
            hasError: false,
          ),
        ],
      );
      const labels = AgentStatusPlatformLabels(
        title: 'Agents are working',
        body: '1 running / 0 queued / 0 retrying / 0 need attention',
      );

      final sync = container.read(
        agentStatusPlatformSyncControllerProvider.notifier,
      );
      await sync.sync(snapshot, labels);
      await sync.sync(snapshot, labels);

      expect(client.payloads, hasLength(1));
      expect(
        container.read(agentStatusPlatformSyncControllerProvider).status,
        AgentStatusPlatformSyncStatus.synced,
      );

      final failing = _RecordingPlatformClient(
        exception: MissingPluginException(),
      );
      final failingContainer = ProviderContainer(
        overrides: [
          agentStatusPlatformClientProvider.overrideWithValue(failing),
        ],
      );
      addTearDown(failingContainer.dispose);

      await failingContainer
          .read(agentStatusPlatformSyncControllerProvider.notifier)
          .sync(snapshot, labels);

      expect(
        failingContainer.read(agentStatusPlatformSyncControllerProvider).status,
        AgentStatusPlatformSyncStatus.unsupported,
      );

      final nativeFailing = _RecordingPlatformClient(
        result: const AgentStatusPlatformResult(
          notificationStatus: 'scheduled',
          liveActivityStatus: 'failed',
        ),
      );
      final nativeFailingContainer = ProviderContainer(
        overrides: [
          agentStatusPlatformClientProvider.overrideWithValue(nativeFailing),
        ],
      );
      addTearDown(nativeFailingContainer.dispose);
      final nativeFailingSync = nativeFailingContainer.read(
        agentStatusPlatformSyncControllerProvider.notifier,
      );

      await nativeFailingSync.sync(snapshot, labels);
      await nativeFailingSync.sync(snapshot, labels);

      expect(nativeFailing.payloads, hasLength(2));
      expect(
        nativeFailingContainer
            .read(agentStatusPlatformSyncControllerProvider)
            .status,
        AgentStatusPlatformSyncStatus.failed,
      );

      final transientFailing = _RecordingPlatformClient(
        exception: PlatformException(code: 'transient'),
      );
      final transientFailingContainer = ProviderContainer(
        overrides: [
          agentStatusPlatformClientProvider.overrideWithValue(transientFailing),
        ],
      );
      addTearDown(transientFailingContainer.dispose);
      final transientFailingSync = transientFailingContainer.read(
        agentStatusPlatformSyncControllerProvider.notifier,
      );

      await transientFailingSync.sync(snapshot, labels);
      await transientFailingSync.sync(snapshot, labels);

      expect(transientFailing.payloads, hasLength(2));
      expect(
        transientFailingContainer
            .read(agentStatusPlatformSyncControllerProvider)
            .status,
        AgentStatusPlatformSyncStatus.failed,
      );
    },
  );
}

RuntimeTaskRecord _task(
  String id, {
  required String status,
  DateTime? updatedAt,
  DateTime? leasedUntil,
  DateTime? scheduledAt,
  int attempts = 0,
  int maxAttempts = 2,
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
    maxAttempts: maxAttempts,
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

final class _RecordingPlatformClient implements AgentStatusPlatformClient {
  _RecordingPlatformClient({this.result, this.exception});

  final AgentStatusPlatformResult? result;
  final Object? exception;
  final List<AgentStatusPlatformPayload> payloads = [];

  @override
  Future<AgentStatusPlatformResult> sync(
    AgentStatusPlatformPayload payload,
  ) async {
    payloads.add(payload);
    final exception = this.exception;
    if (exception != null) {
      throw exception;
    }
    return result ?? const AgentStatusPlatformResult();
  }
}
