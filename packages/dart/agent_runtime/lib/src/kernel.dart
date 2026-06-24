import 'package:widenote_core/widenote_core.dart';

import 'event.dart';
import 'model.dart';
import 'pack.dart';
import 'permissions.dart';
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
    this.autoDrain = true,
  });

  final EventStore eventStore;
  final TraceSink traceSink;
  final PermissionBroker permissionBroker;
  final ToolRegistry toolRegistry;
  final WnIdGenerator idGenerator;
  final WnClock clock;
  final ModelClient model;
  final String deviceId;
  final bool autoDrain;

  final Map<String, AgentPack> _packs = <String, AgentPack>{};
  final List<RuntimeTask> _tasks = <RuntimeTask>[];
  final List<RuntimeRun> _runs = <RuntimeRun>[];

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
    _packs[pack.id] = pack;
  }

  Future<WnEvent> publish(WnEventDraft draft) async {
    final event = _materialize(draft);
    await eventStore.append(event);
    await _trace(
      name: 'runtime.event.appended',
      message: 'Event appended.',
      eventId: event.id,
      details: <String, Object?>{'type': event.type},
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
      final task = _nextRunnableTask();
      if (task != null) {
        await _executeTask(task);
        executed += 1;
        continue;
      }

      final blocked = _nextBlockedTask();
      if (blocked != null) {
        final latest = _replaceTask(
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

  Future<bool> cancelTask(String taskId, {String reason = 'user_requested'}) {
    final task = _taskById(taskId);
    if (task == null || task.status.isTerminal) {
      return Future<bool>.value(false);
    }
    if (task.status == RuntimeTaskStatus.running) {
      return Future<bool>.value(false);
    }

    final next = _replaceTask(task, RuntimeTaskStatus.canceled, error: reason);
    return _traceTaskCanceled(next, reason).then((_) => true);
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
    final next = _replaceTask(task, status, attempts: 0, clearError: true);
    await _traceTaskRetryRequested(next);
    if (drain) {
      await drainQueue();
    }
    return true;
  }

  Future<void> _enqueueMatching(WnEvent event) async {
    final requests = <_TaskRequest>[];
    for (final pack in _packs.values) {
      for (final subscription in pack.subscriptions) {
        if (!subscription.matches(event)) {
          continue;
        }

        final definition = pack.definitionFor(subscription.agentId);
        final handler = pack.handlerFor(subscription.agentId);
        if (handler == null &&
            definition.runtimeKind != AgentRuntimeKind.script) {
          await _traceMissingHandler(pack, subscription, event);
          continue;
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
      final task = _createTask(request);
      _tasks.add(task);
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
            taskIdsBySubscription[_dependencyKey(
              queued.request.pack.id,
              dependency,
            )];
        if (taskId == null) {
          missingDependencyIds.add(dependency);
          continue;
        }
        dependencyIds.add(taskId);
      }

      final nextStatus = missingDependencyIds.isNotEmpty
          ? RuntimeTaskStatus.blocked
          : dependencyIds.isEmpty
          ? RuntimeTaskStatus.queued
          : RuntimeTaskStatus.waiting;
      final next = _replaceTask(
        queued.task,
        nextStatus,
        dependencyTaskIds: dependencyIds,
        missingDependencyIds: missingDependencyIds,
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
      final blocked = _replaceTask(
        queuedTask,
        RuntimeTaskStatus.blocked,
        error: 'Registered pack is missing: ${queuedTask.packId}',
      );
      await _traceTaskBlocked(blocked);
      return;
    }

    final definition = pack.definitionFor(queuedTask.agentId);
    final task = _replaceTask(
      queuedTask,
      RuntimeTaskStatus.running,
      attempts: queuedTask.attempts + 1,
      clearError: true,
    );
    final run = _createRun(task);
    _runs.add(run);

    final unsupportedRuntime = _unsupportedRuntimeReason(definition);
    if (unsupportedRuntime != null) {
      final deniedTask = _replaceTask(
        task,
        RuntimeTaskStatus.denied,
        error: unsupportedRuntime,
      );
      final deniedRun = _replaceRun(
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
    if (missing.isNotEmpty) {
      final deniedTask = _replaceTask(task, RuntimeTaskStatus.denied);
      final deniedRun = _replaceRun(run, RuntimeRunStatus.denied);
      await _tracePermissionDenied(deniedTask, deniedRun, missing);
      return;
    }

    await _traceRunStarted(task, run);

    try {
      final context = _contextFor(task, run);
      final handler = pack.handlerFor(task.agentId);
      if (handler == null) {
        throw StateError('Agent handler missing: ${task.agentId}');
      }
      final triggerEvent = await eventStore.readById(task.triggerEventId);
      if (triggerEvent == null) {
        throw StateError('Trigger event missing: ${task.triggerEventId}');
      }
      final result = await handler.handle(context, triggerEvent);
      final outputEvents = _materializeOutputs(result.events, triggerEvent);
      await eventStore.appendAll(outputEvents);
      for (final output in outputEvents) {
        await _traceOutput(task, run, output);
      }
      final succeededRun = _replaceRun(
        run,
        RuntimeRunStatus.succeeded,
        outputEventIds: outputEvents.map((event) => event.id).toList(),
      );
      final succeededTask = _replaceTask(task, RuntimeTaskStatus.succeeded);
      await _traceRunCompleted(succeededTask, succeededRun);
    } catch (error) {
      final failedRun = _replaceRun(
        run,
        RuntimeRunStatus.failed,
        error: '$error',
      );
      if (task.canRetry) {
        final retryTask = _replaceTask(
          task,
          RuntimeTaskStatus.queued,
          error: '$error',
        );
        await _traceRunFailed(retryTask, failedRun, error);
        await _traceTaskRetryQueued(retryTask);
        return;
      }

      final failedTask = _replaceTask(
        task,
        RuntimeTaskStatus.failed,
        error: '$error',
      );
      await _traceRunFailed(failedTask, failedRun, error);
    }
  }

  RuntimeTask? _nextRunnableTask() {
    for (final task in _tasks) {
      if (task.status != RuntimeTaskStatus.queued &&
          task.status != RuntimeTaskStatus.waiting) {
        continue;
      }
      if (_dependenciesSucceeded(task)) {
        return task;
      }
    }
    return null;
  }

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
      AgentRuntimeKind.native ||
      AgentRuntimeKind.declarative ||
      AgentRuntimeKind.remote => null,
      AgentRuntimeKind.script =>
        'Script execution is not available without an accepted sandbox.',
    };
  }

  String _dependencyKey(String packId, String subscriptionId) {
    return '$packId::$subscriptionId';
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

  RuntimeTask _createTask(_TaskRequest request) {
    final now = clock.now();
    return RuntimeTask(
      id: idGenerator.nextId('task'),
      packId: request.pack.id,
      agentId: request.subscription.agentId,
      subscriptionId: request.subscription.id,
      triggerEventId: request.event.id,
      status: RuntimeTaskStatus.queued,
      createdAt: now,
      updatedAt: now,
      maxAttempts: request.definition.retryPolicy.normalizedMaxAttempts,
    );
  }

  RuntimeRun _createRun(RuntimeTask task) {
    return RuntimeRun(
      id: idGenerator.nextId('run'),
      taskId: task.id,
      packId: task.packId,
      agentId: task.agentId,
      status: RuntimeRunStatus.running,
      startedAt: clock.now(),
      attempt: task.attempts,
    );
  }

  AgentContext _contextFor(RuntimeTask task, RuntimeRun run) {
    return AgentContext(
      packId: task.packId,
      agentId: task.agentId,
      task: task,
      run: run,
      model: _PermissionCheckedModelClient(
        packId: task.packId,
        permissionBroker: permissionBroker,
        delegate: model,
      ),
      tools: _RuntimeToolInvoker(
        packId: task.packId,
        runId: run.id,
        permissionBroker: permissionBroker,
        toolRegistry: toolRegistry,
      ),
    );
  }

  RuntimeTask _replaceTask(
    RuntimeTask task,
    RuntimeTaskStatus status, {
    List<String>? dependencyTaskIds,
    List<String>? missingDependencyIds,
    int? attempts,
    int? maxAttempts,
    String? error,
    bool clearError = false,
  }) {
    final next = task.copyWith(
      status: status,
      updatedAt: clock.now(),
      dependencyTaskIds: dependencyTaskIds,
      missingDependencyIds: missingDependencyIds,
      attempts: attempts,
      maxAttempts: maxAttempts,
      error: error,
      clearError: clearError,
    );
    final index = _tasks.indexWhere((candidate) => candidate.id == task.id);
    if (index >= 0) {
      _tasks[index] = next;
    }
    return next;
  }

  RuntimeRun _replaceRun(
    RuntimeRun run,
    RuntimeRunStatus status, {
    List<String>? outputEventIds,
    String? error,
  }) {
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
    return next;
  }

  List<WnEvent> _materializeOutputs(
    Iterable<WnEventDraft> drafts,
    WnEvent causedBy,
  ) {
    return drafts
        .map((draft) => _materialize(draft, causedBy: causedBy))
        .toList();
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
        details: immutableJsonMap(details),
      ),
    );
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
        'subscription_id': task.subscriptionId,
        'dependency_task_ids': task.dependencyTaskIds,
        'max_attempts': task.maxAttempts,
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
      details: <String, Object?>{'dependency_task_ids': task.dependencyTaskIds},
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
      details: <String, Object?>{'reason': reason},
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
        'dependency_task_ids': task.dependencyTaskIds,
        'missing_dependency_ids': task.missingDependencyIds,
        'error': task.error,
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
      details: <String, Object?>{'max_attempts': task.maxAttempts},
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
      details: <String, Object?>{'attempt': run.attempt},
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
      details: <String, Object?>{'type': output.type},
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
        'output_event_count': run.outputEventIds.length,
        'attempt': run.attempt,
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
      details: <String, Object?>{'error': '$error', 'attempt': run.attempt},
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
        'runtime_kind': definition.runtimeKind.name,
        'error': task.error,
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
        'missing_permissions': missing,
        'attempt': run.attempt,
      },
    );
  }
}

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
    required this.permissionBroker,
    required this.delegate,
  });

  final String packId;
  final PermissionBroker permissionBroker;
  final ModelClient delegate;

  @override
  Future<ModelResponse> complete(ModelRequest request) async {
    final granted = await permissionBroker.isGranted(
      packId,
      ModelPermissions.complete,
    );
    if (!granted) {
      throw StateError(
        'Pack $packId is missing ${ModelPermissions.complete} permission.',
      );
    }
    return delegate.complete(request);
  }
}

final class _RuntimeToolInvoker implements ToolInvoker {
  const _RuntimeToolInvoker({
    required this.packId,
    required this.runId,
    required this.permissionBroker,
    required this.toolRegistry,
  });

  final String packId;
  final String runId;
  final PermissionBroker permissionBroker;
  final ToolRegistry toolRegistry;

  @override
  Future<WnResult<JsonMap>> invokeTool(
    String name, {
    JsonMap input = const <String, Object?>{},
  }) async {
    final definition = toolRegistry.lookup(name);
    if (definition == null) {
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
      return WnResult<JsonMap>.err(
        WnFailure(
          code: 'permission_denied',
          message: 'Tool requires permissions that are not granted.',
          details: <String, Object?>{'missing_permissions': missing},
        ),
      );
    }
    return toolRegistry.invoke(
      ToolInvocation(
        packId: packId,
        runId: runId,
        toolName: name,
        input: input,
      ),
    );
  }
}
