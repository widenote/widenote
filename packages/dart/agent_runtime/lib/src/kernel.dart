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
  });

  final EventStore eventStore;
  final TraceSink traceSink;
  final PermissionBroker permissionBroker;
  final ToolRegistry toolRegistry;
  final WnIdGenerator idGenerator;
  final WnClock clock;
  final ModelClient model;
  final String deviceId;

  final Map<String, AgentPack> _packs = <String, AgentPack>{};
  final List<RuntimeTask> _tasks = <RuntimeTask>[];
  final List<RuntimeRun> _runs = <RuntimeRun>[];

  List<RuntimeTask> get tasks => List<RuntimeTask>.unmodifiable(_tasks);
  List<RuntimeRun> get runs => List<RuntimeRun>.unmodifiable(_runs);

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
    await _dispatch(event);
    return event;
  }

  Future<void> _dispatch(WnEvent event) async {
    for (final pack in _packs.values) {
      for (final subscription in pack.subscriptions) {
        if (subscription.matches(event)) {
          await _runSubscription(pack, subscription, event);
        }
      }
    }
  }

  Future<void> _runSubscription(
    AgentPack pack,
    Subscription subscription,
    WnEvent event,
  ) async {
    final handler = pack.handlerFor(subscription.agentId);
    if (handler == null) {
      await _traceMissingHandler(pack, subscription, event);
      return;
    }

    var task = _createTask(pack, subscription, event);
    _tasks.add(task);
    await _traceTaskCreated(task, event);

    final missing = await permissionBroker.missingPermissions(
      pack.id,
      pack.requiredPermissions,
    );
    if (missing.isNotEmpty) {
      task = _replaceTask(task, RuntimeTaskStatus.denied);
      final run = _createDeniedRun(task);
      _runs.add(run);
      await _tracePermissionDenied(task, run, missing);
      return;
    }

    task = _replaceTask(task, RuntimeTaskStatus.running);
    var run = _createRun(task);
    _runs.add(run);
    await _traceRunStarted(task, run);

    try {
      final context = _contextFor(task, run);
      final result = await handler.handle(context, event);
      final outputEvents = _materializeOutputs(result.events, event);
      await eventStore.appendAll(outputEvents);
      for (final output in outputEvents) {
        await _traceOutput(task, run, output);
      }
      run = _replaceRun(
        run,
        RuntimeRunStatus.succeeded,
        outputEventIds: outputEvents.map((event) => event.id).toList(),
      );
      _replaceTask(task, RuntimeTaskStatus.succeeded);
      await _traceRunCompleted(task, run);
    } catch (error) {
      run = _replaceRun(run, RuntimeRunStatus.failed, error: '$error');
      _replaceTask(task, RuntimeTaskStatus.failed);
      await _traceRunFailed(task, run, error);
    }
  }

  RuntimeTask _createTask(
    AgentPack pack,
    Subscription subscription,
    WnEvent event,
  ) {
    final now = clock.now();
    return RuntimeTask(
      id: idGenerator.nextId('task'),
      packId: pack.id,
      agentId: subscription.agentId,
      subscriptionId: subscription.id,
      triggerEventId: event.id,
      status: RuntimeTaskStatus.queued,
      createdAt: now,
      updatedAt: now,
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
    );
  }

  RuntimeRun _createDeniedRun(RuntimeTask task) {
    return RuntimeRun(
      id: idGenerator.nextId('run'),
      taskId: task.id,
      packId: task.packId,
      agentId: task.agentId,
      status: RuntimeRunStatus.denied,
      startedAt: clock.now(),
      completedAt: clock.now(),
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

  RuntimeTask _replaceTask(RuntimeTask task, RuntimeTaskStatus status) {
    final next = task.copyWith(status: status, updatedAt: clock.now());
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
      details: <String, Object?>{'error': '$error'},
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
      details: <String, Object?>{'missing_permissions': missing},
    );
  }
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
