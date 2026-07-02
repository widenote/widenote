import 'package:widenote_core/widenote_core.dart';

import 'approval.dart';
import 'event.dart';
import 'model.dart';
import 'pack.dart';
import 'permissions.dart';
import 'run_mode.dart';
import 'store.dart';
import 'task.dart';
import 'tools.dart';
import 'trace.dart';

final class RuntimeKernel {
  RuntimeKernel({
    required this.eventStore,
    required this.traceSink,
    required this.permissionBroker,
    required this.toolRegistry,
    required this.idGenerator,
    required this.clock,
    required this.model,
    required this.deviceId,
    this.runMode = RunMode.auto,
    this.approvalBroker,
    RuntimeStore? runtimeStore,
    PackRegistry? packRegistry,
    this.runLeaseDuration = const Duration(minutes: 30),
    this.retryBackoffBase = const Duration(seconds: 30),
    this.maxConcurrentTasks = 1,
    this.autoDrain = true,
  }) : runtimeStore = runtimeStore ?? InMemoryRuntimeStore(),
       packRegistry = packRegistry ?? InMemoryPackRegistry();

  final EventStore eventStore;
  final TraceSink traceSink;
  final PermissionBroker permissionBroker;
  final ToolRegistry toolRegistry;
  final WnIdGenerator idGenerator;
  final WnClock clock;
  final ModelClient model;
  final String deviceId;
  final RunMode runMode;
  final ApprovalBroker? approvalBroker;
  final RuntimeStore runtimeStore;
  final PackRegistry packRegistry;
  final Duration runLeaseDuration;
  final Duration retryBackoffBase;
  final int maxConcurrentTasks;
  final bool autoDrain;

  final Map<String, AgentPack> _packs = <String, AgentPack>{};
  final List<RuntimeTask> _tasks = <RuntimeTask>[];
  final List<RuntimeRun> _runs = <RuntimeRun>[];
  final Set<String> _blockedPermissionKeys = <String>{};

  List<RuntimeTask> get tasks => List<RuntimeTask>.unmodifiable(_tasks);
  List<RuntimeRun> get runs => List<RuntimeRun>.unmodifiable(_runs);
  List<RuntimePackStatus> get packStatuses {
    return _packs.values
        .map((pack) {
          final packTasks = _tasks
              .where((task) => task.packId == pack.id)
              .toList();
          final status = _statusForPackTasks(packTasks);
          return RuntimePackStatus(
            packId: pack.id,
            version: pack.version,
            name: pack.name,
            status: status,
            taskCount: packTasks.length,
            queuedCount:
                _countTasks(packTasks, RuntimeTaskStatus.queued) +
                _countTasks(packTasks, RuntimeTaskStatus.waiting),
            runningCount: _countTasks(packTasks, RuntimeTaskStatus.running),
            succeededCount: _countTasks(packTasks, RuntimeTaskStatus.succeeded),
            failedCount: _countTasks(packTasks, RuntimeTaskStatus.failed),
            deniedCount: _countTasks(packTasks, RuntimeTaskStatus.denied),
            canceledCount: _countTasks(packTasks, RuntimeTaskStatus.canceled),
            blockedCount: _countTasks(packTasks, RuntimeTaskStatus.blocked),
          );
        })
        .toList(growable: false);
  }

  void registerPack(AgentPack pack) {
    registerPacks(<AgentPack>[pack]);
  }

  void registerPacks(Iterable<AgentPack> packs) {
    final batch = packs.toList(growable: false);
    final previous = <String, AgentPack?>{
      for (final pack in batch) pack.id: _packs[pack.id],
    };
    try {
      for (final pack in batch) {
        _packs[pack.id] = pack;
        packRegistry.register(pack);
      }
    } catch (_) {
      for (final entry in previous.entries) {
        final oldPack = entry.value;
        if (oldPack == null) {
          _packs.remove(entry.key);
          packRegistry.unregister(entry.key);
        } else {
          _packs[entry.key] = oldPack;
          packRegistry.register(oldPack);
        }
      }
      rethrow;
    }
  }

  Future<void> syncPackStatuses() async {
    for (final status in packStatuses) {
      await runtimeStore.upsertPackStatus(status);
    }
  }

  Future<void> restoreRuntimeState({bool terminateStaleRuns = true}) async {
    _tasks
      ..clear()
      ..addAll(await runtimeStore.readTasks());
    _runs
      ..clear()
      ..addAll(await runtimeStore.readRuns());

    await _restoreRevokedPermissionBlocks();
    if (terminateStaleRuns) {
      await _terminateStaleRuns();
      await _recoverExpiredTaskLeases();
    }
    await syncPackStatuses();
  }

  Future<PermissionRevocationResult> handlePermissionRevoked(
    String packId,
    String permission,
  ) async {
    _blockedPermissionKeys.add(_permissionKey(packId, permission));
    final affectedTaskIds = <String>[];
    for (final task in List<RuntimeTask>.of(_tasks)) {
      if (task.packId != packId ||
          task.status.isTerminal ||
          task.status == RuntimeTaskStatus.running ||
          !_taskRequiresPermission(task, permission)) {
        continue;
      }
      final denied = await _replaceTask(
        task,
        RuntimeTaskStatus.denied,
        error: 'Permission revoked: $permission',
      );
      affectedTaskIds.add(denied.id);
      await _tracePermissionRevoked(denied, permission);
    }
    await _traceContextCacheInvalidationRequested(packId, permission);
    return PermissionRevocationResult(
      packId: packId,
      permission: permission,
      affectedTaskIds: List<String>.unmodifiable(affectedTaskIds),
      contextCacheInvalidationRequested: true,
    );
  }

  Future<WnEvent> publish(WnEventDraft draft) async {
    final event = _materialize(draft);
    await eventStore.append(event);
    await _trace(
      name: 'runtime.event.appended',
      message: 'Event appended.',
      eventId: event.id,
      details: <String, Object?>{
        'trace_type': 'event_received',
        'type': event.type,
      },
    );
    await _enqueueMatching(event);
    if (autoDrain) {
      await drainQueue();
    }
    return event;
  }

  Future<int> drainQueue() async {
    var executed = 0;

    while (true) {
      final claimed = <RuntimeTask>[];
      final reservedTaskIds = <String>{};
      final reservedConcurrencyKeys = <String>{};
      while (claimed.length < _effectiveMaxConcurrentTasks) {
        final task = _nextRunnableTask(
          excludedTaskIds: reservedTaskIds,
          reservedConcurrencyKeys: reservedConcurrencyKeys,
        );
        if (task == null) {
          break;
        }
        reservedTaskIds.add(task.id);
        final next = await _claimTaskForExecution(task);
        if (next == null) {
          await _refreshTask(task.id);
          continue;
        }
        claimed.add(next);
        final concurrencyKey = next.concurrencyKey;
        if (concurrencyKey != null) {
          reservedConcurrencyKeys.add(concurrencyKey);
        }
      }

      if (claimed.isNotEmpty) {
        await Future.wait(claimed.map(_executeTask));
        executed += claimed.length;
        continue;
      }

      final blocked = _nextBlockedTask();
      if (blocked != null) {
        final latest = await _replaceTask(
          blocked,
          RuntimeTaskStatus.blocked,
          error: _dependencyBlockReason(blocked),
        );
        await _traceTaskBlocked(latest);
        continue;
      }

      break;
    }

    return executed;
  }

  Future<bool> cancelTask(
    String taskId, {
    String reason = 'user_requested',
  }) async {
    final task = _taskById(taskId);
    if (task == null || task.status.isTerminal) {
      return false;
    }
    if (task.status == RuntimeTaskStatus.running) {
      return false;
    }

    final next = await _replaceTask(
      task,
      RuntimeTaskStatus.canceled,
      error: reason,
    );
    await _traceTaskCanceled(next, reason);
    return true;
  }

  Future<bool> retryTask(String taskId, {bool drain = true}) async {
    final task = _taskById(taskId);
    if (task == null ||
        task.status == RuntimeTaskStatus.running ||
        task.status == RuntimeTaskStatus.succeeded) {
      return false;
    }

    final status = task.dependencyTaskIds.isEmpty
        ? RuntimeTaskStatus.queued
        : RuntimeTaskStatus.waiting;
    final next = await _replaceTask(
      task,
      status,
      attempts: 0,
      clearError: true,
      clearLease: true,
      clearScheduledAt: true,
    );
    await _traceTaskRetryRequested(next);
    if (drain) {
      await drainQueue();
    }
    return true;
  }

