import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'package:widenote_agent_runtime/src/approval.dart' as runtime;
import 'package:widenote_agent_runtime/src/event.dart' as runtime;
import 'package:widenote_agent_runtime/src/kernel.dart' as runtime;
import 'package:widenote_agent_runtime/src/model.dart' as runtime;
import 'package:widenote_agent_runtime/src/pack.dart' as runtime;
import 'package:widenote_agent_runtime/src/permissions.dart' as runtime;
import 'package:widenote_agent_runtime/src/run_mode.dart' as runtime;
import 'package:widenote_agent_runtime/src/task.dart' as runtime;
import 'package:widenote_agent_runtime/src/tools.dart' as runtime;
import 'package:widenote_core/widenote_core.dart';
import 'package:widenote_local_db/widenote_local_db.dart';

void main() {
  group('LocalDbRuntimeStore', () {
    late WideNoteLocalDatabase database;
    late LocalDbRuntimeStore store;

    setUp(() {
      database = WideNoteLocalDatabase.inMemory();
      store = LocalDbRuntimeStore(database);
    });

    tearDown(() {
      database.close();
    });

    test(
      'round-trips tasks, runs, and pack status with metadata intact',
      () async {
        final createdAt = DateTime.utc(2026, 6, 26, 8);
        final updatedAt = DateTime.utc(2026, 6, 26, 8, 5);
        final completedAt = DateTime.utc(2026, 6, 26, 8, 10);
        final leaseExpiresAt = DateTime.utc(2026, 6, 26, 8, 15);
        _seedEvent(database, id: 'event-round-trip', createdAt: createdAt);
        _seedPackInstallation(
          database,
          packId: 'pack.adapter',
          name: 'Installed Pack',
          version: '9.9.9',
          status: 'disabled',
          runtimeStatus: 'idle',
          requestedPermissions: const <Object?>['memory.propose'],
          enabledSubscriptionIds: const <Object?>['sub.keep'],
          manifest: const <String, Object?>{
            'id': 'pack.adapter',
            'source': 'installed-manifest',
          },
          payload: const <String, Object?>{'install_note': 'keep-me'},
          createdAt: createdAt,
        );

        final task = runtime.RuntimeTask(
          id: 'task-round-trip',
          identityKey:
              'event-round-trip::pack.adapter::0.1.0::sub.main::agent.main',
          packId: 'pack.adapter',
          packVersion: '0.1.0',
          agentId: 'agent.main',
          handlerRole: 'handler.role',
          subscriptionId: 'sub.main',
          triggerEventId: 'event-round-trip',
          status: runtime.RuntimeTaskStatus.waiting,
          dependencyTaskIds: const <String>['task-before'],
          missingDependencyIds: const <String>['sub.missing'],
          attempts: 2,
          maxAttempts: 4,
          error: 'waiting for dependency',
          createdAt: createdAt,
          updatedAt: updatedAt,
        );
        await store.upsertTask(task);
        final run = runtime.RuntimeRun(
          id: 'run-round-trip',
          taskId: task.id,
          packId: task.packId,
          packVersion: task.packVersion,
          agentId: task.agentId,
          status: runtime.RuntimeRunStatus.failed,
          startedAt: createdAt,
          attempt: 2,
          runMode: runtime.RunMode.confirm,
          completedAt: completedAt,
          leaseExpiresAt: leaseExpiresAt,
          outputEventIds: const <String>['event-output-1', 'event-output-2'],
          error: 'handler failed',
        );
        await store.upsertRun(run);
        await store.upsertPackStatus(
          const runtime.RuntimePackStatus(
            packId: 'pack.adapter',
            version: '0.1.0',
            name: 'Runtime Pack Name',
            status: runtime.RuntimePackStatusKind.running,
            taskCount: 7,
            queuedCount: 1,
            runningCount: 2,
            succeededCount: 3,
            failedCount: 4,
            deniedCount: 5,
            canceledCount: 6,
            blockedCount: 7,
          ),
        );
        await store.upsertPackStatus(
          const runtime.RuntimePackStatus(
            packId: 'pack.generated',
            version: '1.2.3',
            name: 'Generated Runtime Pack',
            status: runtime.RuntimePackStatusKind.idle,
            taskCount: 0,
            queuedCount: 0,
            runningCount: 0,
            succeededCount: 0,
            failedCount: 0,
            deniedCount: 0,
            canceledCount: 0,
            blockedCount: 0,
          ),
        );

        final readTask = await store.readTaskById(task.id);
        expect(readTask, isNotNull);
        expect(readTask!.id, task.id);
        expect(readTask.identityKey, task.identityKey);
        expect(readTask.packId, task.packId);
        expect(readTask.packVersion, task.packVersion);
        expect(readTask.agentId, task.agentId);
        expect(readTask.handlerRole, task.handlerRole);
        expect(readTask.subscriptionId, task.subscriptionId);
        expect(readTask.triggerEventId, task.triggerEventId);
        expect(readTask.status, task.status);
        expect(readTask.dependencyTaskIds, task.dependencyTaskIds);
        expect(readTask.missingDependencyIds, task.missingDependencyIds);
        expect(readTask.attempts, task.attempts);
        expect(readTask.maxAttempts, task.maxAttempts);
        expect(readTask.error, task.error);
        expect(readTask.createdAt, task.createdAt);
        expect(readTask.updatedAt, task.updatedAt);

        final readRun = await store.readRunById(run.id);
        expect(readRun, isNotNull);
        expect(readRun!.id, run.id);
        expect(readRun.taskId, run.taskId);
        expect(readRun.packId, run.packId);
        expect(readRun.packVersion, run.packVersion);
        expect(readRun.agentId, run.agentId);
        expect(readRun.status, run.status);
        expect(readRun.startedAt, run.startedAt);
        expect(readRun.attempt, run.attempt);
        expect(readRun.runMode, run.runMode);
        expect(readRun.completedAt, run.completedAt);
        expect(readRun.leaseExpiresAt, leaseExpiresAt);
        expect(readRun.outputEventIds, run.outputEventIds);
        expect(readRun.error, run.error);
        final persistedRun = database.runtimeRuns.readById(run.id)!;
        expect(persistedRun.payload['runtime_run_mode'], 'confirm');

        final installation = database.packInstallations.readById(
          'pack.adapter',
        )!;
        expect(installation.name, 'Installed Pack');
        expect(installation.version, '9.9.9');
        expect(installation.publisher, 'widenote');
        expect(installation.edition, 'official');
        expect(installation.status, 'disabled');
        expect(installation.runtimeStatus, 'running');
        expect(installation.requestedPermissions, ['memory.propose']);
        expect(installation.enabledSubscriptionIds, ['sub.keep']);
        expect(installation.manifest['source'], 'installed-manifest');
        expect(installation.payload['install_note'], 'keep-me');

        final readPackStatus = await store.readPackStatus('pack.adapter');
        expect(readPackStatus, isNotNull);
        expect(readPackStatus!.name, 'Installed Pack');
        expect(readPackStatus.version, '9.9.9');
        expect(readPackStatus.status, runtime.RuntimePackStatusKind.running);
        expect(readPackStatus.taskCount, 7);
        expect(readPackStatus.queuedCount, 1);
        expect(readPackStatus.runningCount, 2);
        expect(readPackStatus.succeededCount, 3);
        expect(readPackStatus.failedCount, 4);
        expect(readPackStatus.deniedCount, 5);
        expect(readPackStatus.canceledCount, 6);
        expect(readPackStatus.blockedCount, 7);

        final generated = database.packInstallations.readById(
          'pack.generated',
        )!;
        expect(generated.publisher, 'runtime');
        expect(generated.edition, 'runtime');
        expect(generated.status, 'enabled');
        expect(generated.runtimeStatus, 'idle');
        expect(generated.manifest['id'], 'pack.generated');
        expect((await store.readPackStatus('missing-pack')), isNull);
        expect(
          (await store.readPackStatuses()).map((status) => status.packId),
          containsAll(<String>['pack.adapter', 'pack.generated']),
        );
      },
    );

    test('filters tasks and runs by pack and task in stable order', () async {
      final createdAt = DateTime.utc(2026, 6, 26, 9);
      for (var index = 0; index < 4; index += 1) {
        _seedEvent(
          database,
          id: 'event-filter-$index',
          createdAt: createdAt.add(Duration(minutes: index)),
        );
      }

      await store.upsertTask(
        _task(
          id: 'task-alpha-1',
          identityKey: 'identity-alpha-1',
          packId: 'pack.alpha',
          triggerEventId: 'event-filter-0',
          createdAt: createdAt,
        ),
      );
      await store.upsertTask(
        _task(
          id: 'task-beta-1',
          identityKey: 'identity-beta-1',
          packId: 'pack.beta',
          triggerEventId: 'event-filter-1',
          createdAt: createdAt.add(const Duration(minutes: 1)),
        ),
      );
      await store.upsertTask(
        _task(
          id: 'task-alpha-2',
          identityKey: 'identity-alpha-2',
          packId: 'pack.alpha',
          triggerEventId: 'event-filter-2',
          createdAt: createdAt.add(const Duration(minutes: 2)),
        ),
      );
      await store.upsertRun(
        _run(
          id: 'run-alpha-1a',
          taskId: 'task-alpha-1',
          packId: 'pack.alpha',
          startedAt: createdAt,
        ),
      );
      await store.upsertRun(
        _run(
          id: 'run-beta-1',
          taskId: 'task-beta-1',
          packId: 'pack.beta',
          startedAt: createdAt.add(const Duration(minutes: 1)),
        ),
      );
      await store.upsertRun(
        _run(
          id: 'run-alpha-1b',
          taskId: 'task-alpha-1',
          packId: 'pack.alpha',
          startedAt: createdAt.add(const Duration(minutes: 2)),
        ),
      );
      await store.upsertRun(
        _run(
          id: 'run-alpha-2',
          taskId: 'task-alpha-2',
          packId: 'pack.alpha',
          startedAt: createdAt.add(const Duration(minutes: 3)),
        ),
      );

      expect((await store.readTasks()).map((task) => task.id), [
        'task-alpha-1',
        'task-beta-1',
        'task-alpha-2',
      ]);
      expect(
        (await store.readTasks(packId: 'pack.alpha')).map((task) => task.id),
        ['task-alpha-1', 'task-alpha-2'],
      );
      expect(
        (await store.readRuns(taskId: 'task-alpha-1')).map((run) => run.id),
        ['run-alpha-1a', 'run-alpha-1b'],
      );
      expect(
        (await store.readRuns(packId: 'pack.alpha')).map((run) => run.id),
        ['run-alpha-1a', 'run-alpha-1b', 'run-alpha-2'],
      );
      expect(
        (await store.readRuns(taskId: 'task-alpha-1', packId: 'pack.beta')),
        isEmpty,
      );
      expect((await store.readTaskById('missing-task')), isNull);
      expect((await store.readRunById('missing-run')), isNull);
      expect((await store.readTasks(packId: 'pack.missing')), isEmpty);
    });

    test('upserts duplicate identity without duplicating tasks', () async {
      final createdAt = DateTime.utc(2026, 6, 26, 10);
      _seedEvent(database, id: 'event-duplicate', createdAt: createdAt);
      const identity = 'event-duplicate::pack.dup::0.1.0::sub.dup::agent.dup';
      await store.upsertTask(
        _task(
          id: 'task-original',
          identityKey: identity,
          packId: 'pack.dup',
          triggerEventId: 'event-duplicate',
          createdAt: createdAt,
        ),
      );

      await store.upsertTask(
        _task(
          id: 'task-new-id-same-identity',
          identityKey: identity,
          packId: 'pack.dup',
          triggerEventId: 'event-duplicate',
          status: runtime.RuntimeTaskStatus.failed,
          error: 'same identity replacement',
          createdAt: createdAt.add(const Duration(minutes: 1)),
        ),
      );

      final tasks = await store.readTasks(packId: 'pack.dup');
      expect(tasks, hasLength(1));
      expect(tasks.single.id, 'task-original');
      expect(tasks.single.identityKey, identity);
      expect(tasks.single.status, runtime.RuntimeTaskStatus.failed);
      expect(tasks.single.error, 'same identity replacement');
    });

    test('defensively rejects malformed status, list, and lease rows', () async {
      final createdAt = DateTime.utc(2026, 6, 26, 11);
      for (final id in <String>[
        'event-task-status',
        'event-task-list',
        'event-run-status',
        'event-run-output',
        'event-run-lease',
      ]) {
        _seedEvent(database, id: id, createdAt: createdAt);
      }
      _seedPackInstallation(database, packId: 'pack.malformed');
      await store.upsertTask(
        _task(
          id: 'task-bad-status',
          identityKey: 'identity-bad-status',
          packId: 'pack.malformed',
          triggerEventId: 'event-task-status',
          createdAt: createdAt,
        ),
      );
      await store.upsertTask(
        _task(
          id: 'task-bad-list',
          identityKey: 'identity-bad-list',
          packId: 'pack.malformed',
          triggerEventId: 'event-task-list',
          createdAt: createdAt,
        ),
      );
      await store.upsertTask(
        _task(
          id: 'task-run-status',
          identityKey: 'identity-run-status',
          packId: 'pack.malformed',
          triggerEventId: 'event-run-status',
          createdAt: createdAt,
        ),
      );
      await store.upsertTask(
        _task(
          id: 'task-run-output',
          identityKey: 'identity-run-output',
          packId: 'pack.malformed',
          triggerEventId: 'event-run-output',
          createdAt: createdAt,
        ),
      );
      await store.upsertTask(
        _task(
          id: 'task-run-lease',
          identityKey: 'identity-run-lease',
          packId: 'pack.malformed',
          triggerEventId: 'event-run-lease',
          createdAt: createdAt,
        ),
      );
      await store.upsertRun(
        _run(
          id: 'run-bad-status',
          taskId: 'task-run-status',
          packId: 'pack.malformed',
          startedAt: createdAt,
        ),
      );
      await store.upsertRun(
        _run(
          id: 'run-bad-output',
          taskId: 'task-run-output',
          packId: 'pack.malformed',
          startedAt: createdAt,
        ),
      );
      await store.upsertRun(
        _run(
          id: 'run-bad-lease',
          taskId: 'task-run-lease',
          packId: 'pack.malformed',
          leaseExpiresAt: createdAt.add(const Duration(minutes: 5)),
          startedAt: createdAt,
        ),
      );
      database.permissionGrants.insert(
        PermissionGrantRecord(
          id: 'permission-bad-status',
          packId: 'pack.malformed',
          permissionId: 'memory.propose',
          status: 'mystery',
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );

      database.rawDatabase
        ..execute(
          "UPDATE runtime_tasks SET status = 'mystery' "
          "WHERE id = 'task-bad-status';",
        )
        ..execute(
          "UPDATE runtime_tasks SET dependency_task_ids_json = '[\"ok\", 42]' "
          "WHERE id = 'task-bad-list';",
        )
        ..execute(
          "UPDATE runtime_runs SET status = 'mystery' "
          "WHERE id = 'run-bad-status';",
        )
        ..execute(
          "UPDATE runtime_runs SET output_event_ids_json = '[\"ok\", 42]' "
          "WHERE id = 'run-bad-output';",
        )
        ..execute('''
UPDATE runtime_runs
SET payload_json = '{"runtime_run_lease_expires_at":"not-a-date"}'
WHERE id = 'run-bad-lease';
''')
        ..execute(
          "UPDATE pack_installations SET runtime_status = 'mystery' "
          "WHERE pack_id = 'pack.malformed';",
        );

      expect(
        () => store.readTaskById('task-bad-status'),
        throwsA(isA<StateError>()),
      );
      expect(
        () => store.readTaskById('task-bad-list'),
        throwsA(isA<StateError>()),
      );
      expect(
        () => store.readRunById('run-bad-status'),
        throwsA(isA<StateError>()),
      );
      expect(
        () => store.readRunById('run-bad-output'),
        throwsA(isA<StateError>()),
      );
      expect(
        () => store.readRunById('run-bad-lease'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => store.readPackStatus('pack.malformed'),
        throwsA(isA<StateError>()),
      );
      expect(
        () => LocalDbPermissionStore(
          database,
        ).read('pack.malformed', 'memory.propose'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('LocalDbPermissionStore', () {
    late WideNoteLocalDatabase database;
    late LocalDbPermissionStore store;
    late runtime.InMemoryPermissionBroker broker;

    setUp(() {
      database = WideNoteLocalDatabase.inMemory();
      store = LocalDbPermissionStore(database);
      broker = runtime.InMemoryPermissionBroker(store: store);
      _seedPackInstallation(database, packId: 'pack.permission');
    });

    tearDown(() {
      database.close();
    });

    test('round-trips grant, deny, grant, and revoke transitions', () async {
      final grantedAt = DateTime.utc(2026, 6, 26, 12);
      final deniedAt = DateTime.utc(2026, 6, 26, 12, 1);
      final regrantedAt = DateTime.utc(2026, 6, 26, 12, 2);
      final revokedAt = DateTime.utc(2026, 6, 26, 12, 3);

      expect(await store.read('pack.permission', 'memory.propose'), isNull);
      expect(
        await broker.isGranted('pack.permission', 'memory.propose'),
        isFalse,
      );

      await store.upsert(
        runtime.PermissionDecision(
          packId: 'pack.permission',
          permission: 'memory.propose',
          state: runtime.PermissionDecisionState.granted,
          updatedAt: grantedAt,
        ),
      );
      var decision = await store.read('pack.permission', 'memory.propose');
      expect(decision!.state, runtime.PermissionDecisionState.granted);
      expect(decision.updatedAt, grantedAt);
      expect(decision.reason, isNull);
      expect(
        await broker.isGranted('pack.permission', 'memory.propose'),
        isTrue,
      );
      expect(
        database.permissionGrants
            .readByPackAndPermission('pack.permission', 'memory.propose')!
            .grantedAt,
        grantedAt,
      );

      await store.upsert(
        runtime.PermissionDecision(
          packId: 'pack.permission',
          permission: 'memory.propose',
          state: runtime.PermissionDecisionState.denied,
          updatedAt: deniedAt,
          reason: 'user denied',
        ),
      );
      decision = await store.read('pack.permission', 'memory.propose');
      expect(decision!.state, runtime.PermissionDecisionState.denied);
      expect(decision.updatedAt, deniedAt);
      expect(decision.reason, 'user denied');
      expect(
        await broker.isGranted('pack.permission', 'memory.propose'),
        isFalse,
      );
      var record = database.permissionGrants.readByPackAndPermission(
        'pack.permission',
        'memory.propose',
      )!;
      expect(record.grantedAt, isNull);
      expect(record.revokedAt, isNull);

      await store.upsert(
        runtime.PermissionDecision(
          packId: 'pack.permission',
          permission: 'memory.propose',
          state: runtime.PermissionDecisionState.granted,
          updatedAt: regrantedAt,
        ),
      );
      decision = await store.read('pack.permission', 'memory.propose');
      expect(decision!.state, runtime.PermissionDecisionState.granted);
      expect(decision.updatedAt, regrantedAt);
      expect(decision.reason, isNull);
      expect(
        await broker.isGranted('pack.permission', 'memory.propose'),
        isTrue,
      );
      record = database.permissionGrants.readByPackAndPermission(
        'pack.permission',
        'memory.propose',
      )!;
      expect(record.reason, isNull);
      expect(record.revokedAt, isNull);
      expect(record.grantedAt, regrantedAt);

      await store.upsert(
        runtime.PermissionDecision(
          packId: 'pack.permission',
          permission: 'memory.propose',
          state: runtime.PermissionDecisionState.revoked,
          updatedAt: revokedAt,
          reason: 'user revoked',
        ),
      );
      decision = await store.read('pack.permission', 'memory.propose');
      expect(decision!.state, runtime.PermissionDecisionState.revoked);
      expect(decision.updatedAt, revokedAt);
      expect(decision.reason, 'user revoked');
      expect(
        await broker.isGranted('pack.permission', 'memory.propose'),
        isFalse,
      );
      expect(
        (await store.readForPack(
          'pack.permission',
        )).map((decision) => decision.permission),
        ['memory.propose'],
      );
      record = database.permissionGrants.readByPackAndPermission(
        'pack.permission',
        'memory.propose',
      )!;
      expect(record.grantedAt, regrantedAt);
      expect(record.revokedAt, revokedAt);
    });

    test('uses pack foreign key and fails clearly for missing packs', () {
      expect(
        () => store.upsert(
          runtime.PermissionDecision(
            packId: 'pack.missing',
            permission: 'memory.propose',
            state: runtime.PermissionDecisionState.granted,
            updatedAt: DateTime.utc(2026, 6, 26, 12),
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
      expect(database.permissionGrants.readAll(), isEmpty);
    });
  });

  group('LocalDbApprovalStore', () {
    late WideNoteLocalDatabase database;
    late LocalDbApprovalStore store;
    late DateTime createdAt;

    setUp(() {
      database = WideNoteLocalDatabase.inMemory();
      store = LocalDbApprovalStore(database);
      createdAt = DateTime.utc(2026, 6, 26, 12);
      _seedApprovalRuntime(database, createdAt: createdAt);
    });

    tearDown(() {
      database.close();
    });

    test(
      'stores and reads pending approval requests without raw input',
      () async {
        final request = runtime.ApprovalRequest(
          id: 'approval-1',
          packId: 'pack.approval',
          agentId: 'agent.adapter',
          taskId: 'task-approval',
          runId: 'run-approval',
          toolName: 'memory.propose',
          runMode: runtime.RunMode.readOnly,
          toolAccess: runtime.ToolAccess.write,
          toolRisk: runtime.ToolRisk.high,
          isExternal: false,
          requiredPermissions: const <String>['memory.propose'],
          inputKeys: const <String>['body', 'api_key', 'source_refs'],
          sourceRefs: const <Object?>[
            <String, Object?>{'kind': 'event', 'id': 'event-approval'},
          ],
          actionSummary: 'Approve one memory.propose tool invocation.',
          createdAt: createdAt,
          expiresAt: createdAt.add(const Duration(minutes: 15)),
          reason: 'write tool requires approval',
        );

        await store.saveRequest(request);

        final record = database.runtimeApprovals.readById('approval-1')!;
        expect(record.runMode, 'read_only');
        expect(record.toolAccess, 'write');
        expect(record.toolRisk, 'high');
        expect(record.requiredPermissions, <Object?>['memory.propose']);
        expect(record.inputKeys, <Object?>['body', 'api_key', 'source_refs']);
        expect(record.sourceRefs, request.sourceRefs);
        expect(record.status, 'pending');
        expect(record.decision, isNull);
        expect(record.reason, 'write tool requires approval');

        final pending = await store.readPending(
          now: createdAt.add(const Duration(minutes: 1)),
        );
        expect(pending, hasLength(1));
        expect(pending.single.runMode, runtime.RunMode.readOnly);
        expect(pending.single.toolRisk, runtime.ToolRisk.high);
        expect(pending.single.inputKeys, request.inputKeys);
        expect(pending.single.sourceRefs, request.sourceRefs);
        expect(
          await store.readPending(
            now: createdAt.add(const Duration(minutes: 16)),
          ),
          isEmpty,
        );

        final raw = database.rawDatabase
            .select(
              'SELECT * FROM runtime_approval_requests WHERE id = ?;',
              <Object?>['approval-1'],
            )
            .single
            .values
            .join(' ');
        expect(raw, isNot(contains('private-tool-input')));
        expect(raw, isNot(contains('sk-secret')));
      },
    );

    test('persists approve-once and deny decisions', () async {
      await store.saveRequest(
        _approvalRequest(id: 'approval-approve', createdAt: createdAt),
      );
      await store.saveDecision(
        runtime.ApprovalDecision.approved(
          requestId: 'approval-approve',
          decidedAt: createdAt.add(const Duration(minutes: 1)),
          reason: 'looks safe',
        ),
      );

      final approved = database.runtimeApprovals.readById('approval-approve')!;
      expect(approved.status, 'approved');
      expect(approved.decision, 'approve_once');
      expect(approved.reason, 'looks safe');
      expect(
        (await store.readDecision('approval-approve'))!.state,
        runtime.ApprovalDecisionState.approved,
      );

      await store.saveRequest(
        _approvalRequest(id: 'approval-deny', createdAt: createdAt),
      );
      await store.saveDecision(
        runtime.ApprovalDecision.denied(
          requestId: 'approval-deny',
          decidedAt: createdAt.add(const Duration(minutes: 2)),
          reason: 'too broad',
        ),
      );

      final denied = database.runtimeApprovals.readById('approval-deny')!;
      expect(denied.status, 'denied');
      expect(denied.decision, 'deny');
      expect(denied.reason, 'too broad');
      expect(await store.readPending(), isEmpty);
    });

    test('record layer supports canceled and expired approval states', () {
      database.runtimeApprovals.insert(
        _approvalRecord(id: 'approval-cancel', createdAt: createdAt),
      );
      database.runtimeApprovals.insert(
        _approvalRecord(id: 'approval-expire', createdAt: createdAt),
      );

      final canceled = database.runtimeApprovals.cancel(
        'approval-cancel',
        reason: 'user dismissed',
        decidedAt: createdAt.add(const Duration(minutes: 1)),
      );
      final expired = database.runtimeApprovals.expire(
        'approval-expire',
        reason: 'approval ttl elapsed',
        decidedAt: createdAt.add(const Duration(minutes: 16)),
      );

      expect(canceled.status, 'canceled');
      expect(canceled.decision, 'cancel');
      expect(expired.status, 'expired');
      expect(expired.decision, 'expire');
      expect(database.runtimeApprovals.readPending(now: createdAt), isEmpty);
    });
  });

  group('RuntimeKernel with local_db stores', () {
    test('restores queued work from local_db and drains once', () async {
      final database = WideNoteLocalDatabase.inMemory();
      addTearDown(database.close);
      _seedPackInstallation(database, packId: 'pack.restart');
      final permissionStore = LocalDbPermissionStore(database);
      await permissionStore.upsert(
        runtime.PermissionDecision(
          packId: 'pack.restart',
          permission: 'memory.propose',
          state: runtime.PermissionDecisionState.granted,
          updatedAt: DateTime.utc(2026, 6, 26, 13),
        ),
      );
      final pack = _insightPack(id: 'pack.restart');
      final firstKernel = _kernel(
        database,
        permissionStore: permissionStore,
        idGenerator: SequenceWnIdGenerator(seed: 'restart'),
        autoDrain: false,
      )..registerPack(pack);

      await firstKernel.publish(
        const runtime.WnEventDraft(
          type: runtime.WnEventTypes.captureCreated,
          actor: runtime.WnActor.user,
          payload: <String, Object?>{'text': 'survive local db restart'},
        ),
      );
      expect(
        (await LocalDbRuntimeStore(database).readTasks()).single.status,
        runtime.RuntimeTaskStatus.queued,
      );

      final restartedKernel = _kernel(
        database,
        permissionStore: permissionStore,
        idGenerator: SequenceWnIdGenerator(seed: 'restart', startAt: 100),
      )..registerPack(pack);
      await restartedKernel.restoreRuntimeState();

      expect(await restartedKernel.drainQueue(), 1);
      expect(await restartedKernel.drainQueue(), 0);
      expect(
        (await LocalDbEventStore(
          database,
        ).readAll()).map((event) => event.type),
        [
          runtime.WnEventTypes.captureCreated,
          runtime.WnEventTypes.insightCreated,
        ],
      );
      expect(
        (await LocalDbRuntimeStore(database).readTasks()).single.status,
        runtime.RuntimeTaskStatus.succeeded,
      );
    });

    test(
      'persists lease across reopen and retries stale running runs',
      () async {
        final directory = Directory.systemTemp.createTempSync(
          'widenote_runtime_adapter_',
        );
        addTearDown(() {
          if (directory.existsSync()) {
            directory.deleteSync(recursive: true);
          }
        });
        final path = '${directory.path}${Platform.pathSeparator}runtime.sqlite';
        final startedAt = DateTime.utc(2026, 6, 26, 13);
        final leaseExpiresAt = DateTime.utc(2026, 6, 26, 13, 5);
        final recoveryClock = DateTime.utc(2026, 6, 26, 13, 10);

        final first = WideNoteLocalDatabase.openPath(path);
        _seedEvent(first, id: 'event-stale', createdAt: startedAt);
        _seedPackInstallation(
          first,
          packId: 'pack.stale',
          createdAt: startedAt,
        );
        final firstStore = LocalDbRuntimeStore(first);
        await firstStore.upsertTask(
          _task(
            id: 'task-stale',
            identityKey: 'identity-stale',
            packId: 'pack.stale',
            triggerEventId: 'event-stale',
            status: runtime.RuntimeTaskStatus.running,
            attempts: 1,
            maxAttempts: 2,
            createdAt: startedAt,
          ),
        );
        await firstStore.upsertRun(
          _run(
            id: 'run-stale',
            taskId: 'task-stale',
            packId: 'pack.stale',
            status: runtime.RuntimeRunStatus.running,
            leaseExpiresAt: leaseExpiresAt,
            startedAt: startedAt,
          ),
        );
        first.close();

        final reopened = WideNoteLocalDatabase.openPath(path);
        addTearDown(reopened.close);
        final reopenedStore = LocalDbRuntimeStore(reopened);
        expect(
          (await reopenedStore.readRunById('run-stale'))!.leaseExpiresAt,
          leaseExpiresAt,
        );

        final kernel = _kernel(
          reopened,
          clock: FixedWnClock(recoveryClock),
          idGenerator: SequenceWnIdGenerator(seed: 'stale'),
        )..registerPack(_emptyPack(id: 'pack.stale'));
        await kernel.restoreRuntimeState();

        final recoveredTask = (await reopenedStore.readTaskById('task-stale'))!;
        expect(recoveredTask.status, runtime.RuntimeTaskStatus.queued);
        expect(recoveredTask.attempts, 1);
        expect(recoveredTask.leaseOwner, isNull);
        expect(recoveredTask.leasedUntil, isNull);
        expect(recoveredTask.error, contains('lease expired'));
        final recoveredRun = (await reopenedStore.readRunById('run-stale'))!;
        expect(recoveredRun.status, runtime.RuntimeRunStatus.failed);
        expect(recoveredRun.leaseExpiresAt, leaseExpiresAt);
        expect(recoveredRun.error, contains('lease expired'));
      },
    );

    test('restores dependency failure into blocked state', () async {
      final database = WideNoteLocalDatabase.inMemory();
      addTearDown(database.close);
      final createdAt = DateTime.utc(2026, 6, 26, 14);
      _seedEvent(database, id: 'event-dependency', createdAt: createdAt);
      final store = LocalDbRuntimeStore(database);
      await store.upsertTask(
        _task(
          id: 'task-dependency',
          identityKey: 'identity-dependency',
          packId: 'pack.dependency',
          triggerEventId: 'event-dependency',
          status: runtime.RuntimeTaskStatus.failed,
          error: 'dependency failed',
          createdAt: createdAt,
        ),
      );
      await store.upsertTask(
        _task(
          id: 'task-dependent',
          identityKey: 'identity-dependent',
          packId: 'pack.dependency',
          triggerEventId: 'event-dependency',
          status: runtime.RuntimeTaskStatus.waiting,
          dependencyTaskIds: const <String>['task-dependency'],
          createdAt: createdAt.add(const Duration(milliseconds: 1)),
        ),
      );

      final kernel = _kernel(database)
        ..registerPack(_emptyPack(id: 'pack.dependency'));
      await kernel.restoreRuntimeState();
      expect(await kernel.drainQueue(), 0);

      final dependent = (await store.readTaskById('task-dependent'))!;
      expect(dependent.status, runtime.RuntimeTaskStatus.blocked);
      expect(dependent.error, contains('Dependency did not succeed'));
    });

    test(
      'local_db permissions gate queued and future tasks after revoke',
      () async {
        final database = WideNoteLocalDatabase.inMemory();
        addTearDown(database.close);
        _seedPackInstallation(database, packId: 'pack.revoke');
        final permissionStore = LocalDbPermissionStore(database);
        await permissionStore.upsert(
          runtime.PermissionDecision(
            packId: 'pack.revoke',
            permission: 'memory.propose',
            state: runtime.PermissionDecisionState.granted,
            updatedAt: DateTime.utc(2026, 6, 26, 15),
          ),
        );
        final pack = _insightPack(id: 'pack.revoke');
        final firstKernel = _kernel(
          database,
          permissionStore: permissionStore,
          idGenerator: SequenceWnIdGenerator(seed: 'revoke'),
          autoDrain: false,
        )..registerPack(pack);

        await firstKernel.publish(
          const runtime.WnEventDraft(
            type: runtime.WnEventTypes.captureCreated,
            actor: runtime.WnActor.user,
          ),
        );
        expect(
          firstKernel.tasks.single.status,
          runtime.RuntimeTaskStatus.queued,
        );

        await permissionStore.upsert(
          runtime.PermissionDecision(
            packId: 'pack.revoke',
            permission: 'memory.propose',
            state: runtime.PermissionDecisionState.revoked,
            updatedAt: DateTime.utc(2026, 6, 26, 15, 1),
            reason: 'user revoked',
          ),
        );
        final revokeResult = await firstKernel.handlePermissionRevoked(
          'pack.revoke',
          'memory.propose',
        );
        expect(revokeResult.affectedTaskIds, [firstKernel.tasks.single.id]);
        expect(
          (await LocalDbRuntimeStore(
            database,
          ).readTaskById(firstKernel.tasks.single.id))!.status,
          runtime.RuntimeTaskStatus.denied,
        );

        final restartedKernel = _kernel(
          database,
          permissionStore: permissionStore,
          idGenerator: SequenceWnIdGenerator(seed: 'revoke', startAt: 100),
          autoDrain: false,
        )..registerPack(pack);
        await restartedKernel.restoreRuntimeState(terminateStaleRuns: false);
        await restartedKernel.publish(
          const runtime.WnEventDraft(
            type: runtime.WnEventTypes.captureCreated,
            actor: runtime.WnActor.user,
          ),
        );

        expect(
          restartedKernel.tasks.last.status,
          runtime.RuntimeTaskStatus.blocked,
        );
        expect(
          restartedKernel.tasks.last.error,
          contains('Permission revoked'),
        );
        expect(await restartedKernel.drainQueue(), 0);
      },
    );

    test(
      'pending approval broker records request and fails run before tool executes',
      () async {
        final database = WideNoteLocalDatabase.inMemory();
        addTearDown(database.close);
        var toolCalls = 0;
        final tools = runtime.InMemoryToolRegistry()
          ..register(
            runtime.ToolDefinition(
              name: 'todo.external_complete',
              description: 'Would complete a todo through an external system.',
              access: runtime.ToolAccess.write,
              external: true,
              handler: (invocation) async {
                toolCalls += 1;
                return const <String, Object?>{'ok': true};
              },
            ),
          );
        final approvalStore = LocalDbApprovalStore(database);
        final kernel = _kernel(
          database,
          idGenerator: SequenceWnIdGenerator(seed: 'approval'),
          clock: TickingWnClock(DateTime.utc(2026, 6, 26, 17)),
          runMode: runtime.RunMode.confirm,
          approvalBroker: runtime.PendingApprovalBroker(approvalStore),
          toolRegistry: tools,
        )..registerPack(_toolPack(id: 'pack.approval-runtime'));

        await kernel.publish(
          const runtime.WnEventDraft(
            type: runtime.WnEventTypes.captureCreated,
            actor: runtime.WnActor.user,
          ),
        );

        final task = (await LocalDbRuntimeStore(database).readTasks()).single;
        final run = (await LocalDbRuntimeStore(database).readRuns()).single;
        final pending = database.runtimeApprovals.readPending();
        final traces = database.traceEvents.readAll();

        expect(toolCalls, 0);
        expect(task.status, runtime.RuntimeTaskStatus.failed);
        expect(task.error, contains('Approval pending'));
        expect(run.status, runtime.RuntimeRunStatus.failed);
        expect(run.error, contains('Approval pending'));
        expect(pending, hasLength(1));
        expect(pending.single.packId, 'pack.approval-runtime');
        expect(pending.single.runId, run.id);
        expect(pending.single.toolName, 'todo.external_complete');
        expect(pending.single.runMode, 'confirm');
        expect(pending.single.inputKeys, <Object?>['source_event_id', 'value']);
        expect(pending.single.sourceRefs, <Object?>[
          <String, Object?>{'kind': 'event', 'id': task.triggerEventId},
        ]);
        expect(
          traces.map((trace) => trace.name),
          containsAll(<String>[
            'runtime.tool.approval_requested',
            'runtime.tool.approval_pending',
            'runtime.run.approval_pending',
          ]),
        );
        expect(
          database.rawDatabase
              .select('SELECT * FROM runtime_approval_requests;')
              .single
              .values
              .join(' '),
          isNot(contains('private-tool-input')),
        );
      },
    );

    test(
      'file-backed database restores task run permission and pack status',
      () async {
        final directory = Directory.systemTemp.createTempSync(
          'widenote_runtime_adapter_reopen_',
        );
        addTearDown(() {
          if (directory.existsSync()) {
            directory.deleteSync(recursive: true);
          }
        });
        final path = '${directory.path}${Platform.pathSeparator}runtime.sqlite';
        final createdAt = DateTime.utc(2026, 6, 26, 16);

        final first = WideNoteLocalDatabase.openPath(path);
        _seedEvent(first, id: 'event-reopen', createdAt: createdAt);
        _seedPackInstallation(
          first,
          packId: 'pack.reopen',
          createdAt: createdAt,
        );
        final firstRuntimeStore = LocalDbRuntimeStore(first);
        final firstPermissionStore = LocalDbPermissionStore(first);
        await firstRuntimeStore.upsertTask(
          _task(
            id: 'task-reopen',
            identityKey: 'identity-reopen',
            packId: 'pack.reopen',
            triggerEventId: 'event-reopen',
            createdAt: createdAt,
          ),
        );
        await firstRuntimeStore.upsertRun(
          _run(
            id: 'run-reopen',
            taskId: 'task-reopen',
            packId: 'pack.reopen',
            leaseExpiresAt: createdAt.add(const Duration(minutes: 5)),
            startedAt: createdAt,
          ),
        );
        await firstRuntimeStore.upsertPackStatus(
          const runtime.RuntimePackStatus(
            packId: 'pack.reopen',
            version: '0.1.0',
            name: 'Reopen Pack',
            status: runtime.RuntimePackStatusKind.queued,
            taskCount: 1,
            queuedCount: 1,
            runningCount: 0,
            succeededCount: 0,
            failedCount: 0,
            deniedCount: 0,
            canceledCount: 0,
            blockedCount: 0,
          ),
        );
        await firstPermissionStore.upsert(
          runtime.PermissionDecision(
            packId: 'pack.reopen',
            permission: 'memory.propose',
            state: runtime.PermissionDecisionState.granted,
            updatedAt: createdAt,
          ),
        );
        first.close();

        final reopened = WideNoteLocalDatabase.openPath(path);
        addTearDown(reopened.close);
        final reopenedRuntimeStore = LocalDbRuntimeStore(reopened);
        final reopenedPermissionStore = LocalDbPermissionStore(reopened);

        expect(
          (await reopenedRuntimeStore.readTaskById('task-reopen'))!.identityKey,
          'identity-reopen',
        );
        expect(
          (await reopenedRuntimeStore.readRunById(
            'run-reopen',
          ))!.leaseExpiresAt,
          createdAt.add(const Duration(minutes: 5)),
        );
        expect(
          (await reopenedRuntimeStore.readPackStatus('pack.reopen'))!.status,
          runtime.RuntimePackStatusKind.queued,
        );
        expect(
          (await reopenedPermissionStore.read(
            'pack.reopen',
            'memory.propose',
          ))!.state,
          runtime.PermissionDecisionState.granted,
        );
      },
    );
  });
}

void _seedEvent(
  WideNoteLocalDatabase database, {
  required String id,
  DateTime? createdAt,
}) {
  database.eventLog.append(
    EventLogEntry(
      id: id,
      type: runtime.WnEventTypes.captureCreated,
      actor: runtime.WnActor.user.name,
      createdAt: createdAt ?? DateTime.utc(2026, 6, 26),
    ),
  );
}

void _seedPackInstallation(
  WideNoteLocalDatabase database, {
  required String packId,
  String name = 'Adapter Pack',
  String version = '0.1.0',
  String status = 'enabled',
  String runtimeStatus = 'idle',
  List<Object?> requestedPermissions = const <Object?>[],
  List<Object?> enabledSubscriptionIds = const <Object?>[],
  Map<String, Object?> manifest = const <String, Object?>{},
  Map<String, Object?> payload = const <String, Object?>{},
  DateTime? createdAt,
}) {
  final timestamp = createdAt ?? DateTime.utc(2026, 6, 26);
  database.packInstallations.insert(
    PackInstallationRecord(
      packId: packId,
      name: name,
      version: version,
      publisher: 'widenote',
      edition: 'official',
      status: status,
      runtimeStatus: runtimeStatus,
      requestedPermissions: requestedPermissions,
      enabledSubscriptionIds: enabledSubscriptionIds,
      manifest: manifest,
      payload: payload,
      installedAt: timestamp,
      updatedAt: timestamp,
    ),
  );
}

void _seedApprovalRuntime(
  WideNoteLocalDatabase database, {
  required DateTime createdAt,
}) {
  _seedEvent(database, id: 'event-approval', createdAt: createdAt);
  _seedPackInstallation(
    database,
    packId: 'pack.approval',
    createdAt: createdAt,
  );
  database.runtimeTasks.insert(
    RuntimeTaskRecord(
      id: 'task-approval',
      packId: 'pack.approval',
      packVersion: '0.1.0',
      agentId: 'agent.adapter',
      handlerId: 'agent.adapter',
      subscriptionId: 'sub.adapter',
      triggerEventId: 'event-approval',
      createdAt: createdAt,
      updatedAt: createdAt,
    ),
  );
  database.runtimeRuns.insert(
    RuntimeRunRecord(
      id: 'run-approval',
      taskId: 'task-approval',
      packId: 'pack.approval',
      packVersion: '0.1.0',
      agentId: 'agent.adapter',
      handlerId: 'agent.adapter',
      status: 'running',
      attempt: 1,
      startedAt: createdAt,
    ),
  );
}

runtime.ApprovalRequest _approvalRequest({
  required String id,
  required DateTime createdAt,
}) {
  return runtime.ApprovalRequest(
    id: id,
    packId: 'pack.approval',
    agentId: 'agent.adapter',
    taskId: 'task-approval',
    runId: 'run-approval',
    toolName: 'todo.suggest',
    runMode: runtime.RunMode.confirm,
    toolAccess: runtime.ToolAccess.write,
    toolRisk: runtime.ToolRisk.low,
    isExternal: false,
    requiredPermissions: const <String>['todo.suggest'],
    inputKeys: const <String>['source_refs', 'title'],
    sourceRefs: const <Object?>[
      <String, Object?>{'kind': 'event', 'id': 'event-approval'},
    ],
    actionSummary: 'Approve one todo.suggest tool invocation.',
    createdAt: createdAt,
    expiresAt: createdAt.add(const Duration(minutes: 15)),
    reason: 'write tool requires approval',
  );
}

RuntimeApprovalRecord _approvalRecord({
  required String id,
  required DateTime createdAt,
}) {
  return RuntimeApprovalRecord(
    id: id,
    packId: 'pack.approval',
    agentId: 'agent.adapter',
    taskId: 'task-approval',
    runId: 'run-approval',
    toolName: 'todo.suggest',
    runMode: 'confirm',
    toolAccess: 'write',
    toolRisk: 'low',
    isExternal: false,
    requiredPermissions: const <Object?>['todo.suggest'],
    inputKeys: const <Object?>['source_refs', 'title'],
    sourceRefs: const <Object?>[
      <String, Object?>{'kind': 'event', 'id': 'event-approval'},
    ],
    actionSummary: 'Approve one todo.suggest tool invocation.',
    requestedAt: createdAt,
    expiresAt: createdAt.add(const Duration(minutes: 15)),
  );
}

runtime.RuntimeTask _task({
  required String id,
  required String identityKey,
  required String packId,
  required String triggerEventId,
  required DateTime createdAt,
  runtime.RuntimeTaskStatus status = runtime.RuntimeTaskStatus.queued,
  List<String> dependencyTaskIds = const <String>[],
  List<String> missingDependencyIds = const <String>[],
  int attempts = 0,
  int maxAttempts = 3,
  String? error,
}) {
  return runtime.RuntimeTask(
    id: id,
    identityKey: identityKey,
    packId: packId,
    packVersion: '0.1.0',
    agentId: 'agent.adapter',
    handlerRole: 'agent.adapter',
    subscriptionId: 'sub.adapter',
    triggerEventId: triggerEventId,
    status: status,
    dependencyTaskIds: dependencyTaskIds,
    missingDependencyIds: missingDependencyIds,
    attempts: attempts,
    maxAttempts: maxAttempts,
    error: error,
    createdAt: createdAt,
    updatedAt: createdAt.add(const Duration(milliseconds: 1)),
  );
}

runtime.RuntimeRun _run({
  required String id,
  required String taskId,
  required String packId,
  required DateTime startedAt,
  runtime.RuntimeRunStatus status = runtime.RuntimeRunStatus.running,
  DateTime? leaseExpiresAt,
}) {
  return runtime.RuntimeRun(
    id: id,
    taskId: taskId,
    packId: packId,
    packVersion: '0.1.0',
    agentId: 'agent.adapter',
    status: status,
    startedAt: startedAt,
    attempt: 1,
    leaseExpiresAt: leaseExpiresAt,
  );
}

runtime.RuntimeKernel _kernel(
  WideNoteLocalDatabase database, {
  LocalDbPermissionStore? permissionStore,
  WnIdGenerator? idGenerator,
  WnClock? clock,
  runtime.RunMode runMode = runtime.RunMode.auto,
  runtime.ApprovalBroker? approvalBroker,
  runtime.ToolRegistry? toolRegistry,
  bool autoDrain = true,
}) {
  return runtime.RuntimeKernel(
    eventStore: LocalDbEventStore(database),
    traceSink: LocalDbTraceSink(database),
    permissionBroker: runtime.InMemoryPermissionBroker(
      store: permissionStore ?? LocalDbPermissionStore(database),
    ),
    toolRegistry: toolRegistry ?? runtime.InMemoryToolRegistry(),
    idGenerator: idGenerator ?? SequenceWnIdGenerator(seed: 'adapter'),
    clock: clock ?? TickingWnClock(DateTime.utc(2026, 6, 26, 13)),
    model: runtime.FakeModel(),
    deviceId: 'device-local',
    runMode: runMode,
    approvalBroker: approvalBroker,
    runtimeStore: LocalDbRuntimeStore(database),
    autoDrain: autoDrain,
  );
}

runtime.AgentPack _insightPack({required String id}) {
  return runtime.AgentPack(
    id: id,
    name: 'Insight Pack',
    version: '0.1.0',
    requiredPermissions: const <String>{'memory.propose'},
    subscriptions: const <runtime.Subscription>[
      runtime.Subscription(
        id: 'sub.adapter',
        agentId: 'agent.adapter',
        eventTypes: <String>{runtime.WnEventTypes.captureCreated},
      ),
    ],
    agentDefinitions: const <String, runtime.AgentDefinition>{
      'agent.adapter': runtime.AgentDefinition(
        id: 'agent.adapter',
        requiredPermissions: <String>{'memory.propose'},
        outputEvents: <String>{runtime.WnEventTypes.insightCreated},
      ),
    },
    agents: const <String, runtime.AgentHandler>{
      'agent.adapter': _InsightHandler(),
    },
  );
}

runtime.AgentPack _emptyPack({required String id}) {
  return runtime.AgentPack(
    id: id,
    name: 'Empty Pack',
    version: '0.1.0',
    subscriptions: const <runtime.Subscription>[],
    agents: const <String, runtime.AgentHandler>{},
  );
}

runtime.AgentPack _toolPack({required String id}) {
  return runtime.AgentPack(
    id: id,
    name: 'Tool Pack',
    version: '0.1.0',
    subscriptions: const <runtime.Subscription>[
      runtime.Subscription(
        id: 'sub.adapter',
        agentId: 'agent.adapter',
        eventTypes: <String>{runtime.WnEventTypes.captureCreated},
      ),
    ],
    agentDefinitions: const <String, runtime.AgentDefinition>{
      'agent.adapter': runtime.AgentDefinition(
        id: 'agent.adapter',
        tools: <String>{'todo.external_complete'},
      ),
    },
    agents: const <String, runtime.AgentHandler>{
      'agent.adapter': _ToolCallingHandler(),
    },
  );
}

final class _InsightHandler implements runtime.AgentHandler {
  const _InsightHandler();

  @override
  Future<runtime.AgentHandlerResult> handle(
    runtime.AgentContext context,
    runtime.WnEvent event,
  ) async {
    return runtime.AgentHandlerResult(
      events: <runtime.WnEventDraft>[
        context.emit(
          type: runtime.WnEventTypes.insightCreated,
          payload: <String, Object?>{'source_event_id': event.id},
        ),
      ],
    );
  }
}

final class _ToolCallingHandler implements runtime.AgentHandler {
  const _ToolCallingHandler();

  @override
  Future<runtime.AgentHandlerResult> handle(
    runtime.AgentContext context,
    runtime.WnEvent event,
  ) async {
    await context.invokeTool(
      'todo.external_complete',
      input: <String, Object?>{
        'source_event_id': event.id,
        'value': 'private-tool-input',
      },
    );
    return const runtime.AgentHandlerResult();
  }
}
