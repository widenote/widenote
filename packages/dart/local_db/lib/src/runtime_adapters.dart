import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;

import 'database.dart';
import 'json.dart';
import 'models.dart';

final class LocalDbEventStore implements runtime.EventStore {
  const LocalDbEventStore(this._database);

  final WideNoteLocalDatabase _database;

  @override
  Future<void> append(runtime.WnEvent event) async {
    _database.eventLog.append(_eventToRecord(event));
  }

  @override
  Future<void> appendAll(Iterable<runtime.WnEvent> events) async {
    final rawDatabase = _database.rawDatabase;
    rawDatabase.execute('BEGIN IMMEDIATE;');
    try {
      for (final event in events) {
        _database.eventLog.append(_eventToRecord(event));
      }
      rawDatabase.execute('COMMIT;');
    } catch (_) {
      rawDatabase.execute('ROLLBACK;');
      rethrow;
    }
  }

  @override
  Future<List<runtime.WnEvent>> readAll() async {
    return _database.eventLog
        .readAll()
        .map(_eventFromRecord)
        .toList(growable: false);
  }

  @override
  Future<runtime.WnEvent?> readById(String id) async {
    final record = _database.eventLog.readById(id);
    return record == null ? null : _eventFromRecord(record);
  }

  @override
  Future<List<runtime.WnEvent>> readByType(String type) async {
    return _database.eventLog
        .readByType(type)
        .map(_eventFromRecord)
        .toList(growable: false);
  }
}

final class LocalDbTraceSink implements runtime.TraceSink {
  const LocalDbTraceSink(this._database);

  final WideNoteLocalDatabase _database;

  @override
  Future<void> record(runtime.RuntimeTrace trace) async {
    _database.traceEvents.insert(_traceToRecord(trace));
  }

  @override
  Future<List<runtime.RuntimeTrace>> readAll() async {
    return _database.traceEvents
        .readAll()
        .map(_traceFromRecord)
        .toList(growable: false);
  }

  @override
  Future<List<runtime.RuntimeTrace>> readByRun(String runId) async {
    return _database.traceEvents
        .readByRun(runId)
        .map(_traceFromRecord)
        .toList(growable: false);
  }
}

