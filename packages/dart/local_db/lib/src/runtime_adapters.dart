import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;

import 'database.dart';
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

runtime.TraceLevel _traceLevelFromRecord(String value) {
  return runtime.TraceLevel.values.firstWhere(
    (level) => level.name == value,
    orElse: () => runtime.TraceLevel.info,
  );
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
