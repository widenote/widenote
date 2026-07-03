import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_cards/widenote_cards.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_model_providers/model_providers.dart';

import '../../../app/local_database.dart';
import '../../model_providers/application/model_provider_settings_controller.dart';
import 'embedding_settings_controller.dart';

final localSearchServiceProvider = Provider<LocalSearchService>((ref) {
  final httpClient = DartIoModelProviderHttpClient();
  ref.onDispose(httpClient.close);
  return LocalSearchService(
    database: ref.watch(localDatabaseProvider),
    httpClient: httpClient,
    embeddingProvider: ref
        .watch(embeddingSettingsControllerProvider)
        .valueOrNull
        ?.provider,
  );
});

final localDbQueryEmbeddingResolverProvider =
    Provider<LocalDbQueryEmbeddingResolver?>((ref) {
      return ref.watch(localSearchServiceProvider).resolveQueryEmbedding;
    });

final timelineHybridSearchProvider = FutureProvider.autoDispose
    .family<TimelineHybridSearchResultSet, TimelineHybridSearchRequest>((
      ref,
      request,
    ) async {
      var disposed = false;
      ref.onDispose(() => disposed = true);
      await Future<void>.delayed(_timelineSearchDebounce);
      if (disposed) {
        return TimelineHybridSearchResultSet.empty(request.query.trim());
      }
      return ref.watch(localSearchServiceProvider).searchTimeline(request);
    });

const _timelineSearchDebounce = Duration(milliseconds: 300);

final class LocalSearchService {
  LocalSearchService({
    required this.database,
    required this.httpClient,
    required this.embeddingProvider,
    DateTime Function()? clock,
  }) : clock = clock ?? _utcNow;

  final WideNoteLocalDatabase database;
  final ModelProviderHttpClient httpClient;
  final EmbeddingProviderConfig? embeddingProvider;
  final DateTime Function() clock;

  Future<TimelineHybridSearchResultSet> searchTimeline(
    TimelineHybridSearchRequest request,
  ) async {
    final query = request.query.trim();
    if (query.isEmpty) {
      return TimelineHybridSearchResultSet.empty(query);
    }
    database.searchIndex.rebuildFromLocalTruth();
    final resolved = await resolveQueryEmbedding(query, database);
    final search = database.searchIndex.search(
      LocalSearchRequest(
        query: query,
        mode: resolved == null
            ? LocalSearchMode.keyword
            : LocalSearchMode.hybrid,
        limit: 30,
        sourceKinds: {
          if (request.kind != null) _sourceKindForTimelineKind(request.kind!),
        },
        includeHighSensitivity: true,
        queryEmbedding: resolved?.embedding,
        embeddingProviderId: resolved?.providerId,
        embeddingModel: resolved?.model,
      ),
    );
    return TimelineHybridSearchResultSet(
      query: query,
      mode: search.mode,
      embeddingUsed: search.embeddingUsed,
      results: [
        for (final result in search.results)
          TimelineHybridSearchResult.fromLocalSearchResult(result),
      ],
    );
  }

  Future<LocalDbResolvedQueryEmbedding?> resolveQueryEmbedding(
    String query,
    WideNoteLocalDatabase database,
  ) async {
    final provider = embeddingProvider;
    if (provider == null ||
        provider.apiKey.trim().isEmpty ||
        query.trim().isEmpty) {
      return null;
    }
    await _ensureChunkEmbeddings(provider, limit: 160);
    final adapter = embeddingProviderFromConfig(
      config: provider,
      httpClient: httpClient,
    );
    final response = await adapter.embed(EmbeddingRequest(input: [query]));
    if (response.embeddings.isEmpty) {
      return null;
    }
    return LocalDbResolvedQueryEmbedding(
      providerId: provider.id,
      model: provider.model,
      embedding: response.embeddings.first,
    );
  }

  Future<LocalSearchEmbeddingRebuildResult> rebuildEmbeddings({
    int limit = 500,
  }) async {
    database.searchIndex.rebuildFromLocalTruth();
    final provider = embeddingProvider;
    if (provider == null || provider.apiKey.trim().isEmpty) {
      return const LocalSearchEmbeddingRebuildResult(
        indexedChunks: 0,
        providerConfigured: false,
      );
    }
    final indexed = await _ensureChunkEmbeddings(provider, limit: limit);
    return LocalSearchEmbeddingRebuildResult(
      indexedChunks: indexed,
      providerConfigured: true,
    );
  }

