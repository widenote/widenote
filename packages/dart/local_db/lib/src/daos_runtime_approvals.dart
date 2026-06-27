part of 'daos.dart';

final class RuntimeApprovalsDao {
  const RuntimeApprovalsDao(this._database);

  final Database _database;

  void insert(RuntimeApprovalRecord approval) {
    _write(approval, allowUpdate: false);
  }

  void save(RuntimeApprovalRecord approval) {
    _write(approval, allowUpdate: true);
  }

  RuntimeApprovalRecord approveOnce(
    String id, {
    String? reason,
    DateTime? decidedAt,
  }) {
    return _decide(
      id,
      status: 'approved',
      decision: 'approve_once',
      reason: reason,
      decidedAt: decidedAt,
    );
  }

  RuntimeApprovalRecord deny(String id, {String? reason, DateTime? decidedAt}) {
    return _decide(
      id,
      status: 'denied',
      decision: 'deny',
      reason: reason,
      decidedAt: decidedAt,
    );
  }

  RuntimeApprovalRecord cancel(
    String id, {
    String? reason,
    DateTime? decidedAt,
  }) {
    return _decide(
      id,
      status: 'canceled',
      decision: 'cancel',
      reason: reason,
      decidedAt: decidedAt,
    );
  }

  RuntimeApprovalRecord expire(
    String id, {
    String? reason,
    DateTime? decidedAt,
  }) {
    return _decide(
      id,
      status: 'expired',
      decision: 'expire',
      reason: reason,
      decidedAt: decidedAt,
    );
  }

  RuntimeApprovalRecord? readById(String id) {
    final rows = _database.select(
      'SELECT * FROM runtime_approval_requests WHERE id = ? LIMIT 1;',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _runtimeApprovalFromRow(rows.first);
  }

  List<RuntimeApprovalRecord> readAll({
    String? status,
    int? limit,
    int? offset,
  }) {
    final rows = _selectOrderedBy(
      _database,
      'runtime_approval_requests',
      orderBy: 'requested_at, id',
      whereSql: status == null ? null : 'status = ?',
      parameters: status == null ? const <Object?>[] : <Object?>[status],
      limit: limit,
      offset: offset,
    );
    return rows.map(_runtimeApprovalFromRow).toList(growable: false);
  }

  List<RuntimeApprovalRecord> readPending({
    DateTime? now,
    String? packId,
    String? runId,
    int? limit,
    int? offset,
  }) {
    final where = <String>['status = ?'];
    final parameters = <Object?>['pending'];
    if (packId != null) {
      where.add('pack_id = ?');
      parameters.add(packId);
    }
    if (runId != null) {
      where.add('run_id = ?');
      parameters.add(runId);
    }
    if (now != null) {
      where.add('(expires_at IS NULL OR expires_at > ?)');
      parameters.add(_encodeDateTime(now));
    }
    final rows = _selectOrderedBy(
      _database,
      'runtime_approval_requests',
      orderBy: 'requested_at, id',
      whereSql: where.join(' AND '),
      parameters: parameters,
      limit: limit,
      offset: offset,
    );
    return rows.map(_runtimeApprovalFromRow).toList(growable: false);
  }

  RuntimeApprovalRecord _decide(
    String id, {
    required String status,
    required String decision,
    required String? reason,
    required DateTime? decidedAt,
  }) {
    final existing = readById(id);
    if (existing == null) {
      throw StateError('Runtime approval request not found: $id');
    }
    final updated = existing.copyWith(
      status: status,
      decision: decision,
      reason: reason,
      decidedAt: decidedAt ?? DateTime.now().toUtc(),
    );
    save(updated);
    return updated;
  }

  void _write(RuntimeApprovalRecord approval, {required bool allowUpdate}) {
    _execute(
      _database,
      '''
INSERT INTO runtime_approval_requests (
  id,
  schema_version,
  pack_id,
  agent_id,
  task_id,
  run_id,
  tool_name,
  run_mode,
  tool_access,
  tool_risk,
  is_external,
  required_permissions_json,
  input_keys_json,
  source_refs_json,
  action_summary,
  status,
  requested_at,
  expires_at,
  decided_at,
  decision,
  reason,
  payload_json
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
${allowUpdate ? _runtimeApprovalUpsertClause : ';'}
''',
      <Object?>[
        approval.id,
        approval.schemaVersion,
        approval.packId,
        approval.agentId,
        approval.taskId,
        approval.runId,
        approval.toolName,
        approval.runMode,
        approval.toolAccess,
        approval.toolRisk,
        _encodeBool(approval.isExternal),
        encodeJsonList(approval.requiredPermissions),
        encodeJsonList(approval.inputKeys),
        encodeJsonList(approval.sourceRefs),
        approval.actionSummary,
        approval.status,
        _encodeDateTime(approval.requestedAt),
        approval.expiresAt == null
            ? null
            : _encodeDateTime(approval.expiresAt!),
        approval.decidedAt == null
            ? null
            : _encodeDateTime(approval.decidedAt!),
        approval.decision,
        approval.reason,
        encodeJsonMap(approval.payload),
      ],
    );
  }
}

const _runtimeApprovalUpsertClause = '''
ON CONFLICT(id) DO UPDATE SET
  schema_version = excluded.schema_version,
  pack_id = excluded.pack_id,
  agent_id = excluded.agent_id,
  task_id = excluded.task_id,
  run_id = excluded.run_id,
  tool_name = excluded.tool_name,
  run_mode = excluded.run_mode,
  tool_access = excluded.tool_access,
  tool_risk = excluded.tool_risk,
  is_external = excluded.is_external,
  required_permissions_json = excluded.required_permissions_json,
  input_keys_json = excluded.input_keys_json,
  source_refs_json = excluded.source_refs_json,
  action_summary = excluded.action_summary,
  status = excluded.status,
  expires_at = excluded.expires_at,
  decided_at = excluded.decided_at,
  decision = excluded.decision,
  reason = excluded.reason,
  payload_json = excluded.payload_json;
''';