final class LocalDbRuntimeStore
    implements runtime.RuntimeStore, runtime.RuntimePackInstallationStore {
  const LocalDbRuntimeStore(this._database);

  final WideNoteLocalDatabase _database;

  @override
  Future<void> upsertTask(runtime.RuntimeTask task) {
    final existing =
        _database.runtimeTasks.readById(task.id) ??
        _database.runtimeTasks.readByIdentityKey(task.identityKey);
    _database.runtimeTasks.save(_taskToRecord(task, existing: existing));
    return Future<void>.value();
  }

  @override
  Future<runtime.RuntimeTask?> readTaskById(String id) {
    final record = _database.runtimeTasks.readById(id);
    return Future<runtime.RuntimeTask?>.value(
      record == null ? null : _taskFromRecord(record),
    );
  }

  @override
  Future<List<runtime.RuntimeTask>> readTasks({String? packId}) {
    final records = packId == null
        ? _database.runtimeTasks.readAll()
        : _database.runtimeTasks.readByPack(packId);
    return Future<List<runtime.RuntimeTask>>.value(
      List<runtime.RuntimeTask>.unmodifiable(records.map(_taskFromRecord)),
    );
  }

  @override
  Future<void> upsertRun(runtime.RuntimeRun run) {
    final existing = _database.runtimeRuns.readById(run.id);
    _database.runtimeRuns.save(_runToRecord(run, existing: existing));
    return Future<void>.value();
  }

  @override
  Future<runtime.RuntimeRun?> readRunById(String id) {
    final record = _database.runtimeRuns.readById(id);
    return Future<runtime.RuntimeRun?>.value(
      record == null ? null : _runFromRecord(record),
    );
  }

  @override
  Future<List<runtime.RuntimeRun>> readRuns({String? taskId, String? packId}) {
    final records = taskId == null
        ? _database.runtimeRuns.readAll()
        : _database.runtimeRuns.readByTask(taskId);
    return Future<List<runtime.RuntimeRun>>.value(
      List<runtime.RuntimeRun>.unmodifiable(
        records
            .where((record) => packId == null || record.packId == packId)
            .map(_runFromRecord),
      ),
    );
  }

  @override
  Future<void> upsertPackStatus(runtime.RuntimePackStatus status) {
    final existing = _database.packInstallations.readById(status.packId);
    final now = DateTime.now().toUtc();
    final payload = _packPayloadWithRuntimeCounts(
      existing?.payload ?? const <String, Object?>{},
      status,
    );
    final record = existing == null
        ? PackInstallationRecord(
            packId: status.packId,
            name: status.name,
            version: status.version,
            publisher: _runtimePackPublisher,
            edition: _runtimePackEdition,
            status: 'enabled',
            runtimeStatus: status.status.name,
            manifest: <String, Object?>{
              'id': status.packId,
              'name': status.name,
              'version': status.version,
            },
            payload: payload,
            installedAt: now,
            updatedAt: now,
          )
        : existing.copyWith(
            runtimeStatus: status.status.name,
            payload: payload,
            updatedAt: now,
          );
    _database.packInstallations.save(record);
    return Future<void>.value();
  }

  @override
  Future<runtime.RuntimePackStatus?> readPackStatus(String packId) {
    final record = _database.packInstallations.readById(packId);
    return Future<runtime.RuntimePackStatus?>.value(
      record == null ? null : _packStatusFromRecord(record),
    );
  }

  @override
  Future<List<runtime.RuntimePackStatus>> readPackStatuses() {
    return Future<List<runtime.RuntimePackStatus>>.value(
      List<runtime.RuntimePackStatus>.unmodifiable(
        _database.packInstallations.readAll().map(_packStatusFromRecord),
      ),
    );
  }

  @override
  Future<void> upsertPackInstallation(
    runtime.RuntimePackInstallation installation,
  ) {
    final existing = _database.packInstallations.readById(installation.packId);
    final now = installation.updatedAt.toUtc();
    final payload = <String, Object?>{
      ...?existing?.payload,
      if (installation.reason != null) 'status_reason': installation.reason,
    };
    final record = existing == null
        ? PackInstallationRecord(
            packId: installation.packId,
            name: installation.packId,
            version: '0.0.0',
            publisher: _runtimePackPublisher,
            edition: _runtimePackEdition,
            status: installation.status.name,
            installedAt: now,
            updatedAt: now,
            payload: payload,
          )
        : existing.copyWith(
            status: installation.status.name,
            payload: payload,
            updatedAt: now,
          );
    _database.packInstallations.save(record);
    return Future<void>.value();
  }

  @override
  Future<runtime.RuntimePackInstallation?> readPackInstallation(String packId) {
    final record = _database.packInstallations.readById(packId);
    if (record == null) {
      return Future<runtime.RuntimePackInstallation?>.value(null);
    }
    return Future<runtime.RuntimePackInstallation?>.value(
      runtime.RuntimePackInstallation(
        packId: record.packId,
        status: record.status == runtime.PackInstallationStatus.enabled.name
            ? runtime.PackInstallationStatus.enabled
            : runtime.PackInstallationStatus.disabled,
        updatedAt: record.updatedAt,
        reason: _optionalRuntimeString(record.payload['status_reason']),
      ),
    );
  }

  runtime.RuntimePackStatus _packStatusFromRecord(
    PackInstallationRecord record,
  ) {
    final tasks = _database.runtimeTasks.readByPack(record.packId);
    final taskCount = tasks.length;
    final queuedCount = _countTaskStatuses(tasks, const <String>{
      'queued',
      'waiting',
    });
    final runningCount = _countTaskStatuses(tasks, const <String>{'running'});
    final succeededCount = _countTaskStatuses(tasks, const <String>{
      'succeeded',
    });
    final failedCount = _countTaskStatuses(tasks, const <String>{'failed'});
    final deniedCount = _countTaskStatuses(tasks, const <String>{'denied'});
    final canceledCount = _countTaskStatuses(tasks, const <String>{'canceled'});
    final blockedCount = _countTaskStatuses(tasks, const <String>{'blocked'});

    return runtime.RuntimePackStatus(
      packId: record.packId,
      version: record.version,
      name: record.name,
      status: _runtimePackStatusKind(record.runtimeStatus),
      taskCount: _runtimePackCount(record.payload, 'task_count', taskCount),
      queuedCount: _runtimePackCount(
        record.payload,
        'queued_count',
        queuedCount,
      ),
      runningCount: _runtimePackCount(
        record.payload,
        'running_count',
        runningCount,
      ),
      succeededCount: _runtimePackCount(
        record.payload,
        'succeeded_count',
        succeededCount,
      ),
      failedCount: _runtimePackCount(
        record.payload,
        'failed_count',
        failedCount,
      ),
      deniedCount: _runtimePackCount(
        record.payload,
        'denied_count',
        deniedCount,
      ),
      canceledCount: _runtimePackCount(
        record.payload,
        'canceled_count',
        canceledCount,
      ),
      blockedCount: _runtimePackCount(
        record.payload,
        'blocked_count',
        blockedCount,
      ),
    );
  }
}

