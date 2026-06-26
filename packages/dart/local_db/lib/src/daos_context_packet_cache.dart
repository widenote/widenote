part of 'daos.dart';

final class ContextPacketCachesDao {
  const ContextPacketCachesDao(this._database);

  final Database _database;

  void insert(ContextPacketCacheRecord cache) {
    _write(cache, allowUpdate: false);
  }

  void save(ContextPacketCacheRecord cache) {
    _write(cache, allowUpdate: true);
  }

  ContextPacketCacheRecord? readById(String id) {
    final rows = _database.select(
      'SELECT * FROM context_packet_cache WHERE id = ? LIMIT 1;',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _contextPacketCacheFromRow(rows.first);
  }

  ContextPacketCacheRecord? readByCacheKey(String cacheKey) {
    final rows = _database.select(
      'SELECT * FROM context_packet_cache WHERE cache_key = ? LIMIT 1;',
      <Object?>[cacheKey],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _contextPacketCacheFromRow(rows.first);
  }

  ContextPacketCacheRecord? readReusableByCacheKey(
    String cacheKey, {
    DateTime? now,
  }) {
    final cache = readByCacheKey(cacheKey);
    if (cache == null) {
      return null;
    }
    return cache.isReusableAt(now ?? DateTime.now().toUtc()) ? cache : null;
  }

  List<ContextPacketCacheRecord> readAll({
    String? status,
    int? limit,
    int? offset,
  }) {
    final rows = _selectOrdered(
      _database,
      'context_packet_cache',
      whereSql: status == null ? null : 'status = ?',
      parameters: status == null ? const <Object?>[] : <Object?>[status],
      limit: limit,
      offset: offset,
    );
    return rows.map(_contextPacketCacheFromRow).toList(growable: false);
  }

  List<ContextPacketCacheRecord> readBySurface(
    String surface, {
    String? status,
    int? limit,
    int? offset,
  }) {
    final rows = _selectOrdered(
      _database,
      'context_packet_cache',
      whereSql: status == null ? 'surface = ?' : 'surface = ? AND status = ?',
      parameters: status == null
          ? <Object?>[surface]
          : <Object?>[surface, status],
      limit: limit,
      offset: offset,
    );
    return rows.map(_contextPacketCacheFromRow).toList(growable: false);
  }

  int invalidateByKeys(
    Iterable<String> invalidationKeys, {
    DateTime? invalidatedAt,
    String reason = 'dependency_changed',
  }) {
    final keys = invalidationKeys.toSet();
    if (keys.isEmpty) {
      return 0;
    }
    final now = invalidatedAt ?? DateTime.now().toUtc();
    final affected = readAll(status: 'active')
        .where(
          (cache) =>
              cache.invalidationKeys.whereType<String>().any(keys.contains),
        )
        .toList(growable: false);
    for (final cache in affected) {
      save(
        cache
            .copyWith(
              status: 'invalidated',
              invalidatedAt: now,
              updatedAt: now,
              packet: cache.packet,
              invalidationKeys: cache.invalidationKeys,
              cacheKey: cache.cacheKey,
              privacyProfile: cache.privacyProfile,
              requestRef: cache.requestRef,
              subjectRef: cache.subjectRef,
              sourceRefs: cache.sourceRefs,
              sourceVersions: cache.sourceVersions,
            )
            .copyWith(
              packet: _mergeJson(cache.packet, <String, Object?>{
                '_cache_invalidation_reason': reason,
              }),
            ),
      );
    }
    return affected.length;
  }

  void _write(ContextPacketCacheRecord cache, {required bool allowUpdate}) {
    if (cache.sourceRefs.isEmpty) {
      throw ArgumentError.value(
        cache.sourceRefs,
        'sourceRefs',
        'must not be empty',
      );
    }
    if (cache.sourceVersions.isEmpty) {
      throw ArgumentError.value(
        cache.sourceVersions,
        'sourceVersions',
        'must not be empty',
      );
    }
    _execute(
      _database,
      '''
INSERT INTO context_packet_cache (
  id,
  schema_version,
  surface,
  request_ref_json,
  subject_ref_json,
  source_refs_json,
  source_versions_json,
  permission_scope,
  disclosure_level,
  generator_id,
  generator_version,
  prompt_version,
  pack_id,
  pack_version,
  agent_id,
  local_date,
  privacy_profile,
  invalidation_keys_json,
  cache_key,
  status,
  packet_json,
  expires_at,
  invalidated_at,
  created_at,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
${allowUpdate ? _contextPacketCacheUpsertClause : ';'}
''',
      <Object?>[
        cache.id,
        cache.schemaVersion,
        cache.surface,
        encodeJsonMap(cache.requestRef),
        encodeJsonMap(cache.subjectRef),
        encodeJsonList(cache.sourceRefs),
        encodeJsonList(cache.sourceVersions),
        cache.permissionScope,
        cache.disclosureLevel,
        cache.generatorId,
        cache.generatorVersion,
        cache.promptVersion,
        cache.packId,
        cache.packVersion,
        cache.agentId,
        cache.localDate,
        cache.privacyProfile,
        encodeJsonList(cache.invalidationKeys),
        cache.cacheKey,
        cache.status,
        encodeJsonMap(cache.packet),
        cache.expiresAt == null ? null : _encodeDateTime(cache.expiresAt!),
        cache.invalidatedAt == null
            ? null
            : _encodeDateTime(cache.invalidatedAt!),
        _encodeDateTime(cache.createdAt),
        _encodeDateTime(cache.updatedAt),
      ],
    );
  }
}

const _contextPacketCacheUpsertClause = '''
ON CONFLICT(id) DO UPDATE SET
  schema_version = excluded.schema_version,
  surface = excluded.surface,
  request_ref_json = excluded.request_ref_json,
  subject_ref_json = excluded.subject_ref_json,
  source_refs_json = excluded.source_refs_json,
  source_versions_json = excluded.source_versions_json,
  permission_scope = excluded.permission_scope,
  disclosure_level = excluded.disclosure_level,
  generator_id = excluded.generator_id,
  generator_version = excluded.generator_version,
  prompt_version = excluded.prompt_version,
  pack_id = excluded.pack_id,
  pack_version = excluded.pack_version,
  agent_id = excluded.agent_id,
  local_date = excluded.local_date,
  privacy_profile = excluded.privacy_profile,
  invalidation_keys_json = excluded.invalidation_keys_json,
  cache_key = excluded.cache_key,
  status = excluded.status,
  packet_json = excluded.packet_json,
  expires_at = excluded.expires_at,
  invalidated_at = excluded.invalidated_at,
  updated_at = excluded.updated_at;
''';
