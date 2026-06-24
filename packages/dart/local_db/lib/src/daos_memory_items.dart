part of 'daos.dart';

final class MemoryItemsDao {
  const MemoryItemsDao(this._database);

  final Database _database;

  void insert(MemoryItemRecord item) {
    _execute(
      _database,
      '''
INSERT INTO memory_items (
  id,
  memory_key,
  schema_version,
  source_capture_id,
  source_event_id,
  status,
  body,
  source_refs_json,
  memory_type,
  confidence,
  sensitivity,
  revision,
  tombstone,
  payload_json,
  created_at,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
''',
      <Object?>[
        item.id,
        item.key,
        item.schemaVersion,
        item.sourceCaptureId,
        item.sourceEventId,
        item.status,
        item.body,
        encodeJsonList(item.sourceRefs),
        item.memoryType,
        item.confidence,
        item.sensitivity,
        item.revision,
        _encodeBool(item.tombstone),
        encodeJsonMap(item.payload),
        _encodeDateTime(item.createdAt),
        _encodeDateTime(item.updatedAt),
      ],
    );
  }

  void save(MemoryItemRecord item) {
    _execute(
      _database,
      '''
INSERT INTO memory_items (
  id,
  memory_key,
  schema_version,
  source_capture_id,
  source_event_id,
  status,
  body,
  source_refs_json,
  memory_type,
  confidence,
  sensitivity,
  revision,
  tombstone,
  payload_json,
  created_at,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
  memory_key = excluded.memory_key,
  schema_version = excluded.schema_version,
  source_capture_id = excluded.source_capture_id,
  source_event_id = excluded.source_event_id,
  status = excluded.status,
  body = excluded.body,
  source_refs_json = excluded.source_refs_json,
  memory_type = excluded.memory_type,
  confidence = excluded.confidence,
  sensitivity = excluded.sensitivity,
  revision = excluded.revision,
  tombstone = excluded.tombstone,
  payload_json = excluded.payload_json,
  updated_at = excluded.updated_at;
''',
      <Object?>[
        item.id,
        item.key,
        item.schemaVersion,
        item.sourceCaptureId,
        item.sourceEventId,
        item.status,
        item.body,
        encodeJsonList(item.sourceRefs),
        item.memoryType,
        item.confidence,
        item.sensitivity,
        item.revision,
        _encodeBool(item.tombstone),
        encodeJsonMap(item.payload),
        _encodeDateTime(item.createdAt),
        _encodeDateTime(item.updatedAt),
      ],
    );
  }

  MemoryItemRecord? readById(String id) {
    final rows = _database.select(
      'SELECT * FROM memory_items WHERE id = ? LIMIT 1;',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _memoryItemFromRow(rows.first);
  }

  List<MemoryItemRecord> readAll({String? status, int? limit, int? offset}) {
    final rows = _selectOrdered(
      _database,
      'memory_items',
      whereSql: status == null ? null : 'status = ?',
      parameters: status == null ? const <Object?>[] : <Object?>[status],
      limit: limit,
      offset: offset,
    );
    return rows.map(_memoryItemFromRow).toList(growable: false);
  }

  List<MemoryItemRecord> readActiveByKey(String key) {
    final rows = _selectOrdered(
      _database,
      'memory_items',
      whereSql: 'memory_key = ? AND status = ? AND tombstone = 0',
      parameters: <Object?>[key, 'active'],
    );
    return rows.map(_memoryItemFromRow).toList(growable: false);
  }
}
