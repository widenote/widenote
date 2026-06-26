part of 'daos.dart';

final class RuntimeTasksDao {
  const RuntimeTasksDao(this._database);

  final Database _database;

  void insert(RuntimeTaskRecord task) {
    _write(task, allowUpdate: false);
  }

  void save(RuntimeTaskRecord task) {
    _write(task, allowUpdate: true);
  }

  RuntimeTaskRecord updateStatus(
    String id,
    String status, {
    DateTime? updatedAt,
    String? error,
    JsonMap payloadUpdates = const <String, Object?>{},
    bool clearLease = true,
  }) {
    final existing = readById(id);
    if (existing == null) {
      throw StateError('Runtime task not found: $id');
    }
    final updated = existing.copyWith(
      status: status,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
      error: error,
      payload: _mergeJson(existing.payload, payloadUpdates),
      clearLease: clearLease,
    );
    save(updated);
    return updated;
  }

  int denyActiveForPack(
    String packId, {
    required String reason,
    DateTime? updatedAt,
  }) {
    final now = updatedAt ?? DateTime.now().toUtc();
    final rows = readByPack(packId)
        .where((task) => !_runtimeTaskTerminalStatuses.contains(task.status))
        .toList(growable: false);
    for (final task in rows) {
      save(
        task.copyWith(
          status: 'denied',
          error: reason,
          updatedAt: now,
          clearLease: true,
        ),
      );
    }
    return rows.length;
  }

  RuntimeTaskRecord? readById(String id) {
    final rows = _database.select(
      'SELECT * FROM runtime_tasks WHERE id = ? LIMIT 1;',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _runtimeTaskFromRow(rows.first);
  }

  RuntimeTaskRecord? readByIdentityKey(String identityKey) {
    final rows = _database.select(
      'SELECT * FROM runtime_tasks WHERE identity_key = ? LIMIT 1;',
      <Object?>[identityKey],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _runtimeTaskFromRow(rows.first);
  }

  List<RuntimeTaskRecord> readAll({String? status, int? limit, int? offset}) {
    final rows = _selectOrdered(
      _database,
      'runtime_tasks',
      whereSql: status == null ? null : 'status = ?',
      parameters: status == null ? const <Object?>[] : <Object?>[status],
      limit: limit,
      offset: offset,
    );
    return rows.map(_runtimeTaskFromRow).toList(growable: false);
  }

  List<RuntimeTaskRecord> readByPack(
    String packId, {
    String? status,
    int? limit,
    int? offset,
  }) {
    final whereSql = status == null
        ? 'pack_id = ?'
        : 'pack_id = ? AND status = ?';
    final parameters = status == null
        ? <Object?>[packId]
        : <Object?>[packId, status];
    final rows = _selectOrdered(
      _database,
      'runtime_tasks',
      whereSql: whereSql,
      parameters: parameters,
      limit: limit,
      offset: offset,
    );
    return rows.map(_runtimeTaskFromRow).toList(growable: false);
  }

  void _write(RuntimeTaskRecord task, {required bool allowUpdate}) {
    if (task.maxAttempts < 1) {
      throw ArgumentError.value(
        task.maxAttempts,
        'maxAttempts',
        'must be positive',
      );
    }
    if (task.attempts < 0) {
      throw ArgumentError.value(task.attempts, 'attempts', 'must be positive');
    }
    _execute(
      _database,
      '''
INSERT INTO runtime_tasks (
  id,
  schema_version,
  pack_id,
  pack_version,
  agent_id,
  handler_id,
  subscription_id,
  trigger_event_id,
  identity_key,
  status,
  dependency_task_ids_json,
  missing_dependency_ids_json,
  attempts,
  max_attempts,
  lease_owner,
  leased_until,
  error,
  payload_json,
  created_at,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
${allowUpdate ? _runtimeTaskUpsertClause : ';'}
''',
      <Object?>[
        task.id,
        task.schemaVersion,
        task.packId,
        task.packVersion,
        task.agentId,
        task.handlerId,
        task.subscriptionId,
        task.triggerEventId,
        task.effectiveIdentityKey,
        task.status,
        encodeJsonList(task.dependencyTaskIds),
        encodeJsonList(task.missingDependencyIds),
        task.attempts,
        task.maxAttempts,
        task.leaseOwner,
        task.leasedUntil == null ? null : _encodeDateTime(task.leasedUntil!),
        task.error,
        encodeJsonMap(task.payload),
        _encodeDateTime(task.createdAt),
        _encodeDateTime(task.updatedAt),
      ],
    );
  }
}

const _runtimeTaskTerminalStatuses = <String>{
  'succeeded',
  'failed',
  'denied',
  'canceled',
  'blocked',
};

const _runtimeTaskUpsertClause = '''
ON CONFLICT(id) DO UPDATE SET
  schema_version = excluded.schema_version,
  pack_id = excluded.pack_id,
  pack_version = excluded.pack_version,
  agent_id = excluded.agent_id,
  handler_id = excluded.handler_id,
  subscription_id = excluded.subscription_id,
  trigger_event_id = excluded.trigger_event_id,
  identity_key = excluded.identity_key,
  status = excluded.status,
  dependency_task_ids_json = excluded.dependency_task_ids_json,
  missing_dependency_ids_json = excluded.missing_dependency_ids_json,
  attempts = excluded.attempts,
  max_attempts = excluded.max_attempts,
  lease_owner = excluded.lease_owner,
  leased_until = excluded.leased_until,
  error = excluded.error,
  payload_json = excluded.payload_json,
  updated_at = excluded.updated_at;
''';