  Future<void> _enqueueMatching(WnEvent event) async {
    final requests = <_TaskRequest>[];
    for (final pack in _packs.values) {
      final disabledReason = await _packDisabledReason(pack.id);
      if (disabledReason != null) {
        await _tracePackDisabledAtEnqueue(pack, event, disabledReason);
        continue;
      }
      for (final subscription in pack.subscriptions) {
        if (!subscription.matches(event)) {
          continue;
        }

        final definition = pack.definitionFor(subscription.agentId);
        final handler = pack.handlerFor(subscription.agentId);
        if (handler == null) {
          await _traceMissingHandler(pack, subscription, event);
        }

        requests.add(
          _TaskRequest(
            pack: pack,
            subscription: subscription,
            event: event,
            definition: definition,
            handler: handler,
          ),
        );
      }
    }

    final taskIdsBySubscription = <String, String>{};
    final created = <_QueuedRequest>[];
    for (final request in requests) {
      final identityKey = _taskIdentityKey(
        eventId: request.event.id,
        packId: request.pack.id,
        packVersion: request.pack.version,
        subscriptionId: request.subscription.id,
        handlerRole: request.subscription.agentId,
      );
      final existing = _taskByIdentity(identityKey);
      if (existing != null) {
        taskIdsBySubscription[_dependencyKey(
              request.pack.id,
              request.subscription.id,
            )] =
            existing.id;
        await _traceDuplicateTaskSkipped(existing, request.event);
        continue;
      }
      final task = _createTask(request);
      _tasks.add(task);
      await runtimeStore.upsertTask(task);
      taskIdsBySubscription[_dependencyKey(
            request.pack.id,
            request.subscription.id,
          )] =
          task.id;
      created.add(_QueuedRequest(request: request, task: task));
    }

    for (final queued in created) {
      final dependencyIds = <String>[];
      final missingDependencyIds = <String>[];
      for (final dependency in queued.request.subscription.dependsOn) {
        final taskId =
            taskIdsBySubscription[_dependencyLookupKey(
              queued.request.pack.id,
              dependency,
            )] ??
            _taskIdForDependency(
              event: queued.request.event,
              currentPackId: queued.request.pack.id,
              dependency: dependency,
            );
        if (taskId == null) {
          missingDependencyIds.add(dependency);
          continue;
        }
        dependencyIds.add(taskId);
      }

      final nextStatus = missingDependencyIds.isNotEmpty
          ? RuntimeTaskStatus.blocked
          : _blockedPermissionFor(
                  queued.request.pack,
                  queued.request.definition,
                ) !=
                null
          ? RuntimeTaskStatus.blocked
          : dependencyIds.isEmpty
          ? RuntimeTaskStatus.queued
          : RuntimeTaskStatus.waiting;
      final blockedPermission = _blockedPermissionFor(
        queued.request.pack,
        queued.request.definition,
      );
      final next = await _replaceTask(
        queued.task,
        nextStatus,
        dependencyTaskIds: dependencyIds,
        missingDependencyIds: missingDependencyIds,
        error: blockedPermission == null
            ? null
            : 'Permission revoked: $blockedPermission',
      );
      await _traceTaskCreated(next, queued.request.event);
      if (nextStatus == RuntimeTaskStatus.waiting) {
        await _traceTaskWaiting(next);
      } else if (nextStatus == RuntimeTaskStatus.blocked) {
        await _traceTaskBlocked(next);
      }
    }
  }

  Future<void> _executeTask(RuntimeTask queuedTask) async {
    final pack = _packs[queuedTask.packId];
    if (pack == null) {
      final blocked = await _replaceTask(
        queuedTask,
        RuntimeTaskStatus.blocked,
        error: 'Registered pack is missing: ${queuedTask.packId}',
      );
      await _traceTaskBlocked(blocked);
      return;
    }

    final definition = pack.definitionFor(queuedTask.agentId);
    final task = queuedTask.status == RuntimeTaskStatus.running
        ? queuedTask
        : await _replaceTask(
            queuedTask,
            RuntimeTaskStatus.running,
            attempts: queuedTask.attempts + 1,
            leaseOwner: _leaseOwner,
            leasedUntil: clock.now().add(runLeaseDuration),
            clearError: true,
            clearScheduledAt: true,
          );
    final run = _createRun(task);
    _runs.add(run);
    await runtimeStore.upsertRun(run);

    final disabledReason = await _packDisabledReason(pack.id);
    if (disabledReason != null) {
      final deniedTask = await _replaceTask(
        task,
        RuntimeTaskStatus.denied,
        error: disabledReason,
      );
      final deniedRun = await _replaceRun(
        run,
        RuntimeRunStatus.denied,
        error: disabledReason,
      );
      await _tracePackDisabledAtExecution(
        deniedTask,
        deniedRun,
        disabledReason,
      );
      return;
    }

    final unsupportedRuntime = _unsupportedRuntimeReason(definition);
    if (unsupportedRuntime != null) {
      final deniedTask = await _replaceTask(
        task,
        RuntimeTaskStatus.denied,
        error: unsupportedRuntime,
      );
      final deniedRun = await _replaceRun(
        run,
        RuntimeRunStatus.denied,
        error: unsupportedRuntime,
      );
      await _traceUnsupportedRuntime(deniedTask, deniedRun, definition);
      return;
    }

    final missing = await permissionBroker.missingPermissions(pack.id, <String>{
      ...pack.requiredPermissions,
      ...definition.requiredPermissions,
    });
    await _tracePermissionChecked(task, run, missing);
    if (missing.isNotEmpty) {
      final deniedTask = await _replaceTask(task, RuntimeTaskStatus.denied);
      final deniedRun = await _replaceRun(run, RuntimeRunStatus.denied);
      await _tracePermissionDenied(deniedTask, deniedRun, missing);
      return;
    }

    await _traceRunStarted(task, run);

    final handler = pack.handlerFor(task.agentId);
    if (handler == null) {
      final error = StateError('Agent handler missing: ${task.agentId}');
      final failedRun = await _replaceRun(
        run,
        RuntimeRunStatus.failed,
        error: error.message,
      );
      final failedTask = await _replaceTask(
        task,
        RuntimeTaskStatus.failed,
        error: error.message,
      );
      await _traceRunFailed(failedTask, failedRun, error);
      return;
    }

    try {
      final context = _contextFor(task, run, definition);
      final triggerEvent = await eventStore.readById(task.triggerEventId);
      if (triggerEvent == null) {
        throw StateError('Trigger event missing: ${task.triggerEventId}');
      }
      final result = await handler.handle(context, triggerEvent);
      _validateOutputEvents(definition, result.events);
      final ownedTask = await _refreshOwnedRunningTask(task, run);
      if (ownedTask == null) {
        return;
      }
      final outputEvents = _materializeOutputs(
        definition,
        result.events,
        triggerEvent,
      );
      await eventStore.appendAll(outputEvents);
      for (final output in outputEvents) {
        await _traceOutput(task, run, output);
      }
      final succeededRun = await _replaceRun(
        run,
        RuntimeRunStatus.succeeded,
        outputEventIds: outputEvents.map((event) => event.id).toList(),
      );
      final succeededTask = await _replaceTask(
        ownedTask,
        RuntimeTaskStatus.succeeded,
      );
      for (final output in outputEvents) {
        await _enqueueMatching(output);
      }
      await _traceRunCompleted(succeededTask, succeededRun);
    } on RuntimePermissionDeniedException catch (error) {
      final deniedRun = await _replaceRun(
        run,
        RuntimeRunStatus.denied,
        error: error.message,
      );
      final deniedTask = await _replaceTask(
        task,
        RuntimeTaskStatus.denied,
        error: error.message,
      );
      await _tracePermissionDenied(deniedTask, deniedRun, error.permissions);
    } on OutputEventValidationException catch (error) {
      final failedRun = await _replaceRun(
        run,
        RuntimeRunStatus.failed,
        error: error.message,
      );
      final failedTask = await _replaceTask(
        task,
        RuntimeTaskStatus.failed,
        error: error.message,
      );
      await _traceOutputRejected(failedTask, failedRun, error);
    } on OutputSourceRefValidationException catch (error) {
      final failedRun = await _replaceRun(
        run,
        RuntimeRunStatus.failed,
        error: error.message,
      );
      final failedTask = await _replaceTask(
        task,
        RuntimeTaskStatus.failed,
        error: error.message,
      );
      await _traceOutputSourceRefRejected(failedTask, failedRun, error);
    } on ApprovalPendingException catch (error) {
      final safeError = _safeTraceError(error.message);
      final failedRun = await _replaceRun(
        run,
        RuntimeRunStatus.failed,
        error: safeError,
      );
      final failedTask = await _replaceTask(
        task,
        RuntimeTaskStatus.failed,
        error: safeError,
      );
      await _traceRunApprovalPending(failedTask, failedRun, error);
    } catch (error) {
      final safeError = _safeTraceError('$error');
      final failedRun = await _replaceRun(
        run,
        RuntimeRunStatus.failed,
        error: safeError,
      );
      if (task.canRetry) {
        final retryStatus = task.dependencyTaskIds.isEmpty
            ? RuntimeTaskStatus.queued
            : RuntimeTaskStatus.waiting;
        final retryTask = await _replaceTask(
          task,
          retryStatus,
          error: safeError,
          scheduledAt: _retryScheduledAt(task),
        );
        await _traceRunFailed(retryTask, failedRun, error);
        await _traceTaskRetryQueued(retryTask);
        return;
      }

      final failedTask = await _replaceTask(
        task,
        RuntimeTaskStatus.failed,
        error: safeError,
      );
      await _traceRunFailed(failedTask, failedRun, error);
    }
  }

  Future<RuntimeTask?> _claimTaskForExecution(RuntimeTask task) async {
    final now = clock.now();
    final claimed = await runtimeStore.claimTaskForExecution(
      task.id,
      leaseOwner: _leaseOwner,
      leasedUntil: now.add(runLeaseDuration),
      now: now,
      maxRunningTasks: _effectiveMaxConcurrentTasks,
    );
    if (claimed == null) {
      return null;
    }
    final index = _tasks.indexWhere((candidate) => candidate.id == claimed.id);
    if (index >= 0) {
      _tasks[index] = claimed;
    } else {
      _tasks.add(claimed);
    }
    await _persistPackStatus(claimed.packId);
    return claimed;
  }

  Future<void> _refreshTask(String taskId) async {
    final latest = await runtimeStore.readTaskById(taskId);
    if (latest == null) {
      _tasks.removeWhere((candidate) => candidate.id == taskId);
      return;
    }
    final index = _tasks.indexWhere((candidate) => candidate.id == taskId);
    if (index >= 0) {
      _tasks[index] = latest;
    } else {
      _tasks.add(latest);
    }
  }

  RuntimeTask? _nextRunnableTask({
    Set<String> excludedTaskIds = const <String>{},
    Set<String> reservedConcurrencyKeys = const <String>{},
  }) {
    for (final task in _tasks) {
      if (excludedTaskIds.contains(task.id)) {
        continue;
      }
      if (task.status != RuntimeTaskStatus.queued &&
          task.status != RuntimeTaskStatus.waiting) {
        continue;
      }
      if (_isScheduledForLater(task)) {
        continue;
      }
      final concurrencyKey = task.concurrencyKey;
      if (concurrencyKey != null &&
          (reservedConcurrencyKeys.contains(concurrencyKey) ||
              _hasRunningConcurrencyKey(concurrencyKey))) {
        continue;
      }
      if (_dependenciesSucceeded(task)) {
        return task;
      }
    }
    return null;
  }

