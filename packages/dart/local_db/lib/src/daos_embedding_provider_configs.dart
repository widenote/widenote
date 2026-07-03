part of 'daos.dart';

final class EmbeddingProviderConfigsDao {
  const EmbeddingProviderConfigsDao(this._database);

  final Database _database;

  void insert(EmbeddingProviderConfigRecord config) {
    _write(config, allowUpdate: false);
  }

  void save(EmbeddingProviderConfigRecord config) {
    _write(config, allowUpdate: true);
  }

  void saveAll(
    List<EmbeddingProviderConfigRecord> configs, {
    required String? defaultId,
  }) {
    _runTransaction(_database, () {
      for (final config in configs) {
        _write(
          config.copyWithDefault(isDefault: config.id == defaultId),
          allowUpdate: true,
        );
      }
      if (defaultId != null) {
        _markDefaultWithoutTransaction(defaultId);
      }
    });
  }

  EmbeddingProviderConfigRecord? readById(String id) {
    final rows = _database.select(
      'SELECT * FROM embedding_provider_configs WHERE id = ? LIMIT 1;',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _embeddingProviderConfigFromRow(rows.first);
  }

  List<EmbeddingProviderConfigRecord> readAll({
    String? status,
    int? limit,
    int? offset,
  }) {
    final rows = _selectOrdered(
      _database,
      'embedding_provider_configs',
      whereSql: status == null ? null : 'status = ?',
      parameters: status == null ? const <Object?>[] : <Object?>[status],
      limit: limit,
      offset: offset,
    );
    return rows.map(_embeddingProviderConfigFromRow).toList(growable: false);
  }

  EmbeddingProviderConfigRecord? readDefault() {
    final rows = _database.select('''
SELECT * FROM embedding_provider_configs
WHERE is_default = 1 AND status = 'active'
ORDER BY updated_at DESC
LIMIT 1;
''');
    if (rows.isEmpty) {
      return null;
    }
    return _embeddingProviderConfigFromRow(rows.first);
  }

  void markDefault(String id) {
    _runTransaction(_database, () => _markDefaultWithoutTransaction(id));
  }

  void _markDefaultWithoutTransaction(String id) {
    _database.execute('UPDATE embedding_provider_configs SET is_default = 0;');
    _database.execute(
      '''
UPDATE embedding_provider_configs
SET is_default = 1
WHERE id = ?;
''',
      <Object?>[id],
    );
  }

  void _write(
    EmbeddingProviderConfigRecord config, {
    required bool allowUpdate,
  }) {
    _execute(
      _database,
      '''
INSERT INTO embedding_provider_configs (
  id,
  schema_version,
  provider_kind,
  display_name,
  endpoint,
  model,
  status,
  is_default,
  has_api_key,
  api_key,
  dimensions,
  batch_size,
  payload_json,
  created_at,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
${allowUpdate ? _embeddingProviderConfigUpsertClause : ';'}
''',
      <Object?>[
        config.id,
        config.schemaVersion,
        config.providerKind,
        config.displayName,
        config.endpoint,
        config.model,
        config.status,
        _encodeBool(config.isDefault),
        _encodeBool(config.hasApiKey),
        config.apiKey,
        config.dimensions,
        config.batchSize,
        encodeJsonMap(config.payload),
        _encodeDateTime(config.createdAt),
        _encodeDateTime(config.updatedAt),
      ],
    );
  }
}

extension on EmbeddingProviderConfigRecord {
  EmbeddingProviderConfigRecord copyWithDefault({required bool isDefault}) {
    return EmbeddingProviderConfigRecord(
      id: id,
      schemaVersion: schemaVersion,
      providerKind: providerKind,
      displayName: displayName,
      endpoint: endpoint,
      model: model,
      status: status,
      isDefault: isDefault,
      hasApiKey: hasApiKey,
      apiKey: apiKey,
      dimensions: dimensions,
      batchSize: batchSize,
      payload: payload,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

const _embeddingProviderConfigUpsertClause = '''
ON CONFLICT(id) DO UPDATE SET
  schema_version = excluded.schema_version,
  provider_kind = excluded.provider_kind,
  display_name = excluded.display_name,
  endpoint = excluded.endpoint,
  model = excluded.model,
  status = excluded.status,
  is_default = excluded.is_default,
  has_api_key = excluded.has_api_key,
  api_key = excluded.api_key,
  dimensions = excluded.dimensions,
  batch_size = excluded.batch_size,
  payload_json = excluded.payload_json,
  updated_at = excluded.updated_at;
''';
