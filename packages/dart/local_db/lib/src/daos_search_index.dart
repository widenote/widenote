part of 'daos.dart';

final class SearchIndexDao {
  const SearchIndexDao(this._database);

  final Database _database;

  LocalSearchIndexRebuildSummary rebuildFromLocalTruth({
    int chunkSize = 900,
    int chunkOverlap = 120,
  }) {
    final documents = _localSearchDocuments(_database);
    final chunks = <SearchChunkRecord>[
      for (final document in documents)
        ..._chunksForDocument(
          document,
          chunkSize: chunkSize,
          chunkOverlap: chunkOverlap,
        ),
    ];
    if (_projectionMatches(documents, chunks)) {
      return LocalSearchIndexRebuildSummary(
        documentCount: documents.length,
        chunkCount: chunks.length,
      );
    }
    _runTransaction(_database, () {
      _database.execute('DELETE FROM search_chunks_fts;');
      for (final document in documents) {
        _writeDocument(document.record);
      }
      for (final chunk in chunks) {
        _writeChunk(chunk);
      }
      _deleteRowsExcept(
        table: 'search_chunks',
        idColumn: 'id',
        keepIds: chunks.map((chunk) => chunk.id).toSet(),
      );
      _deleteRowsExcept(
        table: 'search_documents',
        idColumn: 'id',
        keepIds: documents.map((document) => document.record.id).toSet(),
      );
    });
    return LocalSearchIndexRebuildSummary(
      documentCount: documents.length,
      chunkCount: chunks.length,
    );
  }

  LocalSearchResultSet search(LocalSearchRequest request) {
    final normalizedLimit = _positiveLimit(request.limit, defaultValue: 10);
    final keywordLimit = _positiveLimit(
      request.keywordLimit,
      defaultValue: math.max(80, normalizedLimit),
    );
    final semanticLimit = _positiveLimit(
      request.semanticLimit,
      defaultValue: math.max(80, normalizedLimit),
    );
    final keywordHits = request.mode == LocalSearchMode.semantic
        ? const <_RankedKeywordHit>[]
        : _keywordHits(request, limit: keywordLimit);
    final semanticHits = request.mode == LocalSearchMode.keyword
        ? const <_RankedSemanticHit>[]
        : _semanticHits(request, limit: semanticLimit);
    final results = _fuseHits(
      keywordHits: keywordHits,
      semanticHits: semanticHits,
      fusionK: math.max(1, request.fusionK),
      limit: normalizedLimit,
    );
    return LocalSearchResultSet(
      query: request.query,
      mode: request.mode,
      results: results,
      keywordCandidateCount: keywordHits.length,
      semanticCandidateCount: semanticHits.length,
      embeddingUsed: semanticHits.isNotEmpty,
    );
  }