  bool _isScheduledForLater(RuntimeTask task) {
    final scheduledAt = task.scheduledAt;
    return scheduledAt != null && scheduledAt.isAfter(clock.now());
  }

  bool _hasRunningConcurrencyKey(String concurrencyKey) {
    return _tasks.any(
      (task) =>
          task.status == RuntimeTaskStatus.running &&
          task.concurrencyKey == concurrencyKey,
    );
  }

  int get _effectiveMaxConcurrentTasks {
    return maxConcurrentTasks < 1 ? 1 : maxConcurrentTasks;
  }

  String get _leaseOwner => '$deviceId:runtime';

  RuntimeTask? _nextBlockedTask() {
    for (final task in _tasks) {
      if (task.status == RuntimeTaskStatus.blocked) {
        continue;
      }
      if (task.missingDependencyIds.isNotEmpty) {
        return task;
      }
      if ((task.status == RuntimeTaskStatus.queued ||
              task.status == RuntimeTaskStatus.waiting) &&
          _hasTerminalFailedDependency(task)) {
        return task;
      }
    }
    return null;
  }

  bool _dependenciesSucceeded(RuntimeTask task) {
    return task.dependencyTaskIds.every((id) {
      return _taskById(id)?.status == RuntimeTaskStatus.succeeded;
    });
  }

  bool _hasTerminalFailedDependency(RuntimeTask task) {
    return task.dependencyTaskIds.any((id) {
      final dependency = _taskById(id);
      if (dependency == null || !dependency.status.isTerminal) {
        return false;
      }
      return dependency.status != RuntimeTaskStatus.succeeded;
    });
  }

  RuntimeTask? _taskById(String taskId) {
    for (final task in _tasks) {
      if (task.id == taskId) {
        return task;
      }
    }
    return null;
  }

  RuntimeTask? _taskByIdentity(String identityKey) {
    for (final task in _tasks) {
      if (task.identityKey == identityKey) {
        return task;
      }
    }
    return null;
  }

  String _taskIdentityKey({
    required String eventId,
    required String packId,
    required String packVersion,
    required String subscriptionId,
    required String handlerRole,
  }) {
    return [
      eventId,
      packId,
      packVersion,
      subscriptionId,
      handlerRole,
    ].join('::');
  }

  bool _taskRequiresPermission(RuntimeTask task, String permission) {
    final pack = _packs[task.packId];
    if (pack == null) {
      return false;
    }
    final definition = pack.definitionFor(task.agentId);
    return pack.requiredPermissions.contains(permission) ||
        definition.requiredPermissions.contains(permission);
  }

  Future<String?> _packDisabledReason(String packId) async {
    final installationStore = runtimeStore is RuntimePackInstallationStore
        ? runtimeStore as RuntimePackInstallationStore
        : null;
    if (installationStore != null) {
      final installation = await installationStore.readPackInstallation(packId);
      if (installation != null && !installation.status.isEnabled) {
        return installation.reason ?? 'Pack disabled at execution: $packId';
      }
    }

    final status = await runtimeStore.readPackStatus(packId);
    if (status?.status == RuntimePackStatusKind.disabled) {
      return 'Pack disabled at execution: $packId';
    }
    return null;
  }

  String? _blockedPermissionFor(AgentPack pack, AgentDefinition definition) {
    for (final permission in <String>{
      ...pack.requiredPermissions,
      ...definition.requiredPermissions,
    }) {
      if (_blockedPermissionKeys.contains(
        _permissionKey(pack.id, permission),
      )) {
        return permission;
      }
    }
    return null;
  }

  String _permissionKey(String packId, String permission) {
    return '$packId::$permission';
  }

  Future<void> _restoreRevokedPermissionBlocks() async {
    _blockedPermissionKeys.clear();
    for (final pack in _packs.values) {
      final decisions = await permissionBroker.decisionsForPack(pack.id);
      for (final decision in decisions) {
        if (decision.state == PermissionDecisionState.revoked) {
          _blockedPermissionKeys.add(
            _permissionKey(decision.packId, decision.permission),
          );
        }
      }
    }
  }

  Future<void> _terminateStaleRuns() async {
    final now = clock.now();
    for (final run in List<RuntimeRun>.of(_runs)) {
      if (run.status != RuntimeRunStatus.running) {
        continue;
      }
      final leaseExpiresAt = run.leaseExpiresAt;
      if (leaseExpiresAt == null || leaseExpiresAt.isAfter(now)) {
        continue;
      }
      final task = _taskById(run.taskId);
      final error =
          'Recovered stale running run ${run.id}; lease expired at '
          '${leaseExpiresAt.toIso8601String()}.';
      final failedRun = await _replaceRun(
        run,
        RuntimeRunStatus.failed,
        error: error,
      );
      RuntimeTask? recoveredTask;
      if (task != null && task.status == RuntimeTaskStatus.running) {
        recoveredTask = await _recoverInterruptedTask(task, error);
      }
      await _traceStaleRunTerminated(recoveredTask, failedRun, error);
      if (recoveredTask != null) {
        await _traceStaleTaskRecovered(recoveredTask, error);
        if (!recoveredTask.status.isTerminal) {
          await _traceTaskRetryQueued(recoveredTask);
        }
      }
    }
  }

  Future<void> _recoverExpiredTaskLeases() async {
    final now = clock.now();
    for (final task in List<RuntimeTask>.of(_tasks)) {
      final leasedUntil = task.leasedUntil;
      if (task.status != RuntimeTaskStatus.running ||
          leasedUntil == null ||
          leasedUntil.isAfter(now)) {
        continue;
      }
      final hasActiveRun = _runs.any(
        (run) =>
            run.taskId == task.id && run.status == RuntimeRunStatus.running,
      );
      if (hasActiveRun) {
        continue;
      }
      final error =
          'Recovered stale running task ${task.id}; lease expired at '
          '${leasedUntil.toIso8601String()}.';
      final recovered = await _recoverInterruptedTask(task, error);
      await _traceStaleTaskRecovered(recovered, error);
      if (!recovered.status.isTerminal) {
        await _traceTaskRetryQueued(recovered);
      }
    }
  }

  Future<RuntimeTask> _recoverInterruptedTask(RuntimeTask task, String error) {
    final status = task.canRetry
        ? task.dependencyTaskIds.isEmpty
              ? RuntimeTaskStatus.queued
              : RuntimeTaskStatus.waiting
        : RuntimeTaskStatus.failed;
    return _replaceTask(
      task,
      status,
      error: error,
      scheduledAt: task.canRetry ? _retryScheduledAt(task) : null,
      clearLease: true,
    );
  }

  String _dependencyBlockReason(RuntimeTask task) {
    if (task.missingDependencyIds.isNotEmpty) {
      return 'Missing dependencies: ${task.missingDependencyIds.join(', ')}';
    }
    final failedDependencies = task.dependencyTaskIds
        .where((id) {
          final dependency = _taskById(id);
          return dependency != null &&
              dependency.status.isTerminal &&
              dependency.status != RuntimeTaskStatus.succeeded;
        })
        .toList(growable: false);
    return 'Dependency did not succeed: ${failedDependencies.join(', ')}';
  }

  String? _unsupportedRuntimeReason(AgentDefinition definition) {
    return switch (definition.runtimeKind) {
      AgentRuntimeKind.native => null,
      AgentRuntimeKind.declarative =>
        'Declarative agent execution is not available in the local native runtime.',
      AgentRuntimeKind.remote =>
        'Remote agent execution is not available in the local native runtime.',
      AgentRuntimeKind.script =>
        'Script execution is not available without an accepted sandbox.',
    };
  }

  String _dependencyKey(String packId, String subscriptionId) {
    return '$packId::$subscriptionId';
  }

  String _dependencyLookupKey(String packId, String dependency) {
    return dependency.contains('::')
        ? dependency
        : _dependencyKey(packId, dependency);
  }

  String? _taskIdForDependency({
    required WnEvent event,
    required String currentPackId,
    required String dependency,
  }) {
    final key = _dependencyLookupKey(currentPackId, dependency);
    final separator = key.indexOf('::');
    if (separator <= 0 || separator >= key.length - 2) {
      return null;
    }
    final packId = key.substring(0, separator);
    final subscriptionId = key.substring(separator + 2);
    final pack = _packs[packId];
    if (pack == null) {
      return null;
    }
    Subscription? subscription;
    for (final candidate in pack.subscriptions) {
      if (candidate.id == subscriptionId) {
        subscription = candidate;
        break;
      }
    }
    if (subscription == null) {
      return null;
    }
    final identityKey = _taskIdentityKey(
      eventId: event.id,
      packId: pack.id,
      packVersion: pack.version,
      subscriptionId: subscription.id,
      handlerRole: subscription.agentId,
    );
    return _taskByIdentity(identityKey)?.id;
  }

  RuntimePackStatusKind _statusForPackTasks(List<RuntimeTask> tasks) {
    if (tasks.isEmpty) {
      return RuntimePackStatusKind.idle;
    }
    if (tasks.any((task) => task.status == RuntimeTaskStatus.running)) {
      return RuntimePackStatusKind.running;
    }
    if (tasks.any(
      (task) =>
          task.status == RuntimeTaskStatus.queued ||
          task.status == RuntimeTaskStatus.waiting,
    )) {
      return RuntimePackStatusKind.queued;
    }
    if (tasks.any((task) => task.status == RuntimeTaskStatus.failed)) {
      return RuntimePackStatusKind.failed;
    }
    if (tasks.any((task) => task.status == RuntimeTaskStatus.denied)) {
      return RuntimePackStatusKind.denied;
    }
    if (tasks.any((task) => task.status == RuntimeTaskStatus.blocked)) {
      return RuntimePackStatusKind.blocked;
    }
    if (tasks.any((task) => task.status == RuntimeTaskStatus.canceled)) {
      return RuntimePackStatusKind.canceled;
    }
    return RuntimePackStatusKind.succeeded;
  }

