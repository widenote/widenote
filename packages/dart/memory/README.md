# Dart Memory

## Purpose

Pure Dart Memory lifecycle primitives for WideNote.

This package owns the product-semantic layer for proposed, reviewed, and
accepted Memory. Durable storage adapters implement the repository interface
outside this package.

## Ownership Boundary

Owns Memory items, proposals, default write policy, repository interface, in-memory test repository, and service orchestration.

It must not own Flutter UI, extraction prompts, local database migrations, vector indexes, sync protocols, or generated public schemas.

The current contract is in `docs/architecture/current-contracts.md`: durable,
low-risk, source-linked, non-conflicting Memory is auto-accepted by default;
low-confidence, conflicting, highly sensitive, credential-like, or
policy-unclear Memory goes to review. This package owns that default policy and
the service behavior that makes auto-accept safe through provenance, revision,
review, and deletion semantics.

## Public Surface

- `MemoryItem`
- `MemoryProposal`
- `MemoryType`
- `MemoryPolicy`
- `DefaultMemoryPolicy`
- `MemoryRepository`
- `InMemoryMemoryRepository`
- `MemoryService`
- `MemoryReviewAction`
- `MemoryReviewResult`

## Dependencies

Pure Dart only. This package does not depend on Flutter UI, local DB, real model providers, or backend services.

## Generated Artifacts

None. Future generated Memory contracts should point back to `packages/schemas`.

## Tests

Run:

```sh
dart test
```

Current tests cover default auto-acceptance, review routing, accept/edit/reject
review actions, conflict routing, merge review actions, and deletion tombstones.

## Related Context

- `docs/architecture/current-contracts.md`
- `docs/decisions/0005-use-memory-first-instead-of-pkm-core.md`
- `docs/rfcs/memory-model.md`
- `docs/architecture/engineering-rules.md`
- `docs/architecture/phase-one-technical-plan.md`
