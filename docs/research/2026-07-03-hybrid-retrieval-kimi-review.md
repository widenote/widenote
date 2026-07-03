# Hybrid Retrieval Implementation And Review

Status: implementation note

Date: 2026-07-03

## Context

WideNote's timeline search and chat read tools needed to move from browse-only
or context-packet-only behavior to a real hybrid retrieval baseline. The product
direction is local-first object truth with rebuildable search projections,
online embeddings behind an explicit provider, and progressive evidence
disclosure for Agent use.

The Memex reference branch informed the desired orchestration shape: search
should assemble evidence candidates, not hand an agent a monolithic full
context. The implementation remains WideNote-authored and uses WideNote local
tables, contracts, permissions, and tests.

## Accepted Baseline

- First-stage retrieval uses local BM25/FTS candidates plus dense embedding
  candidates plus metadata filters.
- Results are fused with reciprocal rank fusion.
- The first slice does not add a cross-encoder reranker; candidate-depth and
  reranker controls remain a follow-up once the baseline is observable.
- Agent tools return evidence handles containing source id, chunk id, title,
  path, snippet, score, source type, source refs, and an open command.
- Agent access is progressive: search or list sources first, then open relevant
  source chunks only when needed.
- Embedding configuration is separate from chat/completion model provider
  configuration.
- The default embedding preset is OpenRouter with Qwen
  `qwen/qwen3-embedding-0.6b`.
- Embeddings are online by design. With no valid embedding provider key,
  timeline search and Agent search fall back to keyword/FTS only.
- Chinese tokenization is currently app-level CJK unigram/bigram/trigram plus
  ASCII tokenization. A dedicated tokenizer library can replace this boundary
  after quality and package-footprint review.

## Implementation Notes

- `packages/dart/local_db` owns derived `search_documents`, `search_chunks`,
  `search_chunks_fts`, and `search_chunk_embeddings` projections.
- `SearchIndexDao` rebuilds projections from captures, Memory, cards, insights,
  todos, and derived artifacts, then runs keyword, semantic, or hybrid search.
- `EmbeddingProviderConfigsDao` stores embedding provider config separately from
  model provider config.
- `packages/dart/model_providers` exposes the embedding provider contract and an
  OpenAI-compatible `/embeddings` adapter.
- `apps/mobile/lib/features/retrieval` wires the retrieval service, embedding
  settings UI, manual index rebuild, and timeline search integration.
- `semantic_search.query` now returns evidence handles and can operate in
  `hybrid`, `keyword`, or `semantic` mode. `source.open` and `sources.list`
  expose follow-up exploration tools.

## Review Log

- Kimi round 1 identified a blocking rebuild bug: rebuilding the search
  projection deleted `search_chunks`, which cascaded into stored embeddings and
  forced repeated online embedding. The implementation was changed to short
  circuit unchanged projections, upsert documents/chunks, rebuild FTS only, and
  keep embedding rows unless their chunk is stale.
- Kimi follow-up review identified a privacy-sensitive projection issue:
  sensitivity/status changes could be skipped if body text was unchanged. The
  projection sync check now compares full document and chunk projection rows
  while keeping embedding content hashes tied to text content.
- Kimi follow-up review also found that `semantic_search.query` accepted
  status/date/delete-style filters that were not all implemented. Status and
  updated-at filters are now implemented; unsupported delete/tombstone/privacy
  switches were removed from the search tool input whitelist.
- Timeline search now debounces query execution before invoking online query
  embeddings, reducing request storms while typing.
- Remaining follow-ups: add a reranker once baseline observability exists,
  consider a dedicated tokenizer library, and move larger embedding backfills to
  background scheduling instead of query-time indexing.
