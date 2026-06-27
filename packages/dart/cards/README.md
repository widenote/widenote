# Dart Cards

## Purpose

Pure Dart Memory-first card and insight derivation for WideNote.

This package turns raw capture snapshots and accepted Memory snapshots into
source-linked, browseable cards and first-pass summary/count/trend insights.
Cards and insights are projections. They must never overwrite or replace the
original capture or Memory records.

## Ownership Boundary

Owns small card/insight domain models, source-link validation, and deterministic
derivation rules. Timeline browse filtering is limited to typed object filters;
text retrieval belongs to an embedding/model-backed retriever, not local
substring matching.

It must not own Flutter UI, local database migrations, backup/export formats,
model-provider calls, prompts, PKM/PARA structures, or generated public schemas.

## Public Surface

- `CaptureCardSource`
- `MemoryCardSource`
- `MemoryFirstCard`
- `MemoryFirstInsight`
- `MemoryFirstCardBundle`
- `MemoryFirstCardInput`
- `MemoryFirstCardService`
- `MemoryFirstBrowseIndex`
- `SourceLink`

## Dependencies

Pure Dart only. This package does not depend on Flutter UI, local DB, Memory
repository adapters, model providers, or backend services.

## Generated Artifacts

None. Future generated card or insight contracts should point back to
`packages/schemas`.

## Tests

Run:

```sh
dart test
```

Current tests cover empty input, capture and Memory card generation, insight
generation, required source links, source-ref detail grouping, and browse
filtering without local text matching.