  Future<int> _ensureChunkEmbeddings(
    EmbeddingProviderConfig provider, {
    required int limit,
  }) async {
    final chunks = database.searchIndex.readChunksMissingEmbedding(
      providerId: provider.id,
      model: provider.model,
      limit: limit,
    );
    if (chunks.isEmpty) {
      return 0;
    }
    final adapter = embeddingProviderFromConfig(
      config: provider,
      httpClient: httpClient,
    );
    var indexed = 0;
    final batchSize = provider.batchSize <= 0 ? 16 : provider.batchSize;
    for (var start = 0; start < chunks.length; start += batchSize) {
      final end = start + batchSize > chunks.length
          ? chunks.length
          : start + batchSize;
      final batch = chunks.sublist(start, end);
      final response = await adapter.embed(
        EmbeddingRequest(
          input: [for (final chunk in batch) '${chunk.title}\n${chunk.body}'],
        ),
      );
      for (
        var index = 0;
        index < batch.length && index < response.embeddings.length;
        index += 1
      ) {
        database.searchIndex.saveChunkEmbedding(
          chunkId: batch[index].id,
          providerId: provider.id,
          model: provider.model,
          embedding: response.embeddings[index],
          updatedAt: clock(),
        );
        indexed += 1;
      }
    }
    return indexed;
  }
}

final class TimelineHybridSearchRequest {
  const TimelineHybridSearchRequest({required this.query, this.kind});

  final String query;
  final MemoryFirstTimelineItemKind? kind;

  @override
  bool operator ==(Object other) {
    return other is TimelineHybridSearchRequest &&
        other.query == query &&
        other.kind == kind;
  }

  @override
  int get hashCode => Object.hash(query, kind);
}

final class TimelineHybridSearchResultSet {
  const TimelineHybridSearchResultSet({
    required this.query,
    required this.mode,
    required this.embeddingUsed,
    required this.results,
  });

  factory TimelineHybridSearchResultSet.empty(String query) {
    return TimelineHybridSearchResultSet(
      query: query,
      mode: LocalSearchMode.keyword,
      embeddingUsed: false,
      results: const <TimelineHybridSearchResult>[],
    );
  }

  final String query;
  final LocalSearchMode mode;
  final bool embeddingUsed;
  final List<TimelineHybridSearchResult> results;
}

final class TimelineHybridSearchResult {
  const TimelineHybridSearchResult({
    required this.docId,
    required this.chunkId,
    required this.sourceKind,
    required this.sourceId,
    required this.sourceType,
    required this.title,
    required this.snippet,
    required this.sensitivity,
    required this.score,
    required this.matchedBy,
    required this.sourceRefs,
  });

  factory TimelineHybridSearchResult.fromLocalSearchResult(
    LocalSearchResult result,
  ) {
    final chunk = result.chunk;
    return TimelineHybridSearchResult(
      docId: chunk.docId,
      chunkId: chunk.id,
      sourceKind: chunk.sourceKind,
      sourceId: chunk.sourceId,
      sourceType: chunk.sourceType,
      title: chunk.title,
      snippet: chunk.sensitivity == 'high' ? null : chunk.snippet,
      sensitivity: chunk.sensitivity,
      score: result.score,
      matchedBy: result.matchedBy,
      sourceRefs: chunk.sourceRefs,
    );
  }

  final String docId;
  final String chunkId;
  final String sourceKind;
  final String sourceId;
  final String sourceType;
  final String title;
  final String? snippet;
  final String sensitivity;
  final double score;
  final Set<String> matchedBy;
  final JsonList sourceRefs;
}

final class LocalSearchEmbeddingRebuildResult {
  const LocalSearchEmbeddingRebuildResult({
    required this.indexedChunks,
    required this.providerConfigured,
  });

  final int indexedChunks;
  final bool providerConfigured;
}

String _sourceKindForTimelineKind(MemoryFirstTimelineItemKind kind) {
  return switch (kind) {
    MemoryFirstTimelineItemKind.capture => 'capture',
    MemoryFirstTimelineItemKind.card => 'card',
    MemoryFirstTimelineItemKind.insight => 'insight',
    MemoryFirstTimelineItemKind.memory => 'memory',
    MemoryFirstTimelineItemKind.todo => 'todo',
  };
}

DateTime _utcNow() => DateTime.now().toUtc();
