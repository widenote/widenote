part of 'daos.dart';

final class AttachmentsDao {
  const AttachmentsDao(this._database);

  final Database _database;

  void insert(AttachmentRecord attachment) {
    _write(attachment, allowUpdate: false);
  }

  void save(AttachmentRecord attachment) {
    _write(attachment, allowUpdate: true);
  }

  AttachmentRecord? readById(String id) {
    final rows = _database.select(
      'SELECT * FROM attachments WHERE id = ? LIMIT 1;',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _attachmentFromRow(rows.first);
  }

  List<AttachmentRecord> readByCapture(
    String captureId, {
    String? status,
    int? limit,
    int? offset,
  }) {
    final where = status == null
        ? 'capture_id = ?'
        : 'capture_id = ? AND status = ?';
    final parameters = status == null
        ? <Object?>[captureId]
        : <Object?>[captureId, status];
    final rows = _selectOrdered(
      _database,
      'attachments',
      whereSql: where,
      parameters: parameters,
      limit: limit,
      offset: offset,
    );
    return rows.map(_attachmentFromRow).toList(growable: false);
  }

  List<AttachmentRecord> readAll({String? status, int? limit, int? offset}) {
    final rows = _selectOrdered(
      _database,
      'attachments',
      whereSql: status == null ? null : 'status = ?',
      parameters: status == null ? const <Object?>[] : <Object?>[status],
      limit: limit,
      offset: offset,
    );
    return rows.map(_attachmentFromRow).toList(growable: false);
  }

  void _write(AttachmentRecord attachment, {required bool allowUpdate}) {
    _requireAttachment(attachment);
    _execute(
      _database,
      '''
INSERT INTO attachments (
  id,
  schema_version,
  capture_id,
  source_event_id,
  asset_kind,
  mime_type,
  storage_path,
  original_file_name,
  sha256,
  byte_length,
  status,
  payload_json,
  created_at,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
${allowUpdate ? _attachmentUpsertClause : ';'}
''',
      <Object?>[
        attachment.id,
        attachment.schemaVersion,
        attachment.captureId,
        attachment.sourceEventId,
        attachment.assetKind,
        attachment.mimeType,
        attachment.storagePath,
        attachment.originalFileName,
        attachment.sha256,
        attachment.byteLength,
        attachment.status,
        encodeJsonMap(attachment.payload),
        _encodeDateTime(attachment.createdAt),
        _encodeDateTime(attachment.updatedAt),
      ],
    );
  }
}

void _requireAttachment(AttachmentRecord attachment) {
  if (attachment.captureId.trim().isEmpty) {
    throw ArgumentError.value(
      attachment.captureId,
      'attachment.captureId',
      'must not be empty',
    );
  }
  if (attachment.assetKind.trim().isEmpty) {
    throw ArgumentError.value(
      attachment.assetKind,
      'attachment.assetKind',
      'must not be empty',
    );
  }
  if (attachment.storagePath.trim().isEmpty) {
    throw ArgumentError.value(
      attachment.storagePath,
      'attachment.storagePath',
      'must not be empty',
    );
  }
  final byteLength = attachment.byteLength;
  if (byteLength != null && byteLength < 0) {
    throw ArgumentError.value(
      byteLength,
      'attachment.byteLength',
      'must be non-negative',
    );
  }
}

const _attachmentUpsertClause = '''
ON CONFLICT(id) DO UPDATE SET
  schema_version = excluded.schema_version,
  capture_id = excluded.capture_id,
  source_event_id = excluded.source_event_id,
  asset_kind = excluded.asset_kind,
  mime_type = excluded.mime_type,
  storage_path = excluded.storage_path,
  original_file_name = excluded.original_file_name,
  sha256 = excluded.sha256,
  byte_length = excluded.byte_length,
  status = excluded.status,
  payload_json = excluded.payload_json,
  updated_at = excluded.updated_at;
''';