String? _optionalRuntimeString(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

final class LocalDbPermissionStore implements runtime.PermissionStore {
  const LocalDbPermissionStore(this._database);

  final WideNoteLocalDatabase _database;

  @override
  Future<void> upsert(runtime.PermissionDecision decision) {
    final existing = _database.permissionGrants.readByPackAndPermission(
      decision.packId,
      decision.permission,
    );
    _database.permissionGrants.save(
      _permissionDecisionToRecord(decision, existing: existing),
    );
    return Future<void>.value();
  }

  @override
  Future<runtime.PermissionDecision?> read(String packId, String permission) {
    final record = _database.permissionGrants.readByPackAndPermission(
      packId,
      permission,
    );
    return Future<runtime.PermissionDecision?>.value(
      record == null ? null : _permissionDecisionFromRecord(record),
    );
  }

  @override
  Future<List<runtime.PermissionDecision>> readForPack(String packId) {
    return Future<List<runtime.PermissionDecision>>.value(
      List<runtime.PermissionDecision>.unmodifiable(
        _database.permissionGrants
            .readByPack(packId)
            .map(_permissionDecisionFromRecord),
      ),
    );
  }
}

final class LocalDbApprovalStore implements runtime.ApprovalStore {
  const LocalDbApprovalStore(this._database);

  final WideNoteLocalDatabase _database;

  @override
  Future<void> saveRequest(runtime.ApprovalRequest request) {
    final existing = _database.runtimeApprovals.readById(request.id);
    _database.runtimeApprovals.save(
      _approvalRequestToRecord(request, existing: existing),
    );
    return Future<void>.value();
  }

  @override
  Future<runtime.ApprovalRequest?> readRequest(String id) {
    final record = _database.runtimeApprovals.readById(id);
    return Future<runtime.ApprovalRequest?>.value(
      record == null ? null : _approvalRequestFromRecord(record),
    );
  }

  @override
  Future<List<runtime.ApprovalRequest>> readPending({
    DateTime? now,
    String? packId,
    String? runId,
  }) {
    return Future<List<runtime.ApprovalRequest>>.value(
      List<runtime.ApprovalRequest>.unmodifiable(
        _database.runtimeApprovals
            .readPending(now: now, packId: packId, runId: runId)
            .map(_approvalRequestFromRecord),
      ),
    );
  }

  @override
  Future<void> saveDecision(runtime.ApprovalDecision decision) {
    final existing = _database.runtimeApprovals.readById(decision.requestId);
    if (existing == null) {
      throw StateError('Approval request not found: ${decision.requestId}');
    }
    switch (decision.state) {
      case runtime.ApprovalDecisionState.pending:
        _database.runtimeApprovals.save(
          existing.copyWith(
            status: 'pending',
            decidedAt: decision.decidedAt,
            reason: decision.reason,
            clearDecision: true,
          ),
        );
      case runtime.ApprovalDecisionState.approved:
        _database.runtimeApprovals.approveOnce(
          decision.requestId,
          reason: decision.reason,
          decidedAt: decision.decidedAt,
        );
      case runtime.ApprovalDecisionState.denied:
        _database.runtimeApprovals.deny(
          decision.requestId,
          reason: decision.reason,
          decidedAt: decision.decidedAt,
        );
      case runtime.ApprovalDecisionState.canceled:
        _database.runtimeApprovals.cancel(
          decision.requestId,
          reason: decision.reason,
          decidedAt: decision.decidedAt,
        );
      case runtime.ApprovalDecisionState.expired:
        _database.runtimeApprovals.expire(
          decision.requestId,
          reason: decision.reason,
          decidedAt: decision.decidedAt,
        );
    }
    return Future<void>.value();
  }

  @override
  Future<runtime.ApprovalDecision?> readDecision(String requestId) {
    final record = _database.runtimeApprovals.readById(requestId);
    return Future<runtime.ApprovalDecision?>.value(
      record == null ? null : _approvalDecisionFromRecord(record),
    );
  }
}

EventLogEntry _eventToRecord(runtime.WnEvent event) {
  return EventLogEntry(
    id: event.id,
    type: event.type,
    schemaVersion: event.schemaVersion,
    actor: event.actor.name,
    privacy: event.privacy.wireName,
    subjectRef: event.subjectRef?.toJson() ?? const <String, Object?>{},
    packId: event.packId,
    agentId: event.agentId,
    deviceId: event.deviceId,
    causationId: event.causationId,
    correlationId: event.correlationId,
    payload: event.payload,
    createdAt: event.createdAt,
  );
}

runtime.WnEvent _eventFromRecord(EventLogEntry record) {
  return runtime.WnEvent(
    id: record.id,
    type: record.type,
    schemaVersion: record.schemaVersion,
    actor: _actorFromRecord(record.actor),
    packId: record.packId,
    agentId: record.agentId,
    subjectRef: _subjectRefFromRecord(record),
    payload: record.payload,
    privacy: runtime.WnPrivacy.fromWireName(record.privacy),
    causationId: record.causationId,
    correlationId: record.correlationId,
    deviceId: record.deviceId ?? 'unknown-device',
    createdAt: record.createdAt,
  );
}

RuntimeTaskRecord _taskToRecord(
  runtime.RuntimeTask task, {
  RuntimeTaskRecord? existing,
}) {
  return RuntimeTaskRecord(
    id: existing?.id ?? task.id,
    schemaVersion: existing?.schemaVersion ?? 1,
    packId: task.packId,
    packVersion: task.packVersion,
    agentId: task.agentId,
    handlerId: task.handlerRole,
    subscriptionId: task.subscriptionId,
    triggerEventId: task.triggerEventId,
    identityKey: task.identityKey,
    status: task.status.name,
    dependencyTaskIds: <Object?>[...task.dependencyTaskIds],
    missingDependencyIds: <Object?>[...task.missingDependencyIds],
    attempts: task.attempts,
    maxAttempts: task.maxAttempts,
    leaseOwner: existing?.leaseOwner,
    leasedUntil: existing?.leasedUntil,
    error: task.error,
    payload: existing?.payload ?? const <String, Object?>{},
    createdAt: existing?.createdAt ?? task.createdAt,
    updatedAt: task.updatedAt,
  );
}

runtime.RuntimeTask _taskFromRecord(RuntimeTaskRecord record) {
  return runtime.RuntimeTask(
    id: record.id,
    identityKey: record.effectiveIdentityKey,
    packId: record.packId,
    packVersion: record.packVersion,
    agentId: record.agentId,
    handlerRole: record.handlerId,
    subscriptionId: record.subscriptionId,
    triggerEventId: record.triggerEventId,
    status: _runtimeTaskStatus(record.status),
    dependencyTaskIds: _requiredStringList(
      record.dependencyTaskIds,
      'runtime_tasks.dependency_task_ids_json',
    ),
    missingDependencyIds: _requiredStringList(
      record.missingDependencyIds,
      'runtime_tasks.missing_dependency_ids_json',
    ),
    attempts: record.attempts,
    maxAttempts: record.maxAttempts,
    error: record.error,
    createdAt: record.createdAt,
    updatedAt: record.updatedAt,
  );
}

RuntimeRunRecord _runToRecord(
  runtime.RuntimeRun run, {
  RuntimeRunRecord? existing,
}) {
  return RuntimeRunRecord(
    id: run.id,
    schemaVersion: existing?.schemaVersion ?? 1,
    taskId: run.taskId,
    packId: run.packId,
    packVersion: run.packVersion,
    agentId: run.agentId,
    handlerId: existing?.handlerId ?? run.agentId,
    status: run.status.name,
    attempt: run.attempt,
    outputEventIds: <Object?>[...run.outputEventIds],
    error: run.error,
    payload: _runPayload(
      existing?.payload ?? const <String, Object?>{},
      run.runMode,
      run.leaseExpiresAt,
    ),
    startedAt: run.startedAt,
    completedAt: run.completedAt,
  );
}

runtime.RuntimeRun _runFromRecord(RuntimeRunRecord record) {
  return runtime.RuntimeRun(
    id: record.id,
    taskId: record.taskId,
    packId: record.packId,
    packVersion: record.packVersion,
    agentId: record.agentId,
    status: _runtimeRunStatus(record.status),
    startedAt: record.startedAt,
    attempt: record.attempt,
    runMode: _runtimeRunModeFromPayload(record.payload),
    completedAt: record.completedAt,
    leaseExpiresAt: _dateTimeFromJson(
      record.payload[_runtimeRunLeaseExpiresAtKey],
    ),
    outputEventIds: _requiredStringList(
      record.outputEventIds,
      'runtime_runs.output_event_ids_json',
    ),
    error: record.error,
  );
}

TraceEventRecord _traceToRecord(runtime.RuntimeTrace trace) {
  return TraceEventRecord(
    id: trace.id,
    name: trace.name,
    level: trace.level.name,
    traceTypeOverride: _schemaTraceType(trace.name),
    runIdOverride: trace.runId,
    severityOverride: _schemaSeverity(trace.level),
    message: trace.message,
    sourceEventId: trace.eventId,
    sourceRunId: trace.runId,
    sourceTaskId: trace.taskId,
    packId: trace.packId,
    agentId: trace.agentId,
    status: trace.level == runtime.TraceLevel.error ? 'error' : 'ok',
    payload: trace.details,
    createdAt: trace.createdAt,
  );
}

runtime.RuntimeTrace _traceFromRecord(TraceEventRecord record) {
  return runtime.RuntimeTrace(
    id: record.id,
    name: record.name,
    message: record.message,
    level: _traceLevelFromRecord(record.level),
    createdAt: record.createdAt,
    eventId: record.sourceEventId,
    taskId: record.sourceTaskId,
    runId: record.sourceRunId,
    packId: record.packId,
    agentId: record.agentId,
    details: record.payload,
  );
}

PermissionGrantRecord _permissionDecisionToRecord(
  runtime.PermissionDecision decision, {
  PermissionGrantRecord? existing,
}) {
  final grantedAt = switch (decision.state) {
    runtime.PermissionDecisionState.granted => decision.updatedAt,
    runtime.PermissionDecisionState.denied => null,
    runtime.PermissionDecisionState.revoked => existing?.grantedAt,
  };
  final revokedAt = switch (decision.state) {
    runtime.PermissionDecisionState.granted ||
    runtime.PermissionDecisionState.denied => null,
    runtime.PermissionDecisionState.revoked => decision.updatedAt,
  };

  return PermissionGrantRecord(
    id:
        existing?.id ??
        _permissionGrantId(decision.packId, decision.permission),
    schemaVersion: existing?.schemaVersion ?? 1,
    packId: decision.packId,
    permissionId: decision.permission,
    status: decision.state.name,
    grantKind: existing?.grantKind ?? 'user',
    sourceEventId: existing?.sourceEventId,
    grantedAt: grantedAt,
    revokedAt: revokedAt,
    reason: decision.reason,
    payload: existing?.payload ?? const <String, Object?>{},
    createdAt: existing?.createdAt ?? decision.updatedAt,
    updatedAt: decision.updatedAt,
  );
}

runtime.PermissionDecision _permissionDecisionFromRecord(
  PermissionGrantRecord record,
) {
  return runtime.PermissionDecision(
    packId: record.packId,
    permission: record.permissionId,
    state: _permissionDecisionState(record.status),
    updatedAt: record.updatedAt,
    reason: record.reason,
  );
}

RuntimeApprovalRecord _approvalRequestToRecord(
  runtime.ApprovalRequest request, {
  RuntimeApprovalRecord? existing,
}) {
  return RuntimeApprovalRecord(
    id: request.id,
    schemaVersion: existing?.schemaVersion ?? 1,
    packId: request.packId,
    agentId: request.agentId,
    taskId: request.taskId,
    runId: request.runId,
    toolName: request.toolName,
    runMode: request.runMode.wireName,
    toolAccess: request.toolAccess.name,
    toolRisk: request.toolRisk.name,
    isExternal: request.isExternal,
    requiredPermissions: <Object?>[...request.requiredPermissions],
    inputKeys: <Object?>[...request.inputKeys],
    sourceRefs: <Object?>[...request.sourceRefs],
    actionSummary: request.actionSummary ?? '',
    status: existing?.status ?? 'pending',
    requestedAt: request.requestedAt,
    expiresAt: request.expiresAt,
    decidedAt: existing?.decidedAt,
    decision: existing?.decision,
    reason: existing?.reason ?? request.reason,
    payload: existing?.payload ?? const <String, Object?>{},
  );
}

runtime.ApprovalRequest _approvalRequestFromRecord(
  RuntimeApprovalRecord record,
) {
  return runtime.ApprovalRequest(
    id: record.id,
    packId: record.packId,
    agentId: record.agentId,
    taskId: record.taskId,
    runId: record.runId,
    toolName: record.toolName,
    runMode: runtime.runModeFromWireName(record.runMode),
    toolAccess: _toolAccess(record.toolAccess),
    toolRisk: _toolRisk(record.toolRisk),
    isExternal: record.isExternal,
    requiredPermissions: _requiredStringList(
      record.requiredPermissions,
      'runtime_approval_requests.required_permissions_json',
    ),
    inputKeys: _requiredStringList(
      record.inputKeys,
      'runtime_approval_requests.input_keys_json',
    ),
    sourceRefs: record.sourceRefs,
    actionSummary: record.actionSummary.isEmpty ? null : record.actionSummary,
    createdAt: record.requestedAt,
    expiresAt: record.expiresAt,
    reason: record.reason,
  );
}

runtime.ApprovalDecision _approvalDecisionFromRecord(
  RuntimeApprovalRecord record,
) {
  return switch (record.status) {
    'pending' => runtime.ApprovalDecision.pending(
      requestId: record.id,
      reason: record.reason,
      decidedAt: record.decidedAt,
    ),
    'approved' => runtime.ApprovalDecision.approved(
      requestId: record.id,
      reason: record.reason,
      decidedAt: record.decidedAt,
    ),
    'denied' => runtime.ApprovalDecision.denied(
      requestId: record.id,
      reason: record.reason,
      decidedAt: record.decidedAt,
    ),
    'canceled' => runtime.ApprovalDecision.canceled(
      requestId: record.id,
      reason: record.reason,
      decidedAt: record.decidedAt,
    ),
    'expired' => runtime.ApprovalDecision.expired(
      requestId: record.id,
      reason: record.reason,
      decidedAt: record.decidedAt,
    ),
    _ => throw StateError('Unknown approval status: ${record.status}'),
  };
}

runtime.ToolAccess _toolAccess(String value) {
  return _enumByName(runtime.ToolAccess.values, value, 'tool access');
}

runtime.ToolRisk _toolRisk(String value) {
  return _enumByName(runtime.ToolRisk.values, value, 'tool risk');
}

runtime.WnActor _actorFromRecord(String value) {
  return runtime.WnActor.values.firstWhere(
    (actor) => actor.name == value,
    orElse: () => runtime.WnActor.system,
  );
}

runtime.SubjectRef? _subjectRefFromRecord(EventLogEntry record) {
  final kind = record.subjectRefKind;
  final id = record.subjectRefId;
  if (kind == null || id == null) {
    return null;
  }
  return runtime.SubjectRef(kind: kind, id: id);
}

runtime.RuntimeTaskStatus _runtimeTaskStatus(String value) {
  return _enumByName(
    runtime.RuntimeTaskStatus.values,
    value,
    'runtime task status',
  );
}

runtime.RuntimeRunStatus _runtimeRunStatus(String value) {
  return _enumByName(
    runtime.RuntimeRunStatus.values,
    value,
    'runtime run status',
  );
}

runtime.RuntimePackStatusKind _runtimePackStatusKind(String value) {
  return _enumByName(
    runtime.RuntimePackStatusKind.values,
    value,
    'runtime pack status',
  );
}

runtime.PermissionDecisionState _permissionDecisionState(String value) {
  return _enumByName(
    runtime.PermissionDecisionState.values,
    value,
    'permission decision state',
  );
}

runtime.TraceLevel _traceLevelFromRecord(String value) {
  return runtime.TraceLevel.values.firstWhere(
    (level) => level.name == value,
    orElse: () => runtime.TraceLevel.info,
  );
}

T _enumByName<T extends Enum>(List<T> values, String value, String label) {
  for (final candidate in values) {
    if (candidate.name == value) {
      return candidate;
    }
  }
  throw StateError('Unknown $label: $value');
}

List<String> _requiredStringList(JsonList values, String fieldName) {
  final strings = <String>[];
  for (final value in values) {
    if (value is! String) {
      throw StateError(
        '$fieldName must contain only strings; found ${value.runtimeType}.',
      );
    }
    strings.add(value);
  }
  return List<String>.unmodifiable(strings);
}

JsonMap _runPayload(
  JsonMap payload,
  runtime.RunMode runMode,
  DateTime? leaseExpiresAt,
) {
  final next = <String, Object?>{...payload};
  next[_runtimeRunModeKey] = runMode.name;
  if (leaseExpiresAt == null) {
    next.remove(_runtimeRunLeaseExpiresAtKey);
  } else {
    next[_runtimeRunLeaseExpiresAtKey] = leaseExpiresAt
        .toUtc()
        .toIso8601String();
  }
  return next;
}

runtime.RunMode _runtimeRunModeFromPayload(JsonMap payload) {
  final value = payload[_runtimeRunModeKey];
  if (value == null) {
    return runtime.RunMode.auto;
  }
  if (value is String) {
    final normalized = value.replaceAll('-', '_');
    return switch (normalized) {
      'read_only' || 'readOnly' => runtime.RunMode.readOnly,
      'confirm' => runtime.RunMode.confirm,
      'auto' => runtime.RunMode.auto,
      _ => throw StateError('Unknown runtime run mode: $value'),
    };
  }
  throw StateError('$_runtimeRunModeKey must be a string.');
}

DateTime? _dateTimeFromJson(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! String || value.isEmpty) {
    throw StateError(
      '$_runtimeRunLeaseExpiresAtKey must be a non-empty ISO-8601 string.',
    );
  }
  return DateTime.parse(value).toUtc();
}