  int _countTasks(List<RuntimeTask> tasks, RuntimeTaskStatus status) {
    return tasks.where((task) => task.status == status).length;
  }

  Future<void> _persistPackStatus(String packId) async {
    RuntimePackStatus? status;
    for (final candidate in packStatuses) {
      if (candidate.packId == packId) {
        status = candidate;
        break;
      }
    }
    if (status != null) {
      await runtimeStore.upsertPackStatus(status);
    }
  }

  RuntimeTask _createTask(_TaskRequest request) {
    final now = clock.now();
    final handlerRole = request.subscription.agentId;
    return RuntimeTask(
      id: idGenerator.nextId('task'),
      identityKey: _taskIdentityKey(
        eventId: request.event.id,
        packId: request.pack.id,
        packVersion: request.pack.version,
        subscriptionId: request.subscription.id,
        handlerRole: handlerRole,
      ),
      packId: request.pack.id,
      packVersion: request.pack.version,
      agentId: request.subscription.agentId,
      handlerRole: handlerRole,
      subscriptionId: request.subscription.id,
      triggerEventId: request.event.id,
      status: RuntimeTaskStatus.queued,
      createdAt: now,
      updatedAt: now,
      runMode: request.definition.runMode ?? runMode,
      maxAttempts: request.definition.retryPolicy.normalizedMaxAttempts,
      concurrencyKey: request.definition.concurrencyKey,
    );
  }

  RuntimeRun _createRun(RuntimeTask task) {
    final startedAt = clock.now();
    return RuntimeRun(
      id: idGenerator.nextId('run'),
      taskId: task.id,
      packId: task.packId,
      packVersion: task.packVersion,
      agentId: task.agentId,
      status: RuntimeRunStatus.running,
      startedAt: startedAt,
      attempt: task.attempts,
      runMode: task.runMode,
      leaseExpiresAt: startedAt.add(runLeaseDuration),
    );
  }

  AgentContext _contextFor(
    RuntimeTask task,
    RuntimeRun run,
    AgentDefinition definition,
  ) {
    return AgentContext(
      packId: task.packId,
      agentId: task.agentId,
      task: task,
      run: run,
      runMode: run.runMode,
      model: _PermissionCheckedModelClient(
        packId: task.packId,
        taskId: task.id,
        runId: run.id,
        agentId: task.agentId,
        permissionBroker: permissionBroker,
        delegate: model,
        trace: _trace,
      ),
      tools: _RuntimeToolInvoker(
        packId: task.packId,
        runId: run.id,
        taskId: task.id,
        agentId: task.agentId,
        permissionBroker: permissionBroker,
        toolRegistry: toolRegistry,
        runMode: run.runMode,
        declaredTools: definition.tools,
        approvalBroker: approvalBroker,
        idGenerator: idGenerator,
        clock: clock,
        trace: _trace,
      ),
    );
  }

  Future<RuntimeTask> _replaceTask(
    RuntimeTask task,
    RuntimeTaskStatus status, {
    List<String>? dependencyTaskIds,
    List<String>? missingDependencyIds,
    int? attempts,
    int? maxAttempts,
    DateTime? scheduledAt,
    String? leaseOwner,
    DateTime? leasedUntil,
    String? concurrencyKey,
    String? error,
    bool clearScheduledAt = false,
    bool clearLease = false,
    bool clearConcurrencyKey = false,
    bool clearError = false,
  }) async {
    final next = task.copyWith(
      status: status,
      updatedAt: clock.now(),
      dependencyTaskIds: dependencyTaskIds,
      missingDependencyIds: missingDependencyIds,
      attempts: attempts,
      maxAttempts: maxAttempts,
      scheduledAt: scheduledAt,
      leaseOwner: leaseOwner,
      leasedUntil: leasedUntil,
      concurrencyKey: concurrencyKey,
      error: error,
      clearScheduledAt: clearScheduledAt,
      clearLease: clearLease || status != RuntimeTaskStatus.running,
      clearConcurrencyKey: clearConcurrencyKey,
      clearError: clearError,
    );
    final saved = await _persistTaskTransition(task, next);
    await _persistPackStatus(saved.packId);
    return saved;
  }

  Future<RuntimeTask> _persistTaskTransition(
    RuntimeTask previous,
    RuntimeTask next,
  ) async {
    RuntimeTask saved = next;
    if (previous.status == RuntimeTaskStatus.running &&
        previous.leaseOwner == _leaseOwner &&
        previous.leaseOwner != null) {
      saved =
          await runtimeStore.upsertTaskIfLeaseOwner(
            next,
            leaseOwner: _leaseOwner,
          ) ??
          await runtimeStore.readTaskById(previous.id) ??
          next;
    } else {
      await runtimeStore.upsertTask(next);
    }
    final index = _tasks.indexWhere((candidate) => candidate.id == previous.id);
    if (index >= 0) {
      _tasks[index] = saved;
    } else {
      _tasks.add(saved);
    }
    return saved;
  }

  Future<RuntimeTask?> _refreshOwnedRunningTask(
    RuntimeTask task,
    RuntimeRun run,
  ) async {
    final latest = await runtimeStore.readTaskById(task.id);
    if (latest == null) {
      const reason = 'Task disappeared before output.';
      await _replaceRun(run, RuntimeRunStatus.failed, error: reason);
      await _traceTaskLeaseLost(task, run, reason);
      return null;
    }
    final index = _tasks.indexWhere((candidate) => candidate.id == latest.id);
    if (index >= 0) {
      _tasks[index] = latest;
    }
    final leasedUntil = latest.leasedUntil;
    final leaseExpired =
        leasedUntil != null && !leasedUntil.isAfter(clock.now());
    if (latest.status != RuntimeTaskStatus.running ||
        latest.leaseOwner != _leaseOwner ||
        leaseExpired) {
      final reason = leaseExpired
          ? 'Task lease expired before output.'
          : 'Task lease owner changed before output.';
      await _replaceRun(run, RuntimeRunStatus.failed, error: reason);
      await _traceTaskLeaseLost(latest, run, reason);
      return null;
    }
    return latest;
  }

  DateTime _retryScheduledAt(RuntimeTask task) {
    final exponent = (task.attempts - 1).clamp(0, 6).toInt();
    final multiplier = 1 << exponent;
    return clock.now().add(retryBackoffBase * multiplier);
  }

  Future<RuntimeRun> _replaceRun(
    RuntimeRun run,
    RuntimeRunStatus status, {
    List<String>? outputEventIds,
    String? error,
  }) async {
    final next = run.copyWith(
      status: status,
      completedAt: clock.now(),
      outputEventIds: outputEventIds,
      error: error,
    );
    final index = _runs.indexWhere((candidate) => candidate.id == run.id);
    if (index >= 0) {
      _runs[index] = next;
    }
    await runtimeStore.upsertRun(next);
    return next;
  }

  List<WnEvent> _materializeOutputs(
    AgentDefinition definition,
    Iterable<WnEventDraft> drafts,
    WnEvent causedBy,
  ) {
    return drafts
        .map(
          (draft) => _materialize(
            _ensureOutputSourceRefs(definition, draft, causedBy),
            causedBy: causedBy,
          ),
        )
        .toList();
  }

  void _validateOutputEvents(
    AgentDefinition definition,
    Iterable<WnEventDraft> drafts,
  ) {
    final outputs = drafts.toList(growable: false);
    if (outputs.isEmpty) {
      return;
    }
    if (definition.outputEvents.isEmpty) {
      throw OutputEventValidationException(
        agentId: definition.id,
        eventType: outputs.first.type,
        declaredOutputEvents: definition.outputEvents,
      );
    }
    for (final draft in outputs) {
      if (!definition.outputEvents.contains(draft.type)) {
        throw OutputEventValidationException(
          agentId: definition.id,
          eventType: draft.type,
          declaredOutputEvents: definition.outputEvents,
        );
      }
    }
  }

  WnEventDraft _ensureOutputSourceRefs(
    AgentDefinition definition,
    WnEventDraft draft,
    WnEvent causedBy,
  ) {
    if (!_requiresSourceRefs(draft.type)) {
      return draft;
    }
    final refs = _validatedSourceRefs(
      definition.id,
      draft.type,
      draft.payload['source_refs'],
    );
    if (refs.isNotEmpty) {
      return draft;
    }
    return _copyDraftWithPayload(draft, <String, Object?>{
      ...draft.payload,
      'source_refs': <Object?>[_eventSourceRef(causedBy)],
    });
  }

  bool _requiresSourceRefs(String eventType) {
    return _sourceRefRequiredOutputTypes.contains(eventType);
  }

  List<Object?> _validatedSourceRefs(
    String agentId,
    String eventType,
    Object? value,
  ) {
    if (value == null) {
      return const <Object?>[];
    }
    if (value is! List) {
      throw OutputSourceRefValidationException(
        agentId: agentId,
        eventType: eventType,
        reason: 'source_refs must be a list.',
      );
    }
    for (final ref in value) {
      if (!_isSourceRef(ref)) {
        throw OutputSourceRefValidationException(
          agentId: agentId,
          eventType: eventType,
          reason:
              'source_refs must contain objects with kind/id or source_type/source_id.',
        );
      }
    }
    return value;
  }

  bool _isSourceRef(Object? value) {
    if (value is! Map) {
      return false;
    }
    final kind = value['kind'] ?? value['source_type'];
    final id = value['id'] ?? value['source_id'];
    return kind is String && kind.isNotEmpty && id is String && id.isNotEmpty;
  }

