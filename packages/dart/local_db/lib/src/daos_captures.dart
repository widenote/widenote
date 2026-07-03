part of 'daos.dart';

final class CapturesDao {
  const CapturesDao(this._database);

  final Database _database;

  void insert(CaptureRecord capture) {
    _write(capture, allowUpdate: false);
  }

  void save(CaptureRecord capture) {
    _write(capture, allowUpdate: true);
  }

  CaptureRecord updateStatus(
    String id,
    String status, {
    DateTime? updatedAt,
    JsonMap payloadUpdates = const <String, Object?>{},
  }) {
    final existing = readById(id);
    if (existing == null) {
      throw StateError('Capture not found: $id');
    }
    final updated = CaptureRecord(
      id: existing.id,
      schemaVersion: existing.schemaVersion,
      sourceType: existing.sourceType,
      sourceId: existing.sourceId,
      status: status,
      payload: _mergeJson(existing.payload, payloadUpdates),
      createdAt: existing.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
    save(updated);
    return updated;
  }

  void _write(CaptureRecord capture, {required bool allowUpdate}) {
    _execute(
      _database,
      '''
INSERT INTO captures (
  id,
  schema_version,
  source_type,
  source_id,
  status,
  payload_json,
  created_at,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
${allowUpdate ? _captureUpsertClause : ';'}
''',
      <Object?>[
        capture.id,
        capture.schemaVersion,
        capture.sourceType,
        capture.sourceId,
        capture.status,
        encodeJsonMap(capture.payload),
        _encodeDateTime(capture.createdAt),
        _encodeDateTime(capture.updatedAt),
      ],
    );
  }

  CaptureRecord? readById(String id) {
    final rows = _database.select(
      'SELECT * FROM captures WHERE id = ? LIMIT 1;',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _captureFromRow(rows.first);
  }

  List<CaptureRecord> readAll({String? status, int? limit, int? offset}) {
    final rows = _selectOrdered(
      _database,
      'captures',
      whereSql: status == null ? null : 'status = ?',
      parameters: status == null ? const <Object?>[] : <Object?>[status],
      limit: limit,
      offset: offset,
    );
    return rows.map(_captureFromRow).toList(growable: false);
  }

  List<CaptureRecord> readByCreatedAtRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
    String? status,
    int? limit,
    int? offset,
  }) {
    final rows = _selectOrdered(
      _database,
      'captures',
      whereSql: status == null
          ? 'created_at >= ? AND created_at < ?'
          : 'created_at >= ? AND created_at < ? AND status = ?',
      parameters: <Object?>[
        _encodeDateTime(startInclusive),
        _encodeDateTime(endExclusive),
        if (status != null) status,
      ],
      limit: limit,
      offset: offset,
    );
    return rows.map(_captureFromRow).toList(growable: false);
  }
}

const _captureUpsertClause = '''
ON CONFLICT(id) DO UPDATE SET
  schema_version = excluded.schema_version,
  source_type = excluded.source_type,
  source_id = excluded.source_id,
  status = excluded.status,
  payload_json = excluded.payload_json,
  updated_at = excluded.updated_at;
''';
