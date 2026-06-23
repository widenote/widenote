import 'package:sqlite3/sqlite3.dart';

import 'json.dart';
import 'json_codec.dart';
import 'models.dart';

final class EventLogDao {
  const EventLogDao(this._database);

  final Database _database;

  void append(EventLogEntry event) {
    _execute(
      _database,
      '''
INSERT INTO event_log (
  id,
  type,
  schema_version,
  actor,
  status,
  source_capture_id,
  source_event_id,
  subject_kind,
  subject_id,
  subject_ref_json,
  pack_id,
  agent_id,
  device_id,
  causation_id,
  correlation_id,
  privacy,
  payload_json,
  created_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
''',
      <Object?>[
        event.id,
        event.type,
        event.schemaVersion,
        event.actor,
        event.status,
        event.sourceCaptureId,
        event.sourceEventId,
        _eventSubjectKind(event),
        _eventSubjectId(event),
        encodeJsonMap(_eventSubjectRef(event)),
        event.packId,
        event.agentId,
        event.deviceId,
        event.causationId,
        event.correlationId,
        event.privacy,
        encodeJsonMap(event.payload),
        _encodeDateTime(event.createdAt),
      ],
    );
  }

  List<EventLogEntry> readAll({int? limit, int? offset}) {
    return _selectOrdered(
      _database,
      'event_log',
      limit: limit,
      offset: offset,
    ).map(_eventFromRow).toList(growable: false);
  }

  EventLogEntry? readById(String id) {
    final rows = _database.select(
      'SELECT * FROM event_log WHERE id = ? LIMIT 1;',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _eventFromRow(rows.first);
  }

  List<EventLogEntry> readByType(String type, {int? limit, int? offset}) {
    return _selectOrdered(
      _database,
      'event_log',
      whereSql: 'type = ?',
      parameters: <Object?>[type],
      limit: limit,
      offset: offset,
    ).map(_eventFromRow).toList(growable: false);
  }
}

final class CapturesDao {
  const CapturesDao(this._database);

  final Database _database;

  void insert(CaptureRecord capture) {
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
) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
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
}

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
}

final class MemoryCandidatesDao {
  const MemoryCandidatesDao(this._database);

  final Database _database;

  void insert(MemoryCandidateRecord candidate) {
    _execute(
      _database,
      '''
INSERT INTO memory_candidates (
  id,
  candidate_key,
  schema_version,
  source_capture_id,
  source_event_id,
  status,
  body,
  source_refs_json,
  memory_type,
  confidence,
  sensitivity,
  payload_json,
  created_at,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
''',
      <Object?>[
        candidate.id,
        candidate.key,
        candidate.schemaVersion,
        candidate.sourceCaptureId,
        candidate.sourceEventId,
        candidate.status,
        candidate.body,
        encodeJsonList(candidate.sourceRefs),
        candidate.memoryType,
        candidate.confidence,
        candidate.sensitivity,
        encodeJsonMap(candidate.payload),
        _encodeDateTime(candidate.createdAt),
        _encodeDateTime(candidate.updatedAt),
      ],
    );
  }

  MemoryCandidateRecord? readById(String id) {
    final rows = _database.select(
      'SELECT * FROM memory_candidates WHERE id = ? LIMIT 1;',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _memoryCandidateFromRow(rows.first);
  }

  List<MemoryCandidateRecord> readAll({
    String? status,
    int? limit,
    int? offset,
  }) {
    final rows = _selectOrdered(
      _database,
      'memory_candidates',
      whereSql: status == null ? null : 'status = ?',
      parameters: status == null ? const <Object?>[] : <Object?>[status],
      limit: limit,
      offset: offset,
    );
    return rows.map(_memoryCandidateFromRow).toList(growable: false);
  }
}

final class TodosDao {
  const TodosDao(this._database);

  final Database _database;