  JsonMap _eventSourceRef(WnEvent event) {
    return <String, Object?>{
      'kind': 'event',
      'id': event.id,
      'source_type': 'event',
      'source_id': event.id,
      'event_type': event.type,
    };
  }

  WnEventDraft _copyDraftWithPayload(WnEventDraft draft, JsonMap payload) {
    return WnEventDraft(
      type: draft.type,
      actor: draft.actor,
      schemaVersion: draft.schemaVersion,
      payload: payload,
      privacy: draft.privacy,
      packId: draft.packId,
      agentId: draft.agentId,
      subjectRef: draft.subjectRef,
      causationId: draft.causationId,
      correlationId: draft.correlationId,
    );
  }

  WnEvent _materialize(WnEventDraft draft, {WnEvent? causedBy}) {
    final id = idGenerator.nextId('evt');
    return WnEvent(
      id: id,
      type: draft.type,
      schemaVersion: draft.schemaVersion,
      actor: draft.actor,
      packId: draft.packId,
      agentId: draft.agentId,
      subjectRef: draft.subjectRef,
      payload: immutableJsonMap(draft.payload),
      privacy: draft.privacy,
      causationId: draft.causationId ?? causedBy?.id,
      correlationId: draft.correlationId ?? causedBy?.correlationId ?? id,
      deviceId: deviceId,
      createdAt: clock.now(),
    );
  }

  Future<void> _trace({
    required String name,
    required String message,
    TraceLevel level = TraceLevel.info,
    String? eventId,
    String? taskId,
    String? runId,
    String? packId,
    String? agentId,
    JsonMap details = const <String, Object?>{},
  }) {
    return traceSink.record(
      RuntimeTrace(
        id: idGenerator.nextId('trace'),
        name: name,
        message: message,
        level: level,
        createdAt: clock.now(),
        eventId: eventId,
        taskId: taskId,
        runId: runId,
        packId: packId,
        agentId: agentId,
        details: immutableJsonMap(_safeTraceDetails(details)),
      ),
    );
  }

  JsonMap _safeTraceDetails(JsonMap details) {
    return <String, Object?>{
      for (final entry in details.entries) entry.key: _safeTraceValue(entry),
    };
  }

  Object? _safeTraceValue(
    MapEntry<String, Object?> entry, {
    bool preserveStrings = false,
  }) {
    final value = entry.value;
    final preserveRaw =
        preserveStrings || _rawTraceDetailKeys.contains(entry.key);
    if (value is String) {
      return preserveRaw ? value : _limitedTraceString(value);
    }
    if (value is Map) {
      return <String, Object?>{
        for (final nested in value.entries)
          if (nested.key is String)
            nested.key as String: _safeTraceValue(
              MapEntry<String, Object?>(
                nested.key as String,
                nested.value as Object?,
              ),
              preserveStrings: preserveRaw,
            ),
      };
    }
    if (value is Iterable) {
      return value
          .map((item) {
            if (item is String) {
              return preserveRaw ? item : _limitedTraceString(item);
            }
            if (item is Map) {
              return _safeTraceValue(
                MapEntry<String, Object?>('item', item),
                preserveStrings: preserveRaw,
              );
            }
            return item;
          })
          .toList(growable: false);
    }
    return value;
  }

  String _limitedTraceString(String value) {
    if (value.length > 240) {
      return '${value.substring(0, 240)}...';
    }
    return value;
  }

  Future<void> _traceMissingHandler(
    AgentPack pack,
    Subscription subscription,
    WnEvent event,
  ) {
    return _trace(
      name: 'runtime.handler.missing',
      message: 'Subscription has no registered handler.',
      level: TraceLevel.warning,
      eventId: event.id,
      packId: pack.id,
      agentId: subscription.agentId,
    );
  }

  Future<void> _traceTaskCreated(RuntimeTask task, WnEvent event) {
    return _trace(
      name: 'runtime.task.created',
      message: 'Task created from subscription.',
      eventId: event.id,
      taskId: task.id,
      packId: task.packId,
      agentId: task.agentId,
      details: <String, Object?>{
        'trace_type': 'task_created',
        'subscription_id': task.subscriptionId,
        'identity_key': task.identityKey,
        'pack_version': task.packVersion,
        'dependency_task_ids': task.dependencyTaskIds,
        'max_attempts': task.maxAttempts,
      },
    );
  }

  Future<void> _traceDuplicateTaskSkipped(RuntimeTask task, WnEvent event) {
    return _trace(
      name: 'runtime.task.duplicate_skipped',
      message: 'Duplicate task identity was already queued.',
      level: TraceLevel.debug,
      eventId: event.id,
      taskId: task.id,
      packId: task.packId,
      agentId: task.agentId,
      details: <String, Object?>{
        'trace_type': 'task_created',
        'identity_key': task.identityKey,
      },
    );
  }

  Future<void> _traceTaskWaiting(RuntimeTask task) {
    return _trace(
      name: 'runtime.task.waiting',
      message: 'Task is waiting for dependencies.',
      taskId: task.id,
      packId: task.packId,
      agentId: task.agentId,
      details: <String, Object?>{
        'trace_type': 'task_created',
        'dependency_task_ids': task.dependencyTaskIds,
      },
    );
  }

  Future<void> _traceTaskCanceled(RuntimeTask task, String reason) {
    return _trace(
      name: 'runtime.task.canceled',
      message: 'Queued task was canceled.',
      level: TraceLevel.warning,
      taskId: task.id,
      packId: task.packId,
      agentId: task.agentId,
      details: <String, Object?>{'trace_type': 'failed', 'reason': reason},
    );
  }

  Future<void> _traceTaskBlocked(RuntimeTask task) {
    return _trace(
      name: 'runtime.task.blocked',
      message: 'Task dependency could not be satisfied.',
      level: TraceLevel.warning,
      taskId: task.id,
      packId: task.packId,
      agentId: task.agentId,
      details: <String, Object?>{
        'trace_type': 'failed',
        'dependency_task_ids': task.dependencyTaskIds,
        'missing_dependency_ids': task.missingDependencyIds,
        'error': task.error,
      },
    );
  }

  Future<void> _tracePackDisabledAtEnqueue(
    AgentPack pack,
    WnEvent event,
    String reason,
  ) {
    return _trace(
      name: 'runtime.pack.disabled_at_enqueue',
      message: 'Pack is disabled; subscription dispatch skipped.',
      level: TraceLevel.warning,
      eventId: event.id,
      packId: pack.id,
      details: <String, Object?>{
        'trace_type': 'permission_checked',
        'error_code': 'pack_disabled',
        'reason': reason,
      },
    );
  }

  Future<void> _tracePackDisabledAtExecution(
    RuntimeTask task,
    RuntimeRun run,
    String reason,
  ) {
    return _trace(
      name: 'runtime.pack.disabled_at_execution',
      message: 'Queued task denied because the pack is disabled.',
      level: TraceLevel.warning,
      taskId: task.id,
      runId: run.id,
      packId: task.packId,
      agentId: task.agentId,
      details: <String, Object?>{
        'trace_type': 'permission_checked',
        'error_code': 'pack_disabled',
        'reason': reason,
        'attempt': run.attempt,
      },
    );
  }

  Future<void> _traceTaskRetryQueued(RuntimeTask task) {
    return _trace(
      name: 'runtime.task.retry_queued',
      message: 'Failed task was queued for retry.',
      level: TraceLevel.warning,
      taskId: task.id,
      packId: task.packId,
      agentId: task.agentId,
      details: <String, Object?>{
        'trace_type': 'failed',
        'attempts': task.attempts,
        'max_attempts': task.maxAttempts,
      },
    );
  }

  Future<void> _traceTaskRetryRequested(RuntimeTask task) {
    return _trace(
      name: 'runtime.task.retry_requested',
      message: 'Task retry was requested.',
      taskId: task.id,
      packId: task.packId,
      agentId: task.agentId,
      details: <String, Object?>{
        'trace_type': 'task_created',
        'max_attempts': task.maxAttempts,
      },
    );
  }

  Future<void> _traceRunStarted(RuntimeTask task, RuntimeRun run) {
    return _trace(
      name: 'runtime.run.started',
      message: 'Agent run started.',
      taskId: task.id,
      runId: run.id,
      packId: task.packId,
      agentId: task.agentId,
      details: <String, Object?>{
        'trace_type': 'run_started',
        'attempt': run.attempt,
        'run_mode': run.runMode.wireName,
        'lease_expires_at': run.leaseExpiresAt?.toIso8601String(),
      },
    );
  }

  Future<void> _traceOutput(RuntimeTask task, RuntimeRun run, WnEvent output) {
    return _trace(
      name: 'runtime.handler.output',
      message: 'Handler emitted event.',
      eventId: output.id,
      taskId: task.id,
      runId: run.id,
      packId: task.packId,
      agentId: task.agentId,
      details: <String, Object?>{
        'trace_type': 'event_emitted',
        'type': output.type,
      },
    );
  }

  Future<void> _traceOutputRejected(
    RuntimeTask task,
    RuntimeRun run,
    OutputEventValidationException error,
  ) {
    return _trace(
      name: 'runtime.handler.output_rejected',
      message: 'Handler emitted an undeclared output event.',
      level: TraceLevel.error,
      taskId: task.id,
      runId: run.id,
      packId: task.packId,
      agentId: task.agentId,
      details: <String, Object?>{
        'trace_type': 'error',
        'event_type': error.eventType,
        'declared_output_events': error.declaredOutputEvents.toList(),
        'error': error.message,
      },
    );
  }

  Future<void> _traceOutputSourceRefRejected(
    RuntimeTask task,
    RuntimeRun run,
    OutputSourceRefValidationException error,
  ) {
    return _trace(
      name: 'runtime.handler.output_rejected',
      message: 'Handler emitted output without valid source refs.',
      level: TraceLevel.error,
      taskId: task.id,
      runId: run.id,
      packId: task.packId,
      agentId: task.agentId,
      details: <String, Object?>{
        'trace_type': 'error',
        'event_type': error.eventType,
        'error_code': 'invalid_source_refs',
        'error': error.message,
      },
    );
  }

