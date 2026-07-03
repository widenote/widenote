part of 'daos.dart';

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

  void save(MemoryCandidateRecord candidate) {
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
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
  candidate_key = excluded.candidate_key,
  schema_version = excluded.schema_version,
  source_capture_id = excluded.source_capture_id,
  source_event_id = excluded.source_event_id,
  status = excluded.status,
  body = excluded.body,
  source_refs_json = excluded.source_refs_json,
  memory_type = excluded.memory_type,
  confidence = excluded.confidence,
  sensitivity = excluded.sensitivity,
  payload_json = excluded.payload_json,
  updated_at = excluded.updated_at;
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

  List<MemoryCandidateRecord> readByCreatedAtRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
    String? status,
    int? limit,
    int? offset,
  }) {
    final rows = _selectOrdered(
      _database,
      'memory_candidates',
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
    return rows.map(_memoryCandidateFromRow).toList(growable: false);
  }

  List<MemoryCandidateRecord> readReviewQueue({int? limit, int? offset}) {
    return readAll(status: 'needs_review', limit: limit, offset: offset);
  }

  MemoryCandidateRecord editCandidateBody(
    String id, {
    required String body,
    DateTime? updatedAt,
  }) {
    final existing = _requireCandidate(id);
    final updated = existing.copyWith(
      body: _reviewBody(body),
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
    save(updated);
    return updated;
  }

  MemoryCandidateRecord rejectCandidate(
    String id, {
    String reason = 'user_rejected',
    DateTime? rejectedAt,
  }) {
    final existing = _requireCandidate(id);
    final updated = existing.copyWith(
      status: 'rejected',
      payload: _mergeJson(existing.payload, <String, Object?>{
        'review_rejection_reason': reason,
      }),
      updatedAt: rejectedAt ?? DateTime.now().toUtc(),
    );
    save(updated);
    return updated;
  }

  MemoryItemRecord acceptCandidate(
    String id, {
    required String itemId,
    String? body,
    DateTime? acceptedAt,
  }) {
    return _runTransaction(_database, () {
      final existing = _requireCandidate(id);
      final now = acceptedAt ?? DateTime.now().toUtc();
      final acceptedBody = body == null ? existing.body : _reviewBody(body);
      final accepted = existing.copyWith(
        status: 'accepted',
        body: acceptedBody,
        payload: _mergeJson(existing.payload, <String, Object?>{
          'accepted_memory_id': itemId,
          'review_decision': 'accepted',
        }),
        updatedAt: now,
      );
      save(accepted);

      final item = MemoryItemRecord(
        id: itemId,
        key: existing.key,
        schemaVersion: existing.schemaVersion,
        sourceCaptureId: existing.sourceCaptureId,
        sourceEventId: existing.sourceEventId,
        body: acceptedBody,
        sourceRefs: existing.sourceRefs,
        memoryType: existing.memoryType,
        confidence: existing.confidence,
        sensitivity: existing.sensitivity,
        payload: _mergeJson(existing.payload, <String, Object?>{
          'accepted_from_candidate_id': existing.id,
        }),
        createdAt: now,
        updatedAt: now,
      );
      MemoryItemsDao(_database).save(item);
      return item;
    });
  }

  MemoryItemRecord mergeCandidate(
    String id, {
    required String targetMemoryId,
    String? mergedBody,
    DateTime? mergedAt,
  }) {
    return _runTransaction(_database, () {
      final candidate = _requireCandidate(id);
      final existingItem = MemoryItemsDao(_database).readById(targetMemoryId);
      if (existingItem == null || existingItem.status != 'active') {
        throw StateError('Active Memory item not found: $targetMemoryId');
      }

      final now = mergedAt ?? DateTime.now().toUtc();
      final body = mergedBody == null
          ? candidate.body
          : _reviewBody(mergedBody);
      final mergedItem = existingItem.copyWith(
        body: body,
        sourceRefs: _mergeJsonLists(
          existingItem.sourceRefs,
          candidate.sourceRefs,
        ),
        confidence: candidate.confidence,
        sensitivity: candidate.sensitivity,
        revision: existingItem.revision + 1,
        updatedAt: now,
      );
      MemoryItemsDao(_database).save(mergedItem);

      final mergedCandidate = candidate.copyWith(
        status: 'merged',
        body: body,
        payload: _mergeJson(candidate.payload, <String, Object?>{
          'merged_memory_id': targetMemoryId,
          'review_decision': 'merged',
        }),
        updatedAt: now,
      );
      save(mergedCandidate);
      return mergedItem;
    });
  }

  MemoryCandidateRecord _requireCandidate(String id) {
    final existing = readById(id);
    if (existing == null) {
      throw StateError('Memory candidate not found: $id');
    }
    return existing;
  }
}
