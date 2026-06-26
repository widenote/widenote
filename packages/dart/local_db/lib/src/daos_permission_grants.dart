part of 'daos.dart';

final class PermissionGrantsDao {
  const PermissionGrantsDao(this._database);

  final Database _database;

  void insert(PermissionGrantRecord grant) {
    _write(grant, allowUpdate: false);
  }

  void save(PermissionGrantRecord grant) {
    _write(grant, allowUpdate: true);
  }

  PermissionGrantRecord grant(
    PermissionGrantRecord grant, {
    DateTime? grantedAt,
  }) {
    final now = grantedAt ?? DateTime.now().toUtc();
    final updated = grant.copyWith(
      status: 'granted',
      grantedAt: now,
      revokedAt: null,
      updatedAt: now,
      clearRevokedAt: true,
    );
    save(updated);
    return updated;
  }

  PermissionGrantRecord deny(
    String packId,
    String permissionId, {
    required String reason,
    DateTime? deniedAt,
  }) {
    final existing = readByPackAndPermission(packId, permissionId);
    if (existing == null) {
      throw StateError('Permission grant not found: $packId/$permissionId');
    }
    final now = deniedAt ?? DateTime.now().toUtc();
    final updated = existing.copyWith(
      status: 'denied',
      reason: reason,
      updatedAt: now,
      clearGrantTime: true,
      clearRevokedAt: true,
    );
    save(updated);
    return updated;
  }

  PermissionGrantRecord revoke(
    String packId,
    String permissionId, {
    required String reason,
    DateTime? revokedAt,
  }) {
    final existing = readByPackAndPermission(packId, permissionId);
    if (existing == null) {
      throw StateError('Permission grant not found: $packId/$permissionId');
    }
    final now = revokedAt ?? DateTime.now().toUtc();
    final updated = existing.copyWith(
      status: 'revoked',
      revokedAt: now,
      reason: reason,
      updatedAt: now,
    );
    save(updated);
    return updated;
  }

  bool isGranted(String packId, String permissionId) {
    return readByPackAndPermission(packId, permissionId)?.isActive ?? false;
  }

  PermissionGrantRecord? readById(String id) {
    final rows = _database.select(
      'SELECT * FROM permission_grants WHERE id = ? LIMIT 1;',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _permissionGrantFromRow(rows.first);
  }

  PermissionGrantRecord? readByPackAndPermission(
    String packId,
    String permissionId,
  ) {
    final rows = _database.select(
      '''
SELECT * FROM permission_grants
WHERE pack_id = ? AND permission_id = ?
LIMIT 1;
''',
      <Object?>[packId, permissionId],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _permissionGrantFromRow(rows.first);
  }

  List<PermissionGrantRecord> readAll({
    String? status,
    int? limit,
    int? offset,
  }) {
    final rows = _selectOrdered(
      _database,
      'permission_grants',
      whereSql: status == null ? null : 'status = ?',
      parameters: status == null ? const <Object?>[] : <Object?>[status],
      limit: limit,
      offset: offset,
    );
    return rows.map(_permissionGrantFromRow).toList(growable: false);
  }

  List<PermissionGrantRecord> readByPack(
    String packId, {
    String? status,
    int? limit,
    int? offset,
  }) {
    final rows = _selectOrdered(
      _database,
      'permission_grants',
      whereSql: status == null ? 'pack_id = ?' : 'pack_id = ? AND status = ?',
      parameters: status == null
          ? <Object?>[packId]
          : <Object?>[packId, status],
      limit: limit,
      offset: offset,
    );
    return rows.map(_permissionGrantFromRow).toList(growable: false);
  }

  void _write(PermissionGrantRecord grant, {required bool allowUpdate}) {
    _execute(
      _database,
      '''
INSERT INTO permission_grants (
  id,
  schema_version,
  pack_id,
  permission_id,
  status,
  grant_kind,
  source_event_id,
  granted_at,
  revoked_at,
  reason,
  payload_json,
  created_at,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
${allowUpdate ? _permissionGrantUpsertClause : ';'}
''',
      <Object?>[
        grant.id,
        grant.schemaVersion,
        grant.packId,
        grant.permissionId,
        grant.status,
        grant.grantKind,
        grant.sourceEventId,
        grant.grantedAt == null ? null : _encodeDateTime(grant.grantedAt!),
        grant.revokedAt == null ? null : _encodeDateTime(grant.revokedAt!),
        grant.reason,
        encodeJsonMap(grant.payload),
        _encodeDateTime(grant.createdAt),
        _encodeDateTime(grant.updatedAt),
      ],
    );
  }
}

const _permissionGrantUpsertClause = '''
ON CONFLICT(id) DO UPDATE SET
  schema_version = excluded.schema_version,
  pack_id = excluded.pack_id,
  permission_id = excluded.permission_id,
  status = excluded.status,
  grant_kind = excluded.grant_kind,
  source_event_id = excluded.source_event_id,
  granted_at = excluded.granted_at,
  revoked_at = excluded.revoked_at,
  reason = excluded.reason,
  payload_json = excluded.payload_json,
  updated_at = excluded.updated_at;
''';