  Future<void> _traceRunCompleted(RuntimeTask task, RuntimeRun run) {
    return _trace(
      name: 'runtime.run.completed',
      message: 'Agent run completed.',
      taskId: task.id,
      runId: run.id,
      packId: task.packId,
      agentId: task.agentId,
      details: <String, Object?>{
        'trace_type': 'run_completed',
        'output_event_count': run.outputEventIds.length,
        'attempt': run.attempt,
      },
    );
  }

  Future<void> _traceTaskLeaseLost(
    RuntimeTask task,
    RuntimeRun run,
    String reason,
  ) {
    return _trace(
      name: 'runtime.task.lease_lost',
      message: 'Task output was skipped because the execution lease is gone.',
      level: TraceLevel.warning,
      taskId: task.id,
      runId: run.id,
      packId: task.packId,
      agentId: task.agentId,
      details: <String, Object?>{
        'trace_type': 'lease_lost',
        'reason': reason,
        'lease_owner': task.leaseOwner,
        'leased_until': task.leasedUntil?.toIso8601String(),
      },
    );
  }

  Future<void> _traceRunFailed(RuntimeTask task, RuntimeRun run, Object error) {
    return _trace(
      name: 'runtime.run.failed',
      message: 'Agent run failed.',
      level: TraceLevel.error,
      taskId: task.id,
      runId: run.id,
      packId: task.packId,
      agentId: task.agentId,
      details: <String, Object?>{
        'trace_type': 'error',
        'error': _safeTraceError('$error'),
        'error_type': error.runtimeType.toString(),
        'attempt': run.attempt,
      },
    );
  }

  Future<void> _traceUnsupportedRuntime(
    RuntimeTask task,
    RuntimeRun run,
    AgentDefinition definition,
  ) {
    return _trace(
      name: 'runtime.agent.unsupported_runtime',
      message: 'Agent runtime kind is not executable locally.',
      level: TraceLevel.warning,
      taskId: task.id,
      runId: run.id,
      packId: task.packId,
      agentId: task.agentId,
      details: <String, Object?>{
        'trace_type': 'permission_checked',
        'runtime_kind': definition.runtimeKind.name,
        'error': task.error,
      },
    );
  }

  Future<void> _tracePermissionChecked(
    RuntimeTask task,
    RuntimeRun run,
    List<String> missing,
  ) {
    return _trace(
      name: 'runtime.permission.checked',
      message: 'Pack permissions checked.',
      taskId: task.id,
      runId: run.id,
      packId: task.packId,
      agentId: task.agentId,
      details: <String, Object?>{
        'trace_type': 'permission_checked',
        'missing_permissions': missing,
        'granted': missing.isEmpty,
      },
    );
  }

  Future<void> _tracePermissionDenied(
    RuntimeTask task,
    RuntimeRun run,
    List<String> missing,
  ) {
    return _trace(
      name: 'runtime.permission.denied',
      message: 'Pack is missing required permissions.',
      level: TraceLevel.warning,
      taskId: task.id,
      runId: run.id,
      packId: task.packId,
      agentId: task.agentId,
      details: <String, Object?>{
        'trace_type': 'permission_checked',
        'missing_permissions': missing,
        'attempt': run.attempt,
      },
    );
  }

  Future<void> _tracePermissionRevoked(RuntimeTask task, String permission) {
    return _trace(
      name: 'runtime.permission.revoked',
      message: 'Queued task denied after permission revocation.',
      level: TraceLevel.warning,
      taskId: task.id,
      packId: task.packId,
      agentId: task.agentId,
      details: <String, Object?>{
        'trace_type': 'permission_checked',
        'permission': permission,
      },
    );
  }

  Future<void> _traceContextCacheInvalidationRequested(
    String packId,
    String permission,
  ) {
    return _trace(
      name: 'runtime.context_cache.invalidate_requested',
      message: 'Context cache invalidation requested after permission change.',
      packId: packId,
      details: <String, Object?>{
        'trace_type': 'event_emitted',
        'permission': permission,
      },
    );
  }

  Future<void> _traceStaleRunTerminated(
    RuntimeTask? task,
    RuntimeRun run,
    String error,
  ) {
    return _trace(
      name: 'runtime.run.stale_terminated',
      message: 'Recovered stale running run as failed.',
      level: TraceLevel.warning,
      taskId: task?.id ?? run.taskId,
      runId: run.id,
      packId: run.packId,
      agentId: run.agentId,
      details: <String, Object?>{'trace_type': 'failed', 'error': error},
    );
  }

  Future<void> _traceStaleTaskRecovered(RuntimeTask task, String error) {
    return _trace(
      name: 'runtime.task.stale_recovered',
      message: 'Recovered stale running task after its lease expired.',
      level: TraceLevel.warning,
      taskId: task.id,
      packId: task.packId,
      agentId: task.agentId,
      details: <String, Object?>{
        'trace_type': task.status == RuntimeTaskStatus.failed
            ? 'failed'
            : 'task_created',
        'status': task.status.name,
        'error': error,
      },
    );
  }

  Future<void> _traceRunApprovalPending(
    RuntimeTask task,
    RuntimeRun run,
    ApprovalPendingException error,
  ) {
    return _trace(
      name: 'runtime.run.approval_pending',
      message: 'Agent run stopped because tool approval is pending.',
      level: TraceLevel.warning,
      taskId: task.id,
      runId: run.id,
      packId: task.packId,
      agentId: task.agentId,
      details: <String, Object?>{
        'trace_type': 'approval',
        'error_code': 'approval_pending',
        'approval_request_id': error.request.id,
        'tool_name': error.request.toolName,
        'decision_state': error.decision.state.name,
      },
    );
  }
}

const _rawTraceDetailKeys = <String>{
  'raw_prompt',
  'raw_model_response',
  'raw_tool_input',
  'raw_tool_result',
  'raw_tool_failure',
};

String _safeTraceError(String value) {
  var redacted = value.replaceAllMapped(
    RegExp(
      r'((api[_-]?key|token|secret|password|authorization|credential|raw[_-]?db)\s*[:=]\s*)([^\s,;]+)',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}[redacted]',
  );
  redacted = redacted.replaceAllMapped(
    RegExp(r'\bBearer\s+[^\s,;]+', caseSensitive: false),
    (_) => 'Bearer [redacted]',
  );
  redacted = redacted.replaceAllMapped(
    RegExp(r'\b(sk|tp)-[A-Za-z0-9][A-Za-z0-9_-]{8,}\b'),
    (match) => '${match.group(1)}-[redacted]',
  );
  if (redacted.length > _maxTraceErrorLength) {
    redacted = '${redacted.substring(0, _maxTraceErrorLength)}...';
  }
  return redacted;
}

const _maxTraceErrorLength = 2048;

final class _TaskRequest {
  const _TaskRequest({
    required this.pack,
    required this.subscription,
    required this.event,
    required this.definition,
    required this.handler,
  });

  final AgentPack pack;
  final Subscription subscription;
  final WnEvent event;
  final AgentDefinition definition;
  final AgentHandler? handler;
}

final class _QueuedRequest {
  const _QueuedRequest({required this.request, required this.task});

  final _TaskRequest request;
  final RuntimeTask task;
}

final class _PermissionCheckedModelClient implements ModelClient {
  const _PermissionCheckedModelClient({
    required this.packId,
    required this.taskId,
    required this.runId,
    required this.agentId,
    required this.permissionBroker,
    required this.delegate,
    required this.trace,
  });

  final String packId;
  final String taskId;
  final String runId;
  final String agentId;
  final PermissionBroker permissionBroker;
  final ModelClient delegate;
  final _TraceRecorder trace;

  @override
  Future<ModelResponse> complete(ModelRequest request) async {
    final stopwatch = Stopwatch()..start();
    final contextKeys = request.context.keys.toList(growable: false)..sort();
    await trace(
      name: 'runtime.model.requested',
      message: 'Model completion requested.',
      taskId: taskId,
      runId: runId,
      packId: packId,
      agentId: agentId,
      details: <String, Object?>{
        'trace_type': 'model',
        'call_state': 'requested',
        'prompt_length': request.prompt.length,
        'raw_prompt': request.prompt,
        'context_keys': contextKeys,
      },
    );
    final granted = await permissionBroker.isGranted(
      packId,
      ModelPermissions.complete,
    );
    if (!granted) {
      await trace(
        name: 'runtime.model.permission_denied',
        message: 'Model completion permission denied.',
        level: TraceLevel.warning,
        taskId: taskId,
        runId: runId,
        packId: packId,
        agentId: agentId,
        details: const <String, Object?>{
          'trace_type': 'permission_checked',
          'missing_permissions': <String>[ModelPermissions.complete],
        },
      );
      throw RuntimePermissionDeniedException(
        packId: packId,
        permissions: const <String>[ModelPermissions.complete],
      );
    }
    try {
      final response = await delegate.complete(request);
      stopwatch.stop();
      await trace(
        name: 'runtime.model.completed',
        message: 'Model completion returned.',
        taskId: taskId,
        runId: runId,
        packId: packId,
        agentId: agentId,
        details: <String, Object?>{
          'trace_type': 'model',
          'call_state': 'completed',
          'prompt_length': request.prompt.length,
          'raw_prompt': request.prompt,
          'response_length': response.text.length,
          'raw_model_response': response.text,
          'duration_ms': stopwatch.elapsedMilliseconds,
          ..._modelUsageTraceDetails(response.raw),
        },
      );
      return response;
    } catch (error) {
      stopwatch.stop();
      await trace(
        name: 'runtime.model.failed',
        message: 'Model completion failed.',
        level: TraceLevel.error,
        taskId: taskId,
        runId: runId,
        packId: packId,
        agentId: agentId,
        details: <String, Object?>{
          'trace_type': 'model',
          'call_state': 'failed',
          'prompt_length': request.prompt.length,
          'raw_prompt': request.prompt,
          'duration_ms': stopwatch.elapsedMilliseconds,
          'error_type': error.runtimeType.toString(),
        },
      );
      rethrow;
    }
  }
}

