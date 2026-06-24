part of 'daos.dart';

final class InsightsDao {
  const InsightsDao(this._database);

  final Database _database;

  void insert(InsightRecord insight) {
    _write(insight, allowUpdate: false);
  }

  void save(InsightRecord insight) {
    _write(insight, allowUpdate: true);
  }

  InsightRecord? readById(String id) {
    final rows = _database.select(
      'SELECT * FROM insights WHERE id = ? LIMIT 1;',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _insightFromRow(rows.first);
  }

  List<InsightRecord> readAll({String? status, int? limit, int? offset}) {
    final rows = _selectOrdered(
      _database,
      'insights',
      whereSql: status == null ? null : 'status = ?',
      parameters: status == null ? const <Object?>[] : <Object?>[status],
      limit: limit,
      offset: offset,
    );
    return rows.map(_insightFromRow).toList(growable: false);
  }

  void _write(InsightRecord insight, {required bool allowUpdate}) {
    _requireSourceRefs(insight.sourceRefs, 'insight.sourceRefs');
    _execute(
      _database,
      '''
INSERT INTO insights (
  id,
  schema_version,
  insight_kind,
  status,
  title,
  summary,
  source_refs_json,
  metric_label,
  metric_value,
  payload_json,
  created_at,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
${allowUpdate ? _insightUpsertClause : ';'}
''',
      <Object?>[
        insight.id,
        insight.schemaVersion,
        insight.insightKind,
        insight.status,
        insight.title,
        insight.summary,
        encodeJsonList(insight.sourceRefs),
        insight.metricLabel,
        insight.metricValue,
        encodeJsonMap(insight.payload),
        _encodeDateTime(insight.createdAt),
        _encodeDateTime(insight.updatedAt),
      ],
    );
  }
}

const _insightUpsertClause = '''
ON CONFLICT(id) DO UPDATE SET
  schema_version = excluded.schema_version,
  insight_kind = excluded.insight_kind,
  status = excluded.status,
  title = excluded.title,
  summary = excluded.summary,
  source_refs_json = excluded.source_refs_json,
  metric_label = excluded.metric_label,
  metric_value = excluded.metric_value,
  payload_json = excluded.payload_json,
  updated_at = excluded.updated_at;
''';
