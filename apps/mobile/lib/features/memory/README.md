# Memory Feature

## Purpose

Owns the mobile Memory management page: local Memory browsing, edit,
tombstone delete, restore visibility, and source metadata.

## Ownership Boundary

This feature presents and updates accepted Memory items through
`packages/dart/local_db`. It does not define public Memory contracts, Memory
policy, extraction prompts, sync semantics, or Agent Pack behavior.

Memory delete is reversible in this slice: rows are tombstoned and their
revision is incremented instead of being physically removed.

The page does not use local substring matching for Memory text search. Text
queries show a retriever-required state until an embedding/model-backed recall
boundary exists.

## Dependencies

- Flutter Material
- `flutter_riverpod`
- `apps/mobile/lib/app/local_database.dart`
- `packages/dart/local_db`

## Public Surface

- `application/memoryControllerProvider`
- `presentation/MemoryPage`

## Generated Artifacts

None.

## Related Context

- `docs/rfcs/memory-model.md`
- `docs/rfcs/mobile-entry-closure.md`
