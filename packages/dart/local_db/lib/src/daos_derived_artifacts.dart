part of 'daos.dart';

final class DerivedArtifactsDao {
  const DerivedArtifactsDao(this._database);

  final Database _database;

  void insert(DerivedArtifactRecord artifact) {
    _write(artifact, allowUpdate: false);
  }

  void save(DerivedArtifactRecord artifact) {
    _write(artifact, allowUpdate: true);
  }

  DerivedArtifactRecord? readById(String id) {
    final rows = _database.select(
      'SELECT * FROM derived_artifacts WHERE id = ? LIMIT 1;',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _derivedArtifactFromRow(rows.first);
  }

  List<DerivedArtifactRecord> readByCapture(
    String captureId, {
    String? status,
    int? limit,
    int? offset,
  }) {
    final where = status == null
        ? 'source_capture_id = ?'
        : 'source_capture_id = ? AND status = ?';
    final parameters = status == null
        ? <Object?>[captureId]
        : <Object?>[captureId, status];
    final rows = _selectOrdered(
      _database,
      'derived_artifacts',
      whereSql: where,
      parameters: parameters,
      limit: limit,
      offset: offset,
    );
    return rows.map(_derivedArtifactFromRow).toList(growable: false);
  }

  List<DerivedArtifactRecord> readByAttachment(
    String attachmentId, {
    String? status,
    int? limit,
    int? offset,
  }) {
    final where = status == null
        ? 'source_attachment_id = ?'
        : 'source_attachment_id = ? AND status = ?';
    final parameters = status == null
        ? <Object?>[attachmentId]
        : <Object?>[attachmentId, status];
    final rows = _selectOrdered(
      _database,
      'derived_artifacts',
      whereSql: where,
      parameters: parameters,
      limit: limit,
      offset: offset,
    );
    return rows.map(_derivedArtifactFromRow).toList(growable: false);
  }

  List<DerivedArtifactRecord> readAll({
    String? status,
    String? artifactKind,
    int? limit,
    int? offset,
  }) {
    final clauses = <String>[];
    final parameters = <Object?>[];
    if (status != null) {
      clauses.add('status = ?');
      parameters.add(status);
    }
    if (artifactKind != null) {
      clauses.add('artifact_kind = ?');
      parameters.add(artifactKind);
    }
    final rows = _selectOrdered(
      _database,
      'derived_artifacts',
      whereSql: clauses.isEmpty ? null : clauses.join(' AND '),
      parameters: parameters,
      limit: limit,
      offset: offset,
    );
    return rows.map(_derivedArtifactFromRow).toList(growable: false);
  }

  void _write(DerivedArtifactRecord artifact, {required bool allowUpdate}) {
    _requireDerivedArtifact(artifact);
    _execute(
      _database,
      '''
INSERT INTO derived_artifacts (
  id,
  schema_version,
  source_capture_id,
  source_attachment_id,
  source_event_id,
  artifact_kind,
  status,
  title,
  body,
  mime_type,
  storage_path,
  content_hash,
  source_refs_json,
  sensitivity,
  confidence,
  generator_id,
  generator_version,
  payload_json,
  created_at,
  updated_at,
  invalidated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
${allowUpdate ? _derivedArtifactUpsertClause : ';'}
''',
      <Object?>[
        artifact.id,
        artifact.schemaVersion,
        artifact.sourceCaptureId,
        artifact.sourceAttachmentId,
        artifact.sourceEventId,
        artifact.artifactKind,
        artifact.status,
        artifact.title,
        artifact.body,
        artifact.mimeType,
        artifact.storagePath,
        artifact.contentHash,
        encodeJsonList(artifact.sourceRefs),
        artifact.sensitivity,
        artifact.confidence,
        artifact.generatorId,
        artifact.generatorVersion,
        encodeJsonMap(artifact.payload),
        _encodeDateTime(artifact.createdAt),
        _encodeDateTime(artifact.updatedAt),
        artifact.invalidatedAt == null
            ? null
            : _encodeDateTime(artifact.invalidatedAt!),
      ],
    );
  }
}

void _requireDerivedArtifact(DerivedArtifactRecord artifact) {
  if (artifact.sourceCaptureId.trim().isEmpty) {
    throw ArgumentError.value(
      artifact.sourceCaptureId,
      'artifact.sourceCaptureId',
      'must not be empty',
    );
  }
  if (artifact.artifactKind.trim().isEmpty) {
    throw ArgumentError.value(
      artifact.artifactKind,
      'artifact.artifactKind',
      'must not be empty',
    );
  }
  if (artifact.title.trim().isEmpty) {
    throw ArgumentError.value(
      artifact.title,
      'artifact.title',
      'must not be empty',
    );
  }
  if (artifact.body.trim().isEmpty) {
    throw ArgumentError.value(
      artifact.body,
      'artifact.body',
      'must not be empty',
    );
  }
  if (artifact.generatorId.trim().isEmpty) {
    throw ArgumentError.value(
      artifact.generatorId,
      'artifact.generatorId',
      'must not be empty',
    );
  }
  if (artifact.generatorVersion.trim().isEmpty) {
    throw ArgumentError.value(
      artifact.generatorVersion,
      'artifact.generatorVersion',
      'must not be empty',
    );
  }
  _requireSourceRefs(artifact.sourceRefs, 'artifact.sourceRefs');
}

const _derivedArtifactUpsertClause = '''
ON CONFLICT(id) DO UPDATE SET
  schema_version = excluded.schema_version,
  source_capture_id = excluded.source_capture_id,
  source_attachment_id = excluded.source_attachment_id,
  source_event_id = excluded.source_event_id,
  artifact_kind = excluded.artifact_kind,
  status = excluded.status,
  title = excluded.title,
  body = excluded.body,
  mime_type = excluded.mime_type,
  storage_path = excluded.storage_path,
  content_hash = excluded.content_hash,
  source_refs_json = excluded.source_refs_json,
  sensitivity = excluded.sensitivity,
  confidence = excluded.confidence,
  generator_id = excluded.generator_id,
  generator_version = excluded.generator_version,
  payload_json = excluded.payload_json,
  updated_at = excluded.updated_at,
  invalidated_at = excluded.invalidated_at;
''';
