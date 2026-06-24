part of 'daos.dart';

void _execute(Database database, String sql, List<Object?> parameters) {
  final statement = database.prepare(sql);
  try {
    statement.execute(parameters);
  } finally {
    statement.dispose();
  }
}

T _runTransaction<T>(Database database, T Function() body) {
  database.execute('BEGIN IMMEDIATE;');
  try {
    final result = body();
    database.execute('COMMIT;');
    return result;
  } catch (_) {
    database.execute('ROLLBACK;');
    rethrow;
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
