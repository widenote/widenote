part of 'daos.dart';

final class TodosDao {
  const TodosDao(this._database);

  final Database _database;

  void insert(TodoRecord todo) {
    _write(todo, allowUpdate: false);
  }

  void save(TodoRecord todo) {
    _write(todo, allowUpdate: true);
  }

  void _write(TodoRecord todo, {required bool allowUpdate}) {
    _execute(
      _database,
      '''
INSERT INTO todos (
  id,
  schema_version,
  source_capture_id,
  source_event_id,
  status,
  payload_json,
  created_at,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
${allowUpdate ? _todoUpsertClause : ';'}
''',
      <Object?>[
        todo.id,
        todo.schemaVersion,
        todo.sourceCaptureId,
        todo.sourceEventId,
        todo.status,
        encodeJsonMap(todo.payload),
        _encodeDateTime(todo.createdAt),
        _encodeDateTime(todo.updatedAt),
      ],
    );
  }

  TodoRecord? readById(String id) {
    final rows = _database.select(
      'SELECT * FROM todos WHERE id = ? LIMIT 1;',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _todoFromRow(rows.first);
  }

  List<TodoRecord> readAll({String? status, int? limit, int? offset}) {
    final rows = _selectOrdered(
      _database,
      'todos',
      whereSql: status == null ? null : 'status = ?',
      parameters: status == null ? const <Object?>[] : <Object?>[status],
      limit: limit,
      offset: offset,
    );
    return rows.map(_todoFromRow).toList(growable: false);
  }

  TodoRecord updateStatus(String id, String status, {DateTime? updatedAt}) {
    final existing = readById(id);
    if (existing == null) {
      throw StateError('Todo not found: $id');
    }
    final updated = existing.copyWith(
      status: status,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
    _execute(
      _database,
      '''
UPDATE todos
SET status = ?, updated_at = ?
WHERE id = ?;
''',
      <Object?>[updated.status, _encodeDateTime(updated.updatedAt), id],
    );
    return updated;
  }
}

const _todoUpsertClause = '''
ON CONFLICT(id) DO UPDATE SET
  schema_version = excluded.schema_version,
  source_capture_id = excluded.source_capture_id,
  source_event_id = excluded.source_event_id,
  status = excluded.status,
  payload_json = excluded.payload_json,
  updated_at = excluded.updated_at;
''';
