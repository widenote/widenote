part of 'daos.dart';

final class ModelProviderConfigsDao {
  const ModelProviderConfigsDao(this._database);

  final Database _database;

  void insert(ModelProviderConfigRecord config) {
    _write(config, allowUpdate: false);
  }

  void save(ModelProviderConfigRecord config) {
    _write(config, allowUpdate: true);
  }

  void saveAll(
    List<ModelProviderConfigRecord> configs, {
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

  ModelProviderConfigRecord? readById(String id) {
    final rows = _database.select(
      'SELECT * FROM model_provider_configs WHERE id = ? LIMIT 1;',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _modelProviderConfigFromRow(rows.first);
  }

  List<ModelProviderConfigRecord> readAll({
    String? status,
    int? limit,
    int? offset,
  }) {
    final rows = _selectOrdered(
      _database,
      'model_provider_configs',
      whereSql: status == null ? null : 'status = ?',
      parameters: status == null ? const <Object?>[] : <Object?>[status],
      limit: limit,
      offset: offset,
    );
    return rows.map(_modelProviderConfigFromRow).toList(growable: false);
  }

  ModelProviderConfigRecord? readDefault() {
    final rows = _database.select('''
SELECT * FROM model_provider_configs
WHERE is_default = 1 AND status = 'active'
ORDER BY updated_at DESC
LIMIT 1;
''');
    if (rows.isEmpty) {
      return null;
    }
    return _modelProviderConfigFromRow(rows.first);
  }

  void markDefault(String id) {
    _runTransaction(_database, () => _markDefaultWithoutTransaction(id));
  }

  void _markDefaultWithoutTransaction(String id) {
    _database.execute('UPDATE model_provider_configs SET is_default = 0;');
    _database.execute(
      '''
UPDATE model_provider_configs
SET is_default = 1
WHERE id = ?;
''',
      <Object?>[id],
    );
  }

  void _write(ModelProviderConfigRecord config, {required bool allowUpdate}) {
    _execute(
      _database,
      '''
INSERT INTO model_provider_configs (
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
  capabilities_json,
  payload_json,
  created_at,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
${allowUpdate ? _modelProviderConfigUpsertClause : ';'}
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
        encodeJsonList(config.capabilities),
        encodeJsonMap(config.payload),
        _encodeDateTime(config.createdAt),
        _encodeDateTime(config.updatedAt),
      ],
    );
  }
}

extension on ModelProviderConfigRecord {
  ModelProviderConfigRecord copyWithDefault({required bool isDefault}) {
    return ModelProviderConfigRecord(
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
      capabilities: capabilities,
      payload: payload,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

const _modelProviderConfigUpsertClause = '''
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
  capabilities_json = excluded.capabilities_json,
  payload_json = excluded.payload_json,
  updated_at = excluded.updated_at;
''';
