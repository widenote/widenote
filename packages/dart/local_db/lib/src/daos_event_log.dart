part of 'daos.dart';

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
