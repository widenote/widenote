part of 'daos.dart';

final class RuntimeRunsDao {
  const RuntimeRunsDao(this._database);

  final Database _database;

  void insert(RuntimeRunRecord run) {
    _write(run, allowUpdate: false);
  }

  void save(RuntimeRunRecord run) {
    _write(run, allowUpdate: true);
  }

  RuntimeRunRecord updateStatus(
    String id,
    String status, {
    DateTime? completedAt,
    JsonList? outputEventIds,
    String? error,
    JsonMap payloadUpdates = const <String, Object?>{},
  }) {
    final existing = readById(id);
    if (existing == null) {
      throw StateError('Runtime run not found: $id');
    }
    final updated = existing.copyWith(
      status: status,
      completedAt: completedAt,
      outputEventIds: outputEventIds,
      error: error,
      payload: _mergeJson(existing.payload, payloadUpdates),
    );
    save(updated);
    return updated;
  }

  RuntimeRunRecord? readById(String id) {
    final rows = _database.select(
      'SELECT * FROM runtime_runs WHERE id = ? LIMIT 1;',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _runtimeRunFromRow(rows.first);
  }

  List<RuntimeRunRecord> readAll({String? status, int? limit, int? offset}) {
    final rows = _selectOrderedBy(
      _database,
      'runtime_runs',
      orderBy: 'started_at, id',
      whereSql: status == null ? null : 'status = ?',
      parameters: status == null ? const <Object?>[] : <Object?>[status],
      limit: limit,
      offset: offset,
    );
    return rows.map(_runtimeRunFromRow).toList(growable: false);
  }

  List<RuntimeRunRecord> readByTask(String taskId, {int? limit, int? offset}) {
    final rows = _selectOrderedBy(
      _database,
      'runtime_runs',
      orderBy: 'started_at, id',
      whereSql: 'task_id = ?',
      parameters: <Object?>[taskId],
      limit: limit,
      offset: offset,
    );
    return rows.map(_runtimeRunFromRow).toList(growable: false);
  }

  void _write(RuntimeRunRecord run, {required bool allowUpdate}) {
    if (run.attempt < 1) {
      throw ArgumentError.value(run.attempt, 'attempt', 'must be positive');
    }
    _execute(
      _database,
      '''
INSERT INTO runtime_runs (
  id,
  schema_version,
  task_id,
  pack_id,
  pack_version,
  agent_id,
  handler_id,
  status,
  attempt,
  output_event_ids_json,
  error,
  payload_json,
  started_at,
  completed_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
${allowUpdate ? _runtimeRunUpsertClause : ';'}
''',
      <Object?>[
        run.id,
        run.schemaVersion,
        run.taskId,
        run.packId,
        run.packVersion,
        run.agentId,
        run.handlerId,
        run.status,
        run.attempt,
        encodeJsonList(run.outputEventIds),
        run.error,
        encodeJsonMap(run.payload),
        _encodeDateTime(run.startedAt),
        run.completedAt == null ? null : _encodeDateTime(run.completedAt!),
      ],
    );
  }
}

const _runtimeRunUpsertClause = '''
ON CONFLICT(id) DO UPDATE SET
  schema_version = excluded.schema_version,
  task_id = excluded.task_id,
  pack_id = excluded.pack_id,
  pack_version = excluded.pack_version,
  agent_id = excluded.agent_id,
  handler_id = excluded.handler_id,
  status = excluded.status,
  attempt = excluded.attempt,
  output_event_ids_json = excluded.output_event_ids_json,
  error = excluded.error,
  payload_json = excluded.payload_json,
  completed_at = excluded.completed_at;
''';