JsonMap _packPayloadWithRuntimeCounts(
  JsonMap payload,
  runtime.RuntimePackStatus status,
) {
  return <String, Object?>{
    ...payload,
    _runtimePackCountsKey: <String, Object?>{
      'task_count': status.taskCount,
      'queued_count': status.queuedCount,
      'running_count': status.runningCount,
      'succeeded_count': status.succeededCount,
      'failed_count': status.failedCount,
      'denied_count': status.deniedCount,
      'canceled_count': status.canceledCount,
      'blocked_count': status.blockedCount,
    },
  };
}

int _runtimePackCount(JsonMap payload, String key, int fallback) {
  final counts = payload[_runtimePackCountsKey];
  if (counts is Map) {
    final value = counts[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
  }
  return fallback;
}

int _countTaskStatuses(List<RuntimeTaskRecord> tasks, Set<String> statuses) {
  return tasks.where((task) => statuses.contains(task.status)).length;
}

String _permissionGrantId(String packId, String permission) {
  return 'permission:$packId::$permission';
}

String _schemaSeverity(runtime.TraceLevel level) {
  return switch (level) {
    runtime.TraceLevel.debug => 'debug',
    runtime.TraceLevel.info => 'info',
    runtime.TraceLevel.warning => 'warn',
    runtime.TraceLevel.error => 'error',
  };
}

String _schemaTraceType(String runtimeName) {
  if (runtimeName.startsWith('runtime.model.') ||
      runtimeName == 'chat.model.failed') {
    return 'model';
  }
  if (runtimeName.startsWith('runtime.tool.approval') ||
      runtimeName == 'runtime.run.approval_pending') {
    return 'approval';
  }
  return switch (runtimeName) {
    'runtime.run.started' => 'run_started',
    'runtime.run.completed' => 'run_completed',
    'runtime.event.appended' => 'event_received',
    'runtime.handler.output' => 'event_emitted',
    'runtime.permission.denied' => 'permission_checked',
    'runtime.run.failed' => 'error',
    _ => 'event_received',
  };
}

const _runtimeRunLeaseExpiresAtKey = 'runtime_run_lease_expires_at';
const _runtimeRunModeKey = 'runtime_run_mode';
const _runtimePackCountsKey = 'runtime_status_counts';
const _runtimePackEdition = 'runtime';
const _runtimePackPublisher = 'runtime';