  SearchDocumentRecord? readDocument(String id) {
    final rows = _database.select(
      'SELECT * FROM search_documents WHERE id = ? LIMIT 1;',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _searchDocumentFromRow(rows.first);
  }

  SearchChunkRecord? readChunk(String id) {
    final rows = _database.select(
      'SELECT * FROM search_chunks WHERE id = ? LIMIT 1;',
      <Object?>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _searchChunkFromRow(rows.first);
  }

  SearchChunkRecord? readFirstChunkForDocument(String docId) {
    final rows = _database.select(
      '''
SELECT *
FROM search_chunks
WHERE doc_id = ?
ORDER BY chunk_index ASC
LIMIT 1;
''',
      <Object?>[docId],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _searchChunkFromRow(rows.first);
  }

  List<SearchChunkRecord> readChunksMissingEmbedding({
    required String providerId,
    required String model,
    int limit = 64,
  }) {
    final rows = _database.select(
      '''
SELECT c.*
FROM search_chunks c
LEFT JOIN search_chunk_embeddings e
  ON e.chunk_id = c.id AND e.provider_id = ? AND e.model = ?
WHERE c.status != 'deleted'
  AND (e.chunk_id IS NULL OR e.content_hash != c.content_hash)
ORDER BY c.updated_at DESC, c.id
LIMIT ?;
''',
      <Object?>[providerId, model, _positiveLimit(limit, defaultValue: 64)],
    );
    return rows.map(_searchChunkFromRow).toList(growable: false);
  }

  void saveChunkEmbedding({
    required String chunkId,
    required String providerId,
    required String model,
    required List<double> embedding,
    required DateTime updatedAt,
  }) {
    final chunk = readChunk(chunkId);
    if (chunk == null) {
      throw StateError('Search chunk not found: $chunkId');
    }
    if (embedding.isEmpty) {
      throw ArgumentError.value(embedding, 'embedding', 'must not be empty');
    }
    _execute(
      _database,
      '''
INSERT INTO search_chunk_embeddings (
  chunk_id,
  provider_id,
  model,
  dimensions,
  embedding_blob,
  content_hash,
  created_at,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(chunk_id, provider_id, model) DO UPDATE SET
  dimensions = excluded.dimensions,
  embedding_blob = excluded.embedding_blob,
  content_hash = excluded.content_hash,
  updated_at = excluded.updated_at;
''',
      <Object?>[
        chunkId,
        providerId,
        model,
        embedding.length,
        _embeddingBlob(embedding),
        chunk.contentHash,
        _encodeDateTime(updatedAt),
        _encodeDateTime(updatedAt),
      ],
    );
  }

  List<SearchDocumentRecord> listDocuments({
    String? sourceKind,
    int limit = 50,
  }) {
    final rows = _selectOrderedBy(
      _database,
      'search_documents',
      orderBy: 'updated_at DESC, id',
      whereSql: sourceKind == null ? null : 'source_kind = ?',
      parameters: sourceKind == null
          ? const <Object?>[]
          : <Object?>[sourceKind],
      limit: _positiveLimit(limit, defaultValue: 50),
    );
    return rows.map(_searchDocumentFromRow).toList(growable: false);
  }

  bool _projectionMatches(
    List<_LocalSearchDocument> documents,
    List<SearchChunkRecord> chunks,
  ) {
    if (!_documentRowsMatch([
      for (final document in documents) document.record,
    ])) {
      return false;
    }
    if (!_chunkRowsMatch(chunks)) {
      return false;
    }
    final ftsRows = _database.select(
      'SELECT COUNT(*) AS count FROM search_chunks_fts;',
    );
    final ftsCount = ftsRows.first['count'] as int;
    return ftsCount == chunks.length;
  }

  bool _documentRowsMatch(List<SearchDocumentRecord> expected) {
    final rows = _database.select('SELECT * FROM search_documents;');
    if (rows.length != expected.length) {
      return false;
    }
    final byId = <String, SearchDocumentRecord>{
      for (final document in expected) document.id: document,
    };
    for (final row in rows) {
      final id = row['id'] as String;
      final document = byId[id];
      if (document == null || !_documentRowMatches(row, document)) {
        return false;
      }
    }
    return true;
  }

  bool _chunkRowsMatch(List<SearchChunkRecord> expected) {
    final rows = _database.select('SELECT * FROM search_chunks;');
    if (rows.length != expected.length) {
      return false;
    }
    final byId = <String, SearchChunkRecord>{
      for (final chunk in expected) chunk.id: chunk,
    };
    for (final row in rows) {
      final id = row['id'] as String;
      final chunk = byId[id];
      if (chunk == null || !_chunkRowMatches(row, chunk)) {
        return false;
      }
    }
    return true;
  }

  bool _documentRowMatches(Row row, SearchDocumentRecord document) {
    return row['schema_version'] == document.schemaVersion &&
        row['source_kind'] == document.sourceKind &&
        row['source_id'] == document.sourceId &&
        row['source_type'] == document.sourceType &&
        row['title'] == document.title &&
        row['status'] == document.status &&
        row['sensitivity'] == document.sensitivity &&
        row['source_refs_json'] == encodeJsonList(document.sourceRefs) &&
        row['metadata_json'] == encodeJsonMap(document.metadata) &&
        row['content_hash'] == document.contentHash &&
        row['created_at'] == _encodeDateTime(document.createdAt) &&
        row['updated_at'] == _encodeDateTime(document.updatedAt);
  }

  bool _chunkRowMatches(Row row, SearchChunkRecord chunk) {
    return row['schema_version'] == chunk.schemaVersion &&
        row['doc_id'] == chunk.docId &&
        row['source_kind'] == chunk.sourceKind &&
        row['source_id'] == chunk.sourceId &&
        row['source_type'] == chunk.sourceType &&
        row['title'] == chunk.title &&
        row['body'] == chunk.body &&
        row['snippet'] == chunk.snippet &&
        row['token_text'] == chunk.tokenText &&
        row['status'] == chunk.status &&
        row['sensitivity'] == chunk.sensitivity &&
        row['source_refs_json'] == encodeJsonList(chunk.sourceRefs) &&
        row['metadata_json'] == encodeJsonMap(chunk.metadata) &&
        row['content_hash'] == chunk.contentHash &&
        row['chunk_index'] == chunk.chunkIndex &&
        row['created_at'] == _encodeDateTime(chunk.createdAt) &&
        row['updated_at'] == _encodeDateTime(chunk.updatedAt);
  }

  void _deleteRowsExcept({
    required String table,
    required String idColumn,
    required Set<String> keepIds,
  }) {
    if (keepIds.isEmpty) {
      _database.execute('DELETE FROM $table;');
      return;
    }
    final placeholders = List.filled(keepIds.length, '?').join(', ');
    _execute(
      _database,
      'DELETE FROM $table WHERE $idColumn NOT IN ($placeholders);',
      keepIds.toList(growable: false),
    );
  }

  void _writeDocument(SearchDocumentRecord document) {
    _execute(
      _database,
      '''
INSERT INTO search_documents (
  id,
  schema_version,
  source_kind,
  source_id,
  source_type,
  title,
  status,
  sensitivity,
  source_refs_json,
  metadata_json,
  content_hash,
  created_at,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
  schema_version = excluded.schema_version,
  source_kind = excluded.source_kind,
  source_id = excluded.source_id,
  source_type = excluded.source_type,
  title = excluded.title,
  status = excluded.status,
  sensitivity = excluded.sensitivity,
  source_refs_json = excluded.source_refs_json,
  metadata_json = excluded.metadata_json,
  content_hash = excluded.content_hash,
  created_at = excluded.created_at,
  updated_at = excluded.updated_at;
''',
      <Object?>[
        document.id,
        document.schemaVersion,
        document.sourceKind,
        document.sourceId,
        document.sourceType,
        document.title,
        document.status,
        document.sensitivity,
        encodeJsonList(document.sourceRefs),
        encodeJsonMap(document.metadata),
        document.contentHash,
        _encodeDateTime(document.createdAt),
        _encodeDateTime(document.updatedAt),
      ],
    );
  }

  void _writeChunk(SearchChunkRecord chunk) {
    _execute(
      _database,
      '''
INSERT INTO search_chunks (
  id,
  schema_version,
  doc_id,
  source_kind,
  source_id,
  source_type,
  title,
  body,
  snippet,
  token_text,
  status,
  sensitivity,
  source_refs_json,
  metadata_json,
  content_hash,
  chunk_index,
  created_at,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
  schema_version = excluded.schema_version,
  doc_id = excluded.doc_id,
  source_kind = excluded.source_kind,
  source_id = excluded.source_id,
  source_type = excluded.source_type,
  title = excluded.title,
  body = excluded.body,
  snippet = excluded.snippet,
  token_text = excluded.token_text,
  status = excluded.status,
  sensitivity = excluded.sensitivity,
  source_refs_json = excluded.source_refs_json,
  metadata_json = excluded.metadata_json,
  content_hash = excluded.content_hash,
  chunk_index = excluded.chunk_index,
  created_at = excluded.created_at,
  updated_at = excluded.updated_at;
''',
      <Object?>[
        chunk.id,
        chunk.schemaVersion,
        chunk.docId,
        chunk.sourceKind,
        chunk.sourceId,
        chunk.sourceType,
        chunk.title,
        chunk.body,
        chunk.snippet,
        chunk.tokenText,
        chunk.status,
        chunk.sensitivity,
        encodeJsonList(chunk.sourceRefs),
        encodeJsonMap(chunk.metadata),
        chunk.contentHash,
        chunk.chunkIndex,
        _encodeDateTime(chunk.createdAt),
        _encodeDateTime(chunk.updatedAt),
      ],
    );
    _execute(
      _database,
      '''
INSERT INTO search_chunks_fts (chunk_id, title, body, token_text)
VALUES (?, ?, ?, ?);
''',
      <Object?>[chunk.id, chunk.title, chunk.body, chunk.tokenText],
    );
  }

  List<_RankedKeywordHit> _keywordHits(
    LocalSearchRequest request, {
    required int limit,
  }) {
    final query = _ftsQuery(request.query);
    final rows = <Row>[
      if (query.isEmpty)
        ..._recentChunkRows(request, limit: limit)
      else ...[
        ..._ftsChunkRows(request, query: query, limit: limit),
        if (request.sourceRefs.isNotEmpty)
          ..._recentChunkRows(request, limit: limit),
      ],
    ];
    final hits = <_RankedKeywordHit>[];
    final seen = <String>{};
    var rank = 1;
    for (final row in rows) {
      final chunk = _searchChunkFromRow(row);
      if (!seen.add(chunk.id)) {
        continue;
      }
      if (!_matchesRequestFilters(chunk, request)) {
        continue;
      }
      final rawScore = row['rank'] as num?;
      hits.add(
        _RankedKeywordHit(
          chunk: chunk,
          rank: rank++,
          score: 1 / (1 + (rawScore?.abs() ?? 0)),
        ),
      );
    }
    return hits;
  }

  ResultSet _ftsChunkRows(
    LocalSearchRequest request, {
    required String query,
    required int limit,
  }) {
    final filter = _sqlFilter(request, tableAlias: 'c');
    return _database.select(
      '''
SELECT c.*, bm25(search_chunks_fts) AS rank
FROM search_chunks_fts
JOIN search_chunks c ON c.id = search_chunks_fts.chunk_id
WHERE search_chunks_fts MATCH ?
${filter.sql}
ORDER BY rank ASC, c.updated_at DESC
LIMIT ?;
''',
      <Object?>[query, ...filter.parameters, limit],
    );
  }

  ResultSet _recentChunkRows(LocalSearchRequest request, {required int limit}) {
    final filter = _sqlFilter(request, tableAlias: 'c');
    return _database.select(
      '''
SELECT c.*, 0.0 AS rank
FROM search_chunks c
WHERE 1 = 1
${filter.sql}
ORDER BY c.updated_at DESC, c.id
LIMIT ?;
''',
      <Object?>[...filter.parameters, limit],
    );
  }

  List<_RankedSemanticHit> _semanticHits(
    LocalSearchRequest request, {
    required int limit,
  }) {
    final queryEmbedding = request.queryEmbedding;
    final providerId = request.embeddingProviderId;
    final model = request.embeddingModel;
    if (queryEmbedding == null ||
        queryEmbedding.isEmpty ||
        providerId == null ||
        providerId.trim().isEmpty ||
        model == null ||
        model.trim().isEmpty) {
      return const <_RankedSemanticHit>[];
    }
    final filter = _sqlFilter(request, tableAlias: 'c');
    final rows = _database.select(
      '''
SELECT c.*, e.embedding_blob
FROM search_chunk_embeddings e
JOIN search_chunks c ON c.id = e.chunk_id
WHERE e.provider_id = ?
  AND e.model = ?
  AND e.content_hash = c.content_hash
${filter.sql}
ORDER BY c.updated_at DESC, c.id;
''',
      <Object?>[providerId, model, ...filter.parameters],
    );
    final scored = <_ScoredSemanticChunk>[];
    for (final row in rows) {
      final chunk = _searchChunkFromRow(row);
      if (!_matchesRequestFilters(chunk, request)) {
        continue;
      }
      final bytes = row['embedding_blob'] as Uint8List;
      final score = _cosineSimilarity(
        queryEmbedding,
        _embeddingFromBlob(bytes),
      );
      if (score.isNaN) {
        continue;
      }
      scored.add(_ScoredSemanticChunk(chunk: chunk, score: score));
    }
    scored.sort((a, b) {
      final score = b.score.compareTo(a.score);
      return score == 0
          ? b.chunk.updatedAt.compareTo(a.chunk.updatedAt)
          : score;
    });
    return [
      for (var index = 0; index < math.min(limit, scored.length); index += 1)
        _RankedSemanticHit(
          chunk: scored[index].chunk,
          rank: index + 1,
          score: scored[index].score,
        ),
    ];
  }
}

final class LocalSearchIndexRebuildSummary {
  const LocalSearchIndexRebuildSummary({
    required this.documentCount,
    required this.chunkCount,
  });

  final int documentCount;
  final int chunkCount;
}

final class SearchTextTokenizer {
  const SearchTextTokenizer._();

  static String tokenText(String input) {
    return tokens(input).join(' ');
  }

  static List<String> tokens(String input) {
    final seen = <String>{};
    final result = <String>[];
    for (final token in _tokens(input)) {
      if (token.length > 64) {
        continue;
      }
      if (seen.add(token)) {
        result.add(token);
      }
    }
    return result;
  }

  static Iterable<String> _tokens(String input) {
    final output = <String>[];
    final word = StringBuffer();
    final cjk = <int>[];

    void flushWord() {
      if (word.length >= 2) {
        final token = word.toString().toLowerCase();
        output.add(token);
      }
      word.clear();
    }

    void flushCjk() {
      if (cjk.isEmpty) {
        return;
      }
      final chars = cjk.map(String.fromCharCode).toList(growable: false);
      for (final char in chars) {
        output.add(char);
      }
      for (var index = 0; index + 1 < chars.length; index += 1) {
        output.add(chars[index] + chars[index + 1]);
      }
      for (var index = 0; index + 2 < chars.length; index += 1) {
        output.add(chars[index] + chars[index + 1] + chars[index + 2]);
      }
      cjk.clear();
    }

    for (final rune in input.runes) {
      if (_isAsciiWordRune(rune)) {
        flushCjk();
        word.writeCharCode(rune);
        continue;
      }
      if (_isCjkRune(rune)) {
        flushWord();
        cjk.add(rune);
        continue;
      }
      flushWord();
      flushCjk();
    }
    flushWord();
    flushCjk();
    return output;
  }
}

List<_LocalSearchDocument> _localSearchDocuments(Database database) {
  final documents = <_LocalSearchDocument>[];
  for (final capture in CapturesDao(database).readAll(limit: 10000)) {
    if (_isDeletedStatus(capture.status)) {
      continue;
    }
    final body = _stringPayload(capture.payload, 'text') ?? '';
    if (body.trim().isEmpty) {
      continue;
    }
    documents.add(
      _document(
        sourceKind: 'capture',
        sourceId: capture.id,
        sourceType: capture.sourceType,
        title: _stringPayload(capture.payload, 'title') ?? 'Capture',
        body: body,
        status: capture.status,
        sensitivity: _stringPayload(capture.payload, 'sensitivity') ?? 'low',
        sourceRefs: _sourceRefsWithSelf('capture', capture.id, <Object?>[
          if (capture.sourceId != null)
            <String, Object?>{'kind': 'event', 'id': capture.sourceId},
        ]),
        metadata: <String, Object?>{
          'source_type': capture.sourceType,
          if (capture.sourceId != null) 'source_id': capture.sourceId,
        },
        createdAt: capture.createdAt,
        updatedAt: capture.updatedAt,
      ),
    );
  }
  for (final memory in MemoryItemsDao(database).readAll(limit: 10000)) {
    if (_isDeletedStatus(memory.status) || memory.tombstone) {
      continue;
    }
    documents.add(
      _document(
        sourceKind: 'memory',
        sourceId: memory.id,
        sourceType: memory.memoryType,
        title: memory.key,
        body: memory.body,
        status: memory.status,
        sensitivity: memory.sensitivity,
        sourceRefs: _sourceRefsWithSelf('memory', memory.id, memory.sourceRefs),
        metadata: <String, Object?>{
          'memory_key': memory.key,
          'memory_type': memory.memoryType,
          'confidence': memory.confidence,
          'revision': memory.revision,
        },
        createdAt: memory.createdAt,
        updatedAt: memory.updatedAt,
      ),
    );
  }
  for (final card in CardsDao(database).readAll(limit: 10000)) {
    if (_isDeletedStatus(card.status)) {
      continue;
    }
    documents.add(
      _document(
        sourceKind: 'card',
        sourceId: card.id,
        sourceType: card.cardKind,
        title: card.title,
        body: card.body,
        status: card.status,
        sensitivity: _stringPayload(card.payload, 'sensitivity') ?? 'low',
        sourceRefs: _sourceRefsWithSelf('card', card.id, card.sourceRefs),
        metadata: <String, Object?>{'card_kind': card.cardKind},
        createdAt: card.createdAt,
        updatedAt: card.updatedAt,
      ),
    );
  }
  for (final insight in InsightsDao(database).readAll(limit: 10000)) {
    if (_isDeletedStatus(insight.status)) {
      continue;
    }
    documents.add(
      _document(
        sourceKind: 'insight',
        sourceId: insight.id,
        sourceType: insight.insightKind,
        title: insight.title,
        body: insight.summary,
        status: insight.status,
        sensitivity: _stringPayload(insight.payload, 'sensitivity') ?? 'low',
        sourceRefs: _sourceRefsWithSelf(
          'insight',
          insight.id,
          insight.sourceRefs,
        ),
        metadata: <String, Object?>{
          'insight_kind': insight.insightKind,
          if (insight.metricLabel != null) 'metric_label': insight.metricLabel,
          if (insight.metricValue != null) 'metric_value': insight.metricValue,
        },
        createdAt: insight.createdAt,
        updatedAt: insight.updatedAt,
      ),
    );
  }
  for (final todo in TodosDao(database).readAll(limit: 10000)) {
    if (_isDeletedStatus(todo.status)) {
      continue;
    }
    final title = _stringPayload(todo.payload, 'title') ?? 'Todo';
    final bodyText = _stringPayload(todo.payload, 'body');
    final dueLabel = _stringPayload(todo.payload, 'due_label');
    final priority = _stringPayload(todo.payload, 'priority');
    final body = <String>[
      title,
      if (bodyText != null) bodyText,
      if (dueLabel != null) dueLabel,
      if (priority != null) priority,
    ].join('\n');
    documents.add(
      _document(
        sourceKind: 'todo',
        sourceId: todo.id,
        sourceType: _stringPayload(todo.payload, 'suggestion_kind') ?? 'todo',
        title: title,
        body: body,
        status: todo.status,
        sensitivity: _stringPayload(todo.payload, 'sensitivity') ?? 'low',
        sourceRefs: _sourceRefsWithSelf(
          'todo',
          todo.id,
          _jsonList(todo.payload['source_refs']),
        ),
        metadata: <String, Object?>{
          if (todo.sourceCaptureId != null)
            'source_capture_id': todo.sourceCaptureId,
          if (todo.sourceEventId != null) 'source_event_id': todo.sourceEventId,
          if (todo.payload['priority'] is String)
            'priority': todo.payload['priority'],
        },
        createdAt: todo.createdAt,
        updatedAt: todo.updatedAt,
      ),
    );
  }
  for (final artifact in DerivedArtifactsDao(database).readAll(limit: 10000)) {
    if (_isDeletedStatus(artifact.status) || artifact.invalidatedAt != null) {
      continue;
    }
    documents.add(
      _document(
        sourceKind: 'derived_artifact',
        sourceId: artifact.id,
        sourceType: artifact.artifactKind,
        title: artifact.title,
        body: artifact.body,
        status: artifact.status,
        sensitivity: artifact.sensitivity,
        sourceRefs: _sourceRefsWithSelf(
          'artifact',
          artifact.id,
          artifact.sourceRefs,
        ),
        metadata: <String, Object?>{
          'artifact_kind': artifact.artifactKind,
          'confidence': artifact.confidence,
          'generator_id': artifact.generatorId,
          if (artifact.sourceAttachmentId != null)
            'source_attachment_id': artifact.sourceAttachmentId,
        },
        createdAt: artifact.createdAt,
        updatedAt: artifact.updatedAt,
      ),
    );
  }
  return documents;
}

_LocalSearchDocument _document({
  required String sourceKind,
  required String sourceId,
  required String sourceType,
  required String title,
  required String body,
  required String status,
  required String sensitivity,
  required JsonList sourceRefs,
  required JsonMap metadata,
  required DateTime createdAt,
  required DateTime updatedAt,
}) {
  final docId = '$sourceKind/$sourceId';
  final normalizedTitle = _nonEmpty(title, fallback: _titleFromBody(body));
  final normalizedBody = body.trim();
  final contentHash = _contentHash(<String, Object?>{
    'source_kind': sourceKind,
    'source_id': sourceId,
    'title': normalizedTitle,
    'body': normalizedBody,
    'source_refs': sourceRefs,
  });
  return _LocalSearchDocument(
    record: SearchDocumentRecord(
      id: docId,
      sourceKind: sourceKind,
      sourceId: sourceId,
      sourceType: sourceType,
      title: normalizedTitle,
      status: status,
      sensitivity: sensitivity,
      sourceRefs: sourceRefs,
      metadata: metadata,
      contentHash: contentHash,
      createdAt: createdAt,
      updatedAt: updatedAt,
    ),
    body: normalizedBody,
  );
}

List<SearchChunkRecord> _chunksForDocument(
  _LocalSearchDocument document, {
  required int chunkSize,
  required int chunkOverlap,
}) {
  final body = document.body;
  if (body.length <= chunkSize) {
    return <SearchChunkRecord>[_chunk(document, body, 0)];
  }
  final chunks = <SearchChunkRecord>[];
  var start = 0;
  var index = 0;
  final step = math.max(1, chunkSize - chunkOverlap);
  while (start < body.length) {
    final end = math.min(body.length, start + chunkSize);
    chunks.add(_chunk(document, body.substring(start, end), index++));
    if (end == body.length) {
      break;
    }
    start += step;
  }
  return chunks;
}

SearchChunkRecord _chunk(
  _LocalSearchDocument document,
  String body,
  int index,
) {
  final record = document.record;
  final title = record.title;
  final textForTokens = '$title\n$body';
  final contentHash = _contentHash(<String, Object?>{
    'doc_id': record.id,
    'index': index,
    'title': title,
    'body': body,
    'document_hash': record.contentHash,
  });
  return SearchChunkRecord(
    id: '${record.id}#$index',
    docId: record.id,
    sourceKind: record.sourceKind,
    sourceId: record.sourceId,
    sourceType: record.sourceType,
    title: title,
    body: body,
    snippet: _snippet(body),
    tokenText: SearchTextTokenizer.tokenText(textForTokens),
    status: record.status,
    sensitivity: record.sensitivity,
    sourceRefs: record.sourceRefs,
    metadata: record.metadata,
    contentHash: contentHash,
    chunkIndex: index,
    createdAt: record.createdAt,
    updatedAt: record.updatedAt,
  );
}

List<LocalSearchResult> _fuseHits({
  required List<_RankedKeywordHit> keywordHits,
  required List<_RankedSemanticHit> semanticHits,
  required int fusionK,
  required int limit,
}) {
  final chunks = <String, SearchChunkRecord>{};
  final keywordById = <String, _RankedKeywordHit>{};
  final semanticById = <String, _RankedSemanticHit>{};
  for (final hit in keywordHits) {
    chunks[hit.chunk.id] = hit.chunk;
    keywordById[hit.chunk.id] = hit;
  }
  for (final hit in semanticHits) {
    chunks[hit.chunk.id] = hit.chunk;
    semanticById[hit.chunk.id] = hit;
  }
  final results = <LocalSearchResult>[];
  for (final entry in chunks.entries) {
    final keyword = keywordById[entry.key];
    final semantic = semanticById[entry.key];
    final matchedBy = <String>{
      if (keyword != null) 'keyword',
      if (semantic != null) 'semantic',
    };
    final score =
        (keyword == null ? 0.0 : 1 / (fusionK + keyword.rank)) +
        (semantic == null ? 0.0 : 1 / (fusionK + semantic.rank));
    results.add(
      LocalSearchResult(
        chunk: entry.value,
        score: score,
        matchedBy: matchedBy,
        keywordRank: keyword?.rank,
        keywordScore: keyword?.score,
        semanticRank: semantic?.rank,
        semanticScore: semantic?.score,
      ),
    );
  }
  results.sort((a, b) {
    final score = b.score.compareTo(a.score);
    if (score != 0) {
      return score;
    }
    return b.chunk.updatedAt.compareTo(a.chunk.updatedAt);
  });
  return List<LocalSearchResult>.unmodifiable(results.take(limit));
}

_SqlFilter _sqlFilter(
  LocalSearchRequest request, {
  required String tableAlias,
}) {
  final clauses = <String>['$tableAlias.status != ?'];
  final parameters = <Object?>['deleted'];
  if (!request.includeHighSensitivity) {
    clauses.add('$tableAlias.sensitivity != ?');
    parameters.add('high');
  }
  if (request.sourceKinds.isNotEmpty) {
    clauses.add(
      '$tableAlias.source_kind IN (${List.filled(request.sourceKinds.length, '?').join(', ')})',
    );
    parameters.addAll(request.sourceKinds);
  }
  if (request.statuses.isNotEmpty) {
    clauses.add(
      '$tableAlias.status IN (${List.filled(request.statuses.length, '?').join(', ')})',
    );
    parameters.addAll(request.statuses);
  }
  if (request.since != null) {
    clauses.add('$tableAlias.updated_at >= ?');
    parameters.add(_encodeDateTime(request.since!));
  }
  if (request.until != null) {
    clauses.add('$tableAlias.updated_at <= ?');
    parameters.add(_encodeDateTime(request.until!));
  }
  return _SqlFilter(
    sql: clauses.map((clause) => '  AND $clause').join('\n'),
    parameters: parameters,
  );
}

bool _matchesRequestFilters(
  SearchChunkRecord chunk,
  LocalSearchRequest request,
) {
  if (request.sourceRefs.isEmpty) {
    return true;
  }
  final sourceKeys = <String>{
    '${chunk.sourceKind}:${chunk.sourceId}',
    for (final ref in chunk.sourceRefs)
      if (ref is Map) '${ref['kind']}:${ref['id']}',
  };
  return request.sourceRefs.any((ref) {
    final kind = ref['kind'];
    final id = ref['id'];
    return kind is String && id is String && sourceKeys.contains('$kind:$id');
  });
}

String _ftsQuery(String query) {
  final tokens = SearchTextTokenizer.tokens(query).take(24).toList();
  if (tokens.isEmpty) {
    return '';
  }
  return tokens.map(_quoteFtsToken).join(' OR ');
}

String _quoteFtsToken(String token) {
  return '"${token.replaceAll('"', '""')}"';
}

int _positiveLimit(int value, {required int defaultValue}) {
  if (value <= 0) {
    return defaultValue;
  }
  return math.min(value, 500);
}

Uint8List _embeddingBlob(List<double> embedding) {
  final floats = Float32List.fromList(embedding);
  return floats.buffer.asUint8List();
}

List<double> _embeddingFromBlob(Uint8List bytes) {
  if (bytes.lengthInBytes % 4 != 0) {
    return const <double>[];
  }
  return Float32List.view(
    bytes.buffer,
    bytes.offsetInBytes,
    bytes.lengthInBytes ~/ 4,
  ).toList(growable: false);
}

double _cosineSimilarity(List<double> a, List<double> b) {
  if (a.isEmpty || b.isEmpty || a.length != b.length) {
    return double.nan;
  }
  var dot = 0.0;
  var aNorm = 0.0;
  var bNorm = 0.0;
  for (var index = 0; index < a.length; index += 1) {
    dot += a[index] * b[index];
    aNorm += a[index] * a[index];
    bNorm += b[index] * b[index];
  }
  if (aNorm == 0 || bNorm == 0) {
    return double.nan;
  }
  return dot / (math.sqrt(aNorm) * math.sqrt(bNorm));
}

bool _isAsciiWordRune(int rune) {
  return (rune >= 48 && rune <= 57) ||
      (rune >= 65 && rune <= 90) ||
      (rune >= 97 && rune <= 122) ||
      rune == 95;
}

bool _isCjkRune(int rune) {
  return (rune >= 0x3400 && rune <= 0x4DBF) ||
      (rune >= 0x4E00 && rune <= 0x9FFF) ||
      (rune >= 0xF900 && rune <= 0xFAFF);
}

JsonList _sourceRefsWithSelf(String kind, String id, JsonList refs) {
  final seen = <String>{};
  final result = <Object?>[];
  void addRef(String kind, String id) {
    if (kind.trim().isEmpty || id.trim().isEmpty) {
      return;
    }
    if (seen.add('$kind:$id')) {
      result.add(<String, Object?>{'kind': kind, 'id': id});
    }
  }

  addRef(kind, id);
  for (final ref in refs) {
    if (ref is! Map) {
      continue;
    }
    final refKind = ref['kind'];
    final refId = ref['id'];
    if (refKind is String && refId is String) {
      addRef(refKind, refId);
    }
  }
  return List<Object?>.unmodifiable(result);
}

JsonList _jsonList(Object? value) {
  return value is List ? List<Object?>.unmodifiable(value) : const <Object?>[];
}

String? _stringPayload(JsonMap payload, String key) {
  final value = payload[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

bool _isDeletedStatus(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized == 'deleted' || normalized == 'purged';
}

String _nonEmpty(String value, {required String fallback}) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

String _titleFromBody(String body) {
  final first = body.trim().split('\n').first.trim();
  return first.isEmpty ? 'Source' : _snippet(first, maxLength: 60);
}

String _snippet(String body, {int maxLength = 220}) {
  final normalized = body.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.length <= maxLength) {
    return normalized;
  }
  return '${normalized.substring(0, math.max(0, maxLength - 3)).trimRight()}...';
}

String _contentHash(Object value) {
  return sha256.convert(utf8.encode(jsonEncode(value))).toString();
}

final class _LocalSearchDocument {
  const _LocalSearchDocument({required this.record, required this.body});

  final SearchDocumentRecord record;
  final String body;
}

final class _SqlFilter {
  const _SqlFilter({required this.sql, required this.parameters});

  final String sql;
  final List<Object?> parameters;
}

final class _RankedKeywordHit {
  const _RankedKeywordHit({
    required this.chunk,
    required this.rank,
    required this.score,
  });

  final SearchChunkRecord chunk;
  final int rank;
  final double score;
}

final class _RankedSemanticHit {
  const _RankedSemanticHit({
    required this.chunk,
    required this.rank,
    required this.score,
  });

  final SearchChunkRecord chunk;
  final int rank;
  final double score;
}

final class _ScoredSemanticChunk {
  const _ScoredSemanticChunk({required this.chunk, required this.score});

  final SearchChunkRecord chunk;
  final double score;
}
