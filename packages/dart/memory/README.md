# Dart Memory

## Purpose

Pure Dart Memory lifecycle primitives for WideNote.

This package owns the product-semantic layer for proposed and accepted Memory before durable storage adapters are introduced.

## Ownership Boundary

Owns Memory items, proposals, default write policy, repository interface, in-memory test repository, and service orchestration.

It must not own Flutter UI, extraction prompts, local database migrations, vector indexes, sync protocols, or generated public schemas.

## Public Surface

- `MemoryItem`
- `MemoryProposal`
- `MemoryType`
- `MemoryPolicy`
- `DefaultMemoryPolicy`
- `MemoryRepository`
- `InMemoryMemoryRepository`
- `MemoryService`

## Dependencies

Pure Dart only. This package does not depend on Flutter UI, local DB, real model providers, or backend services.

## Generated Artifacts

None. Future generated Memory contracts should point back to `packages/schemas`.

## Tests

Run:

```sh
dart test
```

Current tests cover default auto-acceptance, review routing, conflict routing, and deletion tombstones.

## Related Context

- `docs/decisions/0005-use-memory-first-instead-of-pkm-core.md`
- `docs/architecture/engineering-rules.md`
- `docs/architecture/phase-one-technical-plan.md`