JsonMap _modelUsageTraceDetails(JsonMap raw) {
  final details = <String, Object?>{};
  final providerId = _traceString(raw['provider_id']);
  final model = _traceString(raw['model']);
  if (providerId != null) {
    details['provider_id'] = providerId;
  }
  if (model != null) {
    details['model'] = model;
  }

  final usage = _traceMap(raw['usage']);
  final inputTokens =
      _traceInt(usage?['input_tokens']) ?? _traceInt(usage?['prompt_tokens']);
  final outputTokens =
      _traceInt(usage?['output_tokens']) ??
      _traceInt(usage?['completion_tokens']);
  final totalTokens = _traceInt(usage?['total_tokens']);
  if (inputTokens != null) {
    details['input_tokens'] = inputTokens;
  }
  if (outputTokens != null) {
    details['output_tokens'] = outputTokens;
  }
  if (totalTokens != null) {
    details['total_tokens'] = totalTokens;
  }

  final cachedTokens = _traceInt(usage?['cached_tokens']);
  final thoughtTokens = _traceInt(usage?['thought_tokens']);
  if (cachedTokens != null) {
    details['cached_tokens'] = cachedTokens;
  }
  if (thoughtTokens != null) {
    details['thought_tokens'] = thoughtTokens;
  }

  final estimatedCostUsd =
      _traceNum(raw['estimated_cost_usd']) ??
      _traceNum(raw['cost_usd']) ??
      _traceNum(usage?['estimated_cost_usd']) ??
      _traceNum(usage?['cost_usd']);
  if (estimatedCostUsd != null) {
    details['estimated_cost_usd'] = estimatedCostUsd;
  }
  if (usage != null) {
    details['usage_present'] = true;
  }
  return details;
}

JsonMap? _traceMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  return <String, Object?>{
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value as Object?,
  };
}

