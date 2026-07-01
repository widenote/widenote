part of 'daos.dart';

final class ChatSessionsDao {
  const ChatSessionsDao(this._database);

  final Database _database;

  void insert(ChatSessionRecord session) {
    _write(session, allowUpdate: false);
  }

  void save(ChatSessionRecord session) {
    _write(session, allowUpdate: true);
  }

  ChatSessionRecord? readById(String id) {
    final rows = _database.select(
      'SELECT * FROM chat_sessions WHERE id = ? LIMIT 1;',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _chatSessionFromRow(rows.first);
  }

  List<ChatSessionRecord> readAll({String? status, int? limit, int? offset}) {
    _checkPagination(limit: limit, offset: offset);
    final sql = StringBuffer('SELECT * FROM chat_sessions');
    final parameters = <Object?>[];
    if (status != null) {
      sql.write(' WHERE status = ?');
      parameters.add(status);
    }
    sql.write(' ORDER BY updated_at DESC, created_at DESC');
    if (limit != null) {
      sql.write(' LIMIT ?');
      parameters.add(limit);
    } else if (offset != null) {
      sql.write(' LIMIT -1');
    }
    if (offset != null) {
      sql.write(' OFFSET ?');
      parameters.add(offset);
    }
    sql.write(';');
    final rows = _database.select(sql.toString(), parameters);
    return rows.map(_chatSessionFromRow).toList(growable: false);
  }

  void deleteById(String id) {
    _execute(_database, 'DELETE FROM chat_sessions WHERE id = ?;', <Object?>[
      id,
    ]);
  }

  void _write(ChatSessionRecord session, {required bool allowUpdate}) {
    _execute(
      _database,
      '''
INSERT INTO chat_sessions (
  id,
  schema_version,
  title,
  status,
  payload_json,
  created_at,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?)
${allowUpdate ? _chatSessionUpsertClause : ';'}
''',
      <Object?>[
        session.id,
        session.schemaVersion,
        session.title,
        session.status,
        encodeJsonMap(session.payload),
        _encodeDateTime(session.createdAt),
        _encodeDateTime(session.updatedAt),
      ],
    );
  }
}

final class ChatMessagesDao {
  const ChatMessagesDao(this._database);

  final Database _database;

  void insert(ChatMessageRecord message) {
    _write(message, allowUpdate: false);
  }

  void save(ChatMessageRecord message) {
    _write(message, allowUpdate: true);
  }

  ChatMessageRecord? readById(String id) {
    final rows = _database.select(
      'SELECT * FROM chat_messages WHERE id = ? LIMIT 1;',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _chatMessageFromRow(rows.first);
  }

  List<ChatMessageRecord> readBySession(String sessionId) {
    final rows = _database.select(
      '''
SELECT * FROM chat_messages
WHERE session_id = ?
ORDER BY created_at ASC;
''',
      <Object?>[sessionId],
    );
    return rows.map(_chatMessageFromRow).toList(growable: false);
  }

  void deleteBySession(String sessionId) {
    _execute(
      _database,
      'DELETE FROM chat_messages WHERE session_id = ?;',
      <Object?>[sessionId],
    );
  }

  List<ChatMessageRecord> readAll({String? status, int? limit, int? offset}) {
    final rows = _selectOrdered(
      _database,
      'chat_messages',
      whereSql: status == null ? null : 'status = ?',
      parameters: status == null ? const <Object?>[] : <Object?>[status],
      limit: limit,
      offset: offset,
    );
    return rows.map(_chatMessageFromRow).toList(growable: false);
  }

  void _write(ChatMessageRecord message, {required bool allowUpdate}) {
    _execute(
      _database,
      '''
INSERT INTO chat_messages (
  id,
  schema_version,
  session_id,
  role,
  status,
  body,
  source_refs_json,
  payload_json,
  created_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
${allowUpdate ? _chatMessageUpsertClause : ';'}
''',
      <Object?>[
        message.id,
        message.schemaVersion,
        message.sessionId,
        message.role,
        message.status,
        message.body,
        encodeJsonList(message.sourceRefs),
        encodeJsonMap(message.payload),
        _encodeDateTime(message.createdAt),
      ],
    );
  }
}

const _chatSessionUpsertClause = '''
ON CONFLICT(id) DO UPDATE SET
  schema_version = excluded.schema_version,
  title = excluded.title,
  status = excluded.status,
  payload_json = excluded.payload_json,
  updated_at = excluded.updated_at;
''';

const _chatMessageUpsertClause = '''
ON CONFLICT(id) DO UPDATE SET
  schema_version = excluded.schema_version,
  role = excluded.role,
  status = excluded.status,
  body = excluded.body,
  source_refs_json = excluded.source_refs_json,
  payload_json = excluded.payload_json;
''';