  void insert(TodoRecord todo) {
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
) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
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
}

void _execute(Database database, String sql, List<Object?> parameters) {
  final statement = database.prepare(sql);
  try {
    statement.execute(parameters);
  } finally {
    statement.dispose();
  }
}

ResultSet _selectOrdered(
  Database database,
  String table, {
  String? whereSql,
  List<Object?> parameters = const <Object?>[],
  int? limit,
  int? offset,
}) {
  _checkPagination(limit: limit, offset: offset);

  final sql = StringBuffer('SELECT * FROM $table');
  final queryParameters = <Object?>[...parameters];
  if (whereSql != null) {
    sql.write(' WHERE $whereSql');
  }
  sql.write(' ORDER BY created_at, id');
  if (limit != null) {
    sql.write(' LIMIT ?');
    queryParameters.add(limit);
  } else if (offset != null) {
    sql.write(' LIMIT -1');
  }
  if (offset != null) {
    sql.write(' OFFSET ?');
    queryParameters.add(offset);
  }
  sql.write(';');

  return database.select(sql.toString(), queryParameters);
}

void _checkPagination({int? limit, int? offset}) {
  if (limit != null && limit < 0) {
    throw RangeError.value(limit, 'limit', 'must be non-negative');
  }
  if (offset != null && offset < 0) {
    throw RangeError.value(offset, 'offset', 'must be non-negative');
  }
}

EventLogEntry _eventFromRow(Row row) {
  return EventLogEntry(
    id: _text(row, 'id'),
    type: _text(row, 'type'),
    schemaVersion: _integer(row, 'schema_version'),
    actor: _text(row, 'actor'),
    status: _text(row, 'status'),
    privacy: _text(row, 'privacy'),
    sourceCaptureId: _nullableText(row, 'source_capture_id'),
    sourceEventId: _nullableText(row, 'source_event_id'),
    subjectKind: _nullableText(row, 'subject_kind'),
    subjectId: _nullableText(row, 'subject_id'),
    subjectRef: decodeJsonMap(_text(row, 'subject_ref_json')),
    packId: _nullableText(row, 'pack_id'),
    agentId: _nullableText(row, 'agent_id'),
    deviceId: _nullableText(row, 'device_id'),
    causationId: _nullableText(row, 'causation_id'),
    correlationId: _nullableText(row, 'correlation_id'),
    payload: decodeJsonMap(_text(row, 'payload_json')),
    createdAt: _dateTime(row, 'created_at'),
  );
}

CaptureRecord _captureFromRow(Row row) {
  return CaptureRecord(
    id: _text(row, 'id'),
    schemaVersion: _integer(row, 'schema_version'),
    sourceType: _text(row, 'source_type'),
    sourceId: _nullableText(row, 'source_id'),
    status: _text(row, 'status'),
    payload: decodeJsonMap(_text(row, 'payload_json')),
    createdAt: _dateTime(row, 'created_at'),
    updatedAt: _dateTime(row, 'updated_at'),
  );
}

MemoryItemRecord _memoryItemFromRow(Row row) {
  return MemoryItemRecord(
    id: _text(row, 'id'),
    key: _text(row, 'memory_key'),
    schemaVersion: _integer(row, 'schema_version'),
    sourceCaptureId: _nullableText(row, 'source_capture_id'),
    sourceEventId: _nullableText(row, 'source_event_id'),
    status: _text(row, 'status'),
    body: _text(row, 'body'),
    sourceRefs: decodeJsonList(_text(row, 'source_refs_json')),
    memoryType: _text(row, 'memory_type'),
    confidence: _text(row, 'confidence'),
    sensitivity: _text(row, 'sensitivity'),
    revision: _integer(row, 'revision'),
    tombstone: _bool(row, 'tombstone'),
    payload: decodeJsonMap(_text(row, 'payload_json')),
    createdAt: _dateTime(row, 'created_at'),
    updatedAt: _dateTime(row, 'updated_at'),
  );
}

MemoryCandidateRecord _memoryCandidateFromRow(Row row) {
  return MemoryCandidateRecord(
    id: _text(row, 'id'),
    key: _text(row, 'candidate_key'),
    schemaVersion: _integer(row, 'schema_version'),
    sourceCaptureId: _nullableText(row, 'source_capture_id'),
    sourceEventId: _nullableText(row, 'source_event_id'),
    status: _text(row, 'status'),
    body: _text(row, 'body'),
    sourceRefs: decodeJsonList(_text(row, 'source_refs_json')),
    memoryType: _text(row, 'memory_type'),
    confidence: _text(row, 'confidence'),
    sensitivity: _text(row, 'sensitivity'),
    payload: decodeJsonMap(_text(row, 'payload_json')),
    createdAt: _dateTime(row, 'created_at'),
    updatedAt: _dateTime(row, 'updated_at'),
  );
}

TodoRecord _todoFromRow(Row row) {
  return TodoRecord(
    id: _text(row, 'id'),
    schemaVersion: _integer(row, 'schema_version'),
    sourceCaptureId: _nullableText(row, 'source_capture_id'),
    sourceEventId: _nullableText(row, 'source_event_id'),
    status: _text(row, 'status'),
    payload: decodeJsonMap(_text(row, 'payload_json')),
    createdAt: _dateTime(row, 'created_at'),
    updatedAt: _dateTime(row, 'updated_at'),
  );
}

TraceEventRecord _traceFromRow(Row row) {
  final traceType = _text(row, 'trace_type');
  final severity = _text(row, 'severity');
  return TraceEventRecord(
    id: _text(row, 'id'),
    name: _text(row, 'name'),
    level: _text(row, 'level'),
    traceTypeOverride: traceType.isEmpty ? null : traceType,
    runIdOverride: _nullableText(row, 'run_id'),
    severityOverride: severity.isEmpty ? null : severity,
    schemaVersion: _integer(row, 'schema_version'),
    message: _text(row, 'message'),
    sourceEventId: _nullableText(row, 'source_event_id'),
    sourceRunId: _nullableText(row, 'source_run_id'),
    sourceTaskId: _nullableText(row, 'source_task_id'),
    packId: _nullableText(row, 'pack_id'),
    agentId: _nullableText(row, 'agent_id'),
    parentTraceId: _nullableText(row, 'parent_trace_id'),
    durationMs: _nullableNum(row, 'duration_ms'),
    status: _text(row, 'status'),
    payload: decodeJsonMap(_text(row, 'payload_json')),
    createdAt: _dateTime(row, 'created_at'),
  );
}

String _encodeDateTime(DateTime value) => value.toUtc().toIso8601String();

int _encodeBool(bool value) => value ? 1 : 0;

JsonMap _eventSubjectRef(EventLogEntry event) {
  if (event.subjectRef.isNotEmpty) {
    return event.subjectRef;
  }
  final kind = event.subjectKind;
  final id = event.subjectId;
  if (kind == null || id == null) {
    return const <String, Object?>{};
  }
  return <String, Object?>{'kind': kind, 'id': id};
}

String? _eventSubjectKind(EventLogEntry event) {
  final kind = event.subjectRefKind;
  return kind ?? event.subjectKind;
}

String? _eventSubjectId(EventLogEntry event) {
  final id = event.subjectRefId;
  return id ?? event.subjectId;
}

DateTime _dateTime(Row row, String column) {
  return DateTime.parse(_text(row, column)).toUtc();
}

String _text(Row row, String column) => row[column] as String;

String? _nullableText(Row row, String column) => row[column] as String?;

int _integer(Row row, String column) => row[column] as int;

bool _bool(Row row, String column) => _integer(row, column) != 0;

num? _nullableNum(Row row, String column) => row[column] as num?;