String? _traceString(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

int? _traceInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

num? _traceNum(Object? value) {
  if (value is num) {
    return value;
  }
  if (value is String) {
    return num.tryParse(value);
  }
  return null;
}

final class _RuntimeToolInvoker implements ToolInvoker {
  const _RuntimeToolInvoker({
    required this.packId,
    required this.runId,
    required this.taskId,
    required this.agentId,
    required this.permissionBroker,
    required this.toolRegistry,
    required this.runMode,
    required this.declaredTools,
    required this.approvalBroker,
    required this.idGenerator,
    required this.clock,
    required this.trace,
  });

  final String packId;
  final String runId;
  final String taskId;
  final String agentId;
  final PermissionBroker permissionBroker;
  final ToolRegistry toolRegistry;
  final RunMode runMode;
  final Set<String> declaredTools;
  final ApprovalBroker? approvalBroker;
  final WnIdGenerator idGenerator;
  final WnClock clock;
  final _TraceRecorder trace;

  @override
  Future<WnResult<JsonMap>> invokeTool(
    String name, {
    JsonMap input = const <String, Object?>{},
  }) async {
    final inputKeys = _sorted(input.keys);
    if (!declaredTools.contains(name)) {
      await trace(
        name: 'runtime.tool.undeclared',
        message: 'Tool invocation denied because the agent did not declare it.',
        level: TraceLevel.warning,
        taskId: taskId,
        runId: runId,
        packId: packId,
        agentId: agentId,
        details: <String, Object?>{
          ..._toolTraceDetails(name, null, inputKeys),
          'raw_tool_input': input,
          'error_code': 'tool_undeclared',
          'declared_tools': _sorted(declaredTools),
        },
      );
      return WnResult<JsonMap>.err(
        WnFailure(
          code: 'tool_undeclared',
          message: 'Tool is not declared by the current agent: $name',
        ),
      );
    }
    final definition = toolRegistry.lookup(name);
    await trace(
      name: 'runtime.tool.requested',
      message: 'Tool invocation requested.',
      taskId: taskId,
      runId: runId,
      packId: packId,
      agentId: agentId,
      details: <String, Object?>{
        ..._toolTraceDetails(name, definition, inputKeys),
        'raw_tool_input': input,
      },
    );
    if (definition == null) {
      await trace(
        name: 'runtime.tool.failed',
        message: 'Tool is not registered.',
        level: TraceLevel.warning,
        taskId: taskId,
        runId: runId,
        packId: packId,
        agentId: agentId,
        details: <String, Object?>{
          ..._toolTraceDetails(name, definition, inputKeys),
          'raw_tool_input': input,
          'error_code': 'tool_not_found',
        },
      );
      return WnResult<JsonMap>.err(
        WnFailure(
          code: 'tool_not_found',
          message: 'Tool is not registered: $name',
        ),
      );
    }
    final missing = await permissionBroker.missingPermissions(
      packId,
      definition.requiredPermissions,
    );
    if (missing.isNotEmpty) {
      await trace(
        name: 'runtime.tool.permission_denied',
        message: 'Tool permission denied.',
        level: TraceLevel.warning,
        taskId: taskId,
        runId: runId,
        packId: packId,
        agentId: agentId,
        details: <String, Object?>{
          ..._toolTraceDetails(name, definition, inputKeys),
          'raw_tool_input': input,
          'trace_type': 'permission_checked',
          'missing_permissions': missing,
        },
      );
      return WnResult<JsonMap>.err(
        WnFailure(
          code: 'permission_denied',
          message: 'Tool requires permissions that are not granted.',
          details: <String, Object?>{'missing_permissions': missing},
        ),
      );
    }
    final policyFailure = await _toolPolicyFailure(
      definition,
      input: input,
      inputKeys: inputKeys,
    );
    if (policyFailure != null) {
      return WnResult<JsonMap>.err(policyFailure);
    }
    final result = await toolRegistry.invoke(
      ToolInvocation(
        packId: packId,
        runId: runId,
        toolName: name,
        input: input,
      ),
    );
    await trace(
      name: result.isOk ? 'runtime.tool.completed' : 'runtime.tool.failed',
      message: result.isOk ? 'Tool invocation completed.' : 'Tool failed.',
      level: result.isOk ? TraceLevel.info : TraceLevel.warning,
      taskId: taskId,
      runId: runId,
      packId: packId,
      agentId: agentId,
      details: <String, Object?>{
        ..._toolTraceDetails(name, definition, inputKeys),
        'raw_tool_input': input,
        if (result.isOk) ...<String, Object?>{
          'result_keys': _sorted(result.value.keys),
          'raw_tool_result': result.value,
        } else ...<String, Object?>{
          'failure_message': result.failure.message,
          'raw_tool_failure': result.failure.details,
        },
        'error_code': result.isErr ? result.failure.code : null,
      },
    );
    return result;
  }

  Future<WnFailure?> _toolPolicyFailure(
    ToolDefinition definition, {
    required JsonMap input,
    required List<String> inputKeys,
  }) async {
    if (!definition.isExecutableLocally) {
      await trace(
        name: 'runtime.tool.unsupported',
        message: 'Tool execution mode is not supported by the local runtime.',
        level: TraceLevel.warning,
        taskId: taskId,
        runId: runId,
        packId: packId,
        agentId: agentId,
        details: <String, Object?>{
          ..._toolTraceDetails(definition.name, definition, inputKeys),
          'raw_tool_input': input,
          'error_code': 'unsupported_tool',
        },
      );
      return WnFailure(
        code: 'unsupported_tool',
        message:
            'This tool is declared for a deferred or disabled runtime and '
            'cannot execute locally.',
        details: _toolFailureDetails(definition, inputKeys),
      );
    }

    if (!definition.compatibleRunModes.contains(runMode)) {
      await trace(
        name: 'runtime.tool.run_mode_denied',
        message: 'Run mode is not compatible with the requested tool.',
        level: TraceLevel.warning,
        taskId: taskId,
        runId: runId,
        packId: packId,
        agentId: agentId,
        details: <String, Object?>{
          ..._toolTraceDetails(definition.name, definition, inputKeys),
          'raw_tool_input': input,
          'error_code': 'run_mode_denied',
          'denial_reason': 'incompatible_run_mode',
        },
      );
      return WnFailure(
        code: 'run_mode_denied',
        message: 'Current run mode cannot use this tool.',
        details: _toolFailureDetails(definition, inputKeys),
      );
    }

    if (runMode == RunMode.readOnly && !definition.isReadOnlySafe) {
      await trace(
        name: 'runtime.tool.run_mode_denied',
        message: 'Read-only mode denied tool invocation.',
        level: TraceLevel.warning,
        taskId: taskId,
        runId: runId,
        packId: packId,
        agentId: agentId,
        details: <String, Object?>{
          ..._toolTraceDetails(definition.name, definition, inputKeys),
          'raw_tool_input': input,
          'error_code': 'run_mode_denied',
          'denial_reason': 'read_only_mode',
        },
      );
      return WnFailure(
        code: 'run_mode_denied',
        message:
            'Read-only mode cannot run tools that mutate, export, or are high risk.',
        details: _toolFailureDetails(definition, inputKeys),
      );
    }

    if (runMode == RunMode.confirm && definition.requiresApproval) {
      return _approvalFailure(definition, input: input, inputKeys: inputKeys);
    }

    if (runMode == RunMode.auto && !definition.canAutoExecute) {
      return _approvalFailure(definition, input: input, inputKeys: inputKeys);
    }

    return null;
  }

  Future<WnFailure?> _approvalFailure(
    ToolDefinition definition, {
    required JsonMap input,
    required List<String> inputKeys,
  }) async {
    final broker = approvalBroker;
    final requestedAt = clock.now();
    final request = ApprovalRequest(
      id: idGenerator.nextId('approval'),
      packId: packId,
      agentId: agentId,
      taskId: taskId,
      runId: runId,
      toolName: definition.name,
      runMode: runMode,
      toolAccess: definition.access,
      toolRisk: definition.risk,
      isExternal: definition.external,
      requiredPermissions: _sorted(definition.requiredPermissions),
      inputKeys: inputKeys,
      createdAt: requestedAt,
      expiresAt: requestedAt.add(_approvalRequestTtl),
      sourceRefs: _sourceRefsFromInput(input),
      actionSummary: 'Approve one ${definition.name} tool invocation.',
      reason:
          'Tool requires approval for write, external, high-risk, or explicit approval-gated access.',
    );

    if (broker == null) {
      await trace(
        name: 'runtime.tool.approval_unavailable',
        message: 'Tool approval is required but no broker is available.',
        level: TraceLevel.warning,
        taskId: taskId,
        runId: runId,
        packId: packId,
        agentId: agentId,
        details: <String, Object?>{
          ..._approvalTraceDetails(request),
          'raw_tool_input': input,
          'error_code': 'approval_unavailable',
        },
      );
      return WnFailure(
        code: 'approval_unavailable',
        message:
            'Tool approval is required, but no approval broker is available.',
        details: _toolFailureDetails(definition, inputKeys),
      );
    }

    await trace(
      name: 'runtime.tool.approval_requested',
      message: 'Tool approval requested.',
      taskId: taskId,
      runId: runId,
      packId: packId,
      agentId: agentId,
      details: <String, Object?>{
        ..._approvalTraceDetails(request),
        'raw_tool_input': input,
      },
    );

    final ApprovalDecision decision;
    try {
      decision = await broker.requestApproval(request);
    } catch (error) {
      await trace(
        name: 'runtime.tool.approval_failed',
        message: 'Tool approval broker failed.',
        level: TraceLevel.warning,
        taskId: taskId,
        runId: runId,
        packId: packId,
        agentId: agentId,
        details: <String, Object?>{
          ..._approvalTraceDetails(request),
          'raw_tool_input': input,
          'error_code': 'approval_failed',
          'error_type': error.runtimeType.toString(),
        },
      );
      return WnFailure(
        code: 'approval_failed',
        message: 'Tool approval failed before execution.',
        details: _toolFailureDetails(definition, inputKeys),
      );
    }

    await trace(
      name: decision.isPending
          ? 'runtime.tool.approval_pending'
          : decision.isApproved
          ? 'runtime.tool.approval_approved'
          : 'runtime.tool.approval_denied',
      message: decision.isPending
          ? 'Tool approval is pending user review.'
          : decision.isApproved
          ? 'Tool approval granted.'
          : 'Tool approval denied.',
      level: decision.isApproved ? TraceLevel.info : TraceLevel.warning,
      taskId: taskId,
      runId: runId,
      packId: packId,
      agentId: agentId,
      details: <String, Object?>{
        ..._approvalTraceDetails(request),
        'raw_tool_input': input,
        'decision_state': decision.state.name,
      },
    );

    if (decision.isPending) {
      throw ApprovalPendingException(request: request, decision: decision);
    }

    if (decision.isApproved) {
      return null;
    }

    final failureCode = switch (decision.state) {
      ApprovalDecisionState.denied => 'approval_denied',
      ApprovalDecisionState.canceled => 'approval_canceled',
      ApprovalDecisionState.expired => 'approval_expired',
      ApprovalDecisionState.pending => 'approval_pending',
      ApprovalDecisionState.approved => 'approval_denied',
    };

    return WnFailure(
      code: failureCode,
      message: 'Tool approval did not allow execution.',
      details: _toolFailureDetails(definition, inputKeys),
    );
  }

  JsonMap _toolTraceDetails(
    String name,
    ToolDefinition? definition,
    List<String> inputKeys,
  ) {
    return <String, Object?>{
      'trace_type': 'tool',
      'tool_name': name,
      'run_mode': runMode.wireName,
      'input_keys': inputKeys,
      if (definition != null) ...<String, Object?>{
        'tool_access': definition.access.name,
        'tool_risk': definition.risk.name,
        'tool_locality': definition.locality.name,
        'tool_execution': definition.execution.name,
        'tool_approval_requirement': definition.approvalRequirement.name,
        'tool_external': definition.external,
        'tool_high_risk': definition.isHighRisk,
        'approval_required': _requiresApprovalForRunMode(definition),
        'required_permissions': _sorted(definition.requiredPermissions),
        'compatible_run_modes': _sorted(
          definition.compatibleRunModes.map((mode) => mode.wireName),
        ),
      },
    };
  }

  JsonMap _approvalTraceDetails(ApprovalRequest request) {
    return <String, Object?>{
      'trace_type': 'approval',
      'approval_request_id': request.id,
      'tool_name': request.toolName,
      'run_mode': request.runMode.wireName,
      'input_keys': request.inputKeys,
      'tool_access': request.toolAccess.name,
      'tool_risk': request.toolRisk.name,
      'tool_external': request.isExternal,
      'tool_high_risk': request.isHighRisk,
      'required_permissions': request.requiredPermissions,
      'source_refs': request.sourceRefs,
      'action_summary': request.actionSummary,
      'expires_at': request.expiresAt?.toUtc().toIso8601String(),
    };
  }

  JsonMap _toolFailureDetails(
    ToolDefinition definition,
    List<String> inputKeys,
  ) {
    return <String, Object?>{
      'tool_name': definition.name,
      'run_mode': runMode.wireName,
      'input_keys': inputKeys,
      'tool_access': definition.access.name,
      'tool_risk': definition.risk.name,
      'tool_locality': definition.locality.name,
      'tool_execution': definition.execution.name,
      'tool_approval_requirement': definition.approvalRequirement.name,
      'tool_external': definition.external,
      'tool_high_risk': definition.isHighRisk,
      'approval_required': _requiresApprovalForRunMode(definition),
      'required_permissions': _sorted(definition.requiredPermissions),
      'compatible_run_modes': _sorted(
        definition.compatibleRunModes.map((mode) => mode.wireName),
      ),
    };
  }

  bool _requiresApprovalForRunMode(ToolDefinition definition) {
    return switch (runMode) {
      RunMode.readOnly => false,
      RunMode.confirm => definition.requiresApproval,
      RunMode.auto => !definition.canAutoExecute,
    };
  }

  List<String> _sorted(Iterable<String> values) {
    return values.toList(growable: false)..sort();
  }

  List<Object?> _sourceRefsFromInput(JsonMap input) {
    final refs = <Object?>[];
    final sourceRefs = input['source_refs'];
    if (sourceRefs is Iterable) {
      for (final ref in sourceRefs) {
        if (ref is Map) {
          final kind = ref['kind'] ?? ref['source_type'];
          final id = ref['id'] ?? ref['source_id'];
          if (kind is String &&
              kind.isNotEmpty &&
              id is String &&
              id.isNotEmpty) {
            refs.add(<String, Object?>{'kind': kind, 'id': id});
          }
        }
      }
    }
    final sourceEventId = input['source_event_id'];
    if (sourceEventId is String && sourceEventId.isNotEmpty) {
      refs.add(<String, Object?>{'kind': 'event', 'id': sourceEventId});
    }
    final sourceCaptureId = input['source_capture_id'];
    if (sourceCaptureId is String && sourceCaptureId.isNotEmpty) {
      refs.add(<String, Object?>{'kind': 'capture', 'id': sourceCaptureId});
    }
    return List<Object?>.unmodifiable(refs);
  }
}

typedef _TraceRecorder =
    Future<void> Function({
      required String name,
      required String message,
      TraceLevel level,
      String? eventId,
      String? taskId,
      String? runId,
      String? packId,
      String? agentId,
      JsonMap details,
    });

const _sourceRefRequiredOutputTypes = <String>{
  WnEventTypes.memoryProposed,
  WnEventTypes.cardCreated,
  WnEventTypes.insightCreated,
  WnEventTypes.todoSuggested,
};

const _approvalRequestTtl = Duration(minutes: 15);

final class OutputEventValidationException implements Exception {
  OutputEventValidationException({
    required this.agentId,
    required this.eventType,
    required Set<String> declaredOutputEvents,
  }) : declaredOutputEvents = Set<String>.unmodifiable(declaredOutputEvents),
       message =
           'Agent $agentId emitted undeclared output event $eventType. '
           'Declared output_events: '
           '${declaredOutputEvents.isEmpty ? '<none>' : declaredOutputEvents.join(', ')}.';

  final String agentId;
  final String eventType;
  final Set<String> declaredOutputEvents;
  final String message;

  @override
  String toString() => message;
}

final class OutputSourceRefValidationException implements Exception {
  OutputSourceRefValidationException({
    required this.agentId,
    required this.eventType,
    required this.reason,
  }) : message =
           'Agent $agentId emitted derived output $eventType without valid source refs: $reason';

  final String agentId;
  final String eventType;
  final String reason;
  final String message;

  @override
  String toString() => message;
}

final class RuntimePermissionDeniedException implements Exception {
  RuntimePermissionDeniedException({
    required this.packId,
    required Iterable<String> permissions,
  }) : permissions = List<String>.unmodifiable(permissions),
       message =
           'Pack $packId is missing permissions: ${permissions.join(', ')}.';

  final String packId;
  final List<String> permissions;
  final String message;

  @override
  String toString() => message;
}

final class ApprovalPendingException implements Exception {
  ApprovalPendingException({required this.request, required this.decision})
    : message =
          'Approval pending for tool ${request.toolName} '
          'in run ${request.runId}.';

  final ApprovalRequest request;
  final ApprovalDecision decision;
  final String message;

  @override
  String toString() => message;
}
