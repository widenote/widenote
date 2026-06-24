# Dart Cards

## Purpose

Pure Dart Memory-first card and insight derivation for WideNote.

This package turns raw capture snapshots and accepted Memory snapshots into
source-linked, browseable cards and first-pass summary/count/trend insights.
Cards and insights are projections. They must never overwrite or replace the
original capture or Memory records.

## Ownership Boundary

Owns small card/insight domain models, source-link validation, and deterministic
derivation rules.

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
generation, and required source links.
