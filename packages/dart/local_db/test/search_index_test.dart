import 'package:test/test.dart';
import 'package:widenote_local_db/widenote_local_db.dart';

void main() {
  group('SearchIndexDao', () {
    late WideNoteLocalDatabase database;

    setUp(() {
      database = WideNoteLocalDatabase.inMemory();
    });

    tearDown(() {
      database.close();
    });

    test('rebuilds FTS with Chinese segmentation tokens', () {
      final now = DateTime.utc(2026, 7, 3, 9);
      database.captures.insert(
        CaptureRecord(
          id: 'capture-alpha',
          sourceType: 'manual',
          payload: const <String, Object?>{'text': '阿尔法项目发布计划已经确认，周五整理证据。'},
          createdAt: now,
          updatedAt: now,
        ),
      );

      final summary = database.searchIndex.rebuildFromLocalTruth();
      final result = database.searchIndex.search(
        const LocalSearchRequest(query: '阿尔法发布', mode: LocalSearchMode.keyword),
      );

      expect(summary.documentCount, 1);
      expect(summary.chunkCount, 1);
      expect(result.results, hasLength(1));
      expect(result.results.single.chunk.sourceKind, 'capture');
      expect(result.results.single.matchedBy, contains('keyword'));
    });

    test('applies status and updated-at metadata filters', () {
      final now = DateTime.utc(2026, 7, 3, 9, 15);
      database.captures
        ..insert(
          CaptureRecord(
            id: 'capture-old',
            sourceType: 'manual',
            status: 'processed',
            payload: const <String, Object?>{'text': 'Alpha launch evidence.'},
            createdAt: now,
            updatedAt: now,
          ),
        )
        ..insert(
          CaptureRecord(
            id: 'capture-new',
            sourceType: 'manual',
            status: 'archived',
            payload: const <String, Object?>{'text': 'Alpha launch followup.'},
            createdAt: now.add(const Duration(minutes: 10)),
            updatedAt: now.add(const Duration(minutes: 10)),
          ),
        );
      database.searchIndex.rebuildFromLocalTruth();

      final processed = database.searchIndex.search(
        const LocalSearchRequest(
          query: 'Alpha launch',
          mode: LocalSearchMode.keyword,
          statuses: <String>{'processed'},
        ),
      );
      final recent = database.searchIndex.search(
        LocalSearchRequest(
          query: 'Alpha launch',
          mode: LocalSearchMode.keyword,
          since: now.add(const Duration(minutes: 5)),
        ),
      );

      expect(processed.results.map((result) => result.chunk.sourceId), <String>[
        'capture-old',
      ]);
      expect(recent.results.map((result) => result.chunk.sourceId), <String>[
        'capture-new',
      ]);
    });

    test('preserves unchanged chunk embeddings across projection rebuilds', () {
      final now = DateTime.utc(2026, 7, 3, 9, 30);
      database.captures.insert(
        CaptureRecord(
          id: 'capture-alpha',
          sourceType: 'manual',
          payload: const <String, Object?>{
            'text': 'Alpha launch notes should keep their vector.',
          },
          createdAt: now,
          updatedAt: now,
        ),
      );
      database.searchIndex.rebuildFromLocalTruth();
      final chunk = database.searchIndex
          .readChunksMissingEmbedding(
            providerId: 'embedding.openrouter',
            model: 'qwen/qwen3-embedding-0.6b',
          )
          .single;
      database.searchIndex.saveChunkEmbedding(
        chunkId: chunk.id,
        providerId: 'embedding.openrouter',
        model: 'qwen/qwen3-embedding-0.6b',
        embedding: const <double>[1, 0],
        updatedAt: now,
      );

      database.searchIndex.rebuildFromLocalTruth();

      expect(
        database.searchIndex.readChunksMissingEmbedding(
          providerId: 'embedding.openrouter',
          model: 'qwen/qwen3-embedding-0.6b',
        ),
        isEmpty,
      );
      expect(
        database.searchIndex
            .search(
              const LocalSearchRequest(
                query: 'vector',
                mode: LocalSearchMode.semantic,
                queryEmbedding: <double>[1, 0],
                embeddingProviderId: 'embedding.openrouter',
                embeddingModel: 'qwen/qwen3-embedding-0.6b',
              ),
            )
            .embeddingUsed,
        isTrue,
      );

      database.captures.save(
        CaptureRecord(
          id: 'capture-alpha',
          sourceType: 'manual',
          payload: const <String, Object?>{
            'text': 'Alpha launch notes should keep their vector.',
            'sensitivity': 'high',
          },
          createdAt: now,
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );
      database.searchIndex.rebuildFromLocalTruth();

      expect(database.searchIndex.readChunk(chunk.id)!.sensitivity, 'high');
      expect(
        database.searchIndex.readChunksMissingEmbedding(
          providerId: 'embedding.openrouter',
          model: 'qwen/qwen3-embedding-0.6b',
        ),
        isEmpty,
      );

      database.captures.save(
        CaptureRecord(
          id: 'capture-alpha',
          sourceType: 'manual',
          payload: const <String, Object?>{
            'text': 'Alpha launch notes changed and need a new vector.',
            'sensitivity': 'high',
          },
          createdAt: now,
          updatedAt: now.add(const Duration(minutes: 2)),
        ),
      );
      database.searchIndex.rebuildFromLocalTruth();

      expect(
        database.searchIndex
            .readChunksMissingEmbedding(
              providerId: 'embedding.openrouter',
              model: 'qwen/qwen3-embedding-0.6b',
            )
            .single
            .id,
        chunk.id,
      );
    });

    test('fuses keyword and stored dense embedding candidates', () {
      final now = DateTime.utc(2026, 7, 3, 10);
      database.captures.insert(
        CaptureRecord(
          id: 'capture-alpha',
          sourceType: 'manual',
          payload: const <String, Object?>{
            'text': 'Alpha launch notes mention schedule but not finance.',
          },
          createdAt: now,
          updatedAt: now,
        ),
      );
      database.cards.insert(
        CardRecord(
          id: 'card-finance',
          cardKind: 'project_card',
          title: 'Forecast review',
          body: 'Revenue forecast and budget evidence for the launch.',
          sourceRefs: const <Object?>[
            <String, Object?>{'kind': 'capture', 'id': 'capture-alpha'},
          ],
          createdAt: now,
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );
      database.searchIndex.rebuildFromLocalTruth();
      for (final chunk in database.searchIndex.readChunksMissingEmbedding(
        providerId: 'embedding.openrouter',
        model: 'qwen/qwen3-embedding-0.6b',
      )) {
        database.searchIndex.saveChunkEmbedding(
          chunkId: chunk.id,
          providerId: 'embedding.openrouter',
          model: 'qwen/qwen3-embedding-0.6b',
          embedding: chunk.sourceKind == 'card'
              ? const <double>[0, 1]
              : const <double>[1, 0],
          updatedAt: now,
        );
      }

      final result = database.searchIndex.search(
        const LocalSearchRequest(
          query: 'launch forecast',
          mode: LocalSearchMode.hybrid,
          queryEmbedding: <double>[0, 1],
          embeddingProviderId: 'embedding.openrouter',
          embeddingModel: 'qwen/qwen3-embedding-0.6b',
        ),
      );

      expect(result.embeddingUsed, isTrue);
      expect(result.results.first.chunk.sourceKind, 'card');
      expect(
        result.results.first.matchedBy,
        containsAll(<String>['keyword', 'semantic']),
      );
      expect(result.semanticCandidateCount, greaterThan(0));
    });
  });
}
