part of 'daos.dart';

final class TraceEventsDao {
  const TraceEventsDao(this._database);

  final Database _database;

  void insert(TraceEventRecord trace) {
    _execute(
      _database,
      '''
INSERT INTO trace_events (
  id,
  name,
  level,
  trace_type,
  run_id,
  severity,
  schema_version,
  message,
  source_event_id,
  source_run_id,
  source_task_id,
  pack_id,
  agent_id,
  parent_trace_id,
  duration_ms,
  status,
  payload_json,
  created_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
''',
      <Object?>[
        trace.id,
        trace.name,
        trace.level,
        trace.traceType,
        trace.runId,
        trace.severity,
        trace.schemaVersion,
        trace.message,
        trace.sourceEventId,
        trace.sourceRunId,
        trace.sourceTaskId,
        trace.packId,
        trace.agentId,
        trace.parentTraceId,
        trace.durationMs,
        trace.status,
        encodeJsonMap(trace.payload),
        _encodeDateTime(trace.createdAt),
      ],
    );
  }

  TraceEventRecord? readById(String id) {
    final rows = _database.select(
      'SELECT * FROM trace_events WHERE id = ? LIMIT 1;',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _traceFromRow(rows.first);
  }

  List<TraceEventRecord> readAll({int? limit, int? offset}) {
    return _selectOrdered(
      _database,
      'trace_events',
      limit: limit,
      offset: offset,
    ).map(_traceFromRow).toList(growable: false);
  }

  List<TraceEventRecord> readByRun(String runId, {int? limit, int? offset}) {
    return _selectOrdered(
      _database,
      'trace_events',
      whereSql: 'run_id = ?',
      parameters: <Object?>[runId],
      limit: limit,
      offset: offset,
    ).map(_traceFromRow).toList(growable: false);
  }

  List<TraceEventRecord> readByCreatedAtRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
    String? namePrefix,
    int? limit,
    int? offset,
  }) {
    final rows = _selectOrdered(
      _database,
      'trace_events',
      whereSql: namePrefix == null
          ? 'created_at >= ? AND created_at < ?'
          : 'created_at >= ? AND created_at < ? AND name LIKE ?',
      parameters: <Object?>[
        _encodeDateTime(startInclusive),
        _encodeDateTime(endExclusive),
        if (namePrefix != null) '$namePrefix%',
      ],
      limit: limit,
      offset: offset,
    );
    return rows.map(_traceFromRow).toList(growable: false);
  }
}
