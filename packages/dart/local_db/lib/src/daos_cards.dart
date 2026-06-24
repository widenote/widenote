part of 'daos.dart';

final class CardsDao {
  const CardsDao(this._database);

  final Database _database;

  void insert(CardRecord card) {
    _write(card, allowUpdate: false);
  }

  void save(CardRecord card) {
    _write(card, allowUpdate: true);
  }

  CardRecord? readById(String id) {
    final rows = _database.select(
      'SELECT * FROM cards WHERE id = ? LIMIT 1;',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _cardFromRow(rows.first);
  }

  List<CardRecord> readAll({String? status, int? limit, int? offset}) {
    final rows = _selectOrdered(
      _database,
      'cards',
      whereSql: status == null ? null : 'status = ?',
      parameters: status == null ? const <Object?>[] : <Object?>[status],
      limit: limit,
      offset: offset,
    );
    return rows.map(_cardFromRow).toList(growable: false);
  }

  void _write(CardRecord card, {required bool allowUpdate}) {
    _requireSourceRefs(card.sourceRefs, 'card.sourceRefs');
    _execute(
      _database,
      '''
INSERT INTO cards (
  id,
  schema_version,
  card_kind,
  status,
  title,
  body,
  source_refs_json,
  payload_json,
  created_at,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
${allowUpdate ? _cardUpsertClause : ';'}
''',
      <Object?>[
        card.id,
        card.schemaVersion,
        card.cardKind,
        card.status,
        card.title,
        card.body,
        encodeJsonList(card.sourceRefs),
        encodeJsonMap(card.payload),
        _encodeDateTime(card.createdAt),
        _encodeDateTime(card.updatedAt),
      ],
    );
  }
}

const _cardUpsertClause = '''
ON CONFLICT(id) DO UPDATE SET
  schema_version = excluded.schema_version,
  card_kind = excluded.card_kind,
  status = excluded.status,
  title = excluded.title,
  body = excluded.body,
  source_refs_json = excluded.source_refs_json,
  payload_json = excluded.payload_json,
  updated_at = excluded.updated_at;
''';
