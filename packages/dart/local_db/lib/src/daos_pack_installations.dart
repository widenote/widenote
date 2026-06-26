part of 'daos.dart';

final class PackInstallationsDao {
  const PackInstallationsDao(this._database);

  final Database _database;

  void insert(PackInstallationRecord installation) {
    _write(installation, allowUpdate: false);
  }

  void save(PackInstallationRecord installation) {
    _write(installation, allowUpdate: true);
  }

  PackInstallationRecord updateStatus(
    String packId,
    String status, {
    String? runtimeStatus,
    DateTime? updatedAt,
    JsonMap payloadUpdates = const <String, Object?>{},
  }) {
    final existing = readById(packId);
    if (existing == null) {
      throw StateError('Pack installation not found: $packId');
    }
    final updated = existing.copyWith(
      status: status,
      runtimeStatus: runtimeStatus,
      payload: _mergeJson(existing.payload, payloadUpdates),
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
    save(updated);
    return updated;
  }

  PackInstallationRecord? readById(String packId) {
    final rows = _database.select(
      'SELECT * FROM pack_installations WHERE pack_id = ? LIMIT 1;',
      <Object?>[packId],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _packInstallationFromRow(rows.first);
  }

  List<PackInstallationRecord> readAll({
    String? status,
    int? limit,
    int? offset,
  }) {
    final rows = _selectOrderedBy(
      _database,
      'pack_installations',
      orderBy: 'installed_at, pack_id',
      whereSql: status == null ? null : 'status = ?',
      parameters: status == null ? const <Object?>[] : <Object?>[status],
      limit: limit,
      offset: offset,
    );
    return rows.map(_packInstallationFromRow).toList(growable: false);
  }

  void _write(
    PackInstallationRecord installation, {
    required bool allowUpdate,
  }) {
    _execute(
      _database,
      '''
INSERT INTO pack_installations (
  pack_id,
  schema_version,
  name,
  version,
  publisher,
  edition,
  status,
  runtime_status,
  entrypoint_kind,
  requested_permissions_json,
  enabled_subscription_ids_json,
  manifest_json,
  payload_json,
  installed_at,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
${allowUpdate ? _packInstallationUpsertClause : ';'}
''',
      <Object?>[
        installation.packId,
        installation.schemaVersion,
        installation.name,
        installation.version,
        installation.publisher,
        installation.edition,
        installation.status,
        installation.runtimeStatus,
        installation.entrypointKind,
        encodeJsonList(installation.requestedPermissions),
        encodeJsonList(installation.enabledSubscriptionIds),
        encodeJsonMap(installation.manifest),
        encodeJsonMap(installation.payload),
        _encodeDateTime(installation.installedAt),
        _encodeDateTime(installation.updatedAt),
      ],
    );
  }
}

const _packInstallationUpsertClause = '''
ON CONFLICT(pack_id) DO UPDATE SET
  schema_version = excluded.schema_version,
  name = excluded.name,
  version = excluded.version,
  publisher = excluded.publisher,
  edition = excluded.edition,
  status = excluded.status,
  runtime_status = excluded.runtime_status,
  entrypoint_kind = excluded.entrypoint_kind,
  requested_permissions_json = excluded.requested_permissions_json,
  enabled_subscription_ids_json = excluded.enabled_subscription_ids_json,
  manifest_json = excluded.manifest_json,
  payload_json = excluded.payload_json,
  updated_at = excluded.updated_at;
''';
