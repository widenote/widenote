# Timeline Feature

## Purpose

Owns the mobile Timeline browse, type-filter, and detail surfaces for local
captures, cards, insights, accepted Memory, and todos.

## Ownership Boundary

This feature builds a read-only timeline snapshot from local object truth in
`packages/dart/local_db` and browse models from `packages/dart/cards`. It
presents provenance and source references, but it does not define canonical
storage, Memory policy, Agent Pack runtime behavior, search indexing, or sync
semantics.

Timeline text search is not implemented with local substring rules. The current
surface supports local type filtering and shows a retriever-required state for
text queries. Full embedding/vector or model-backed retrieval remains a later
persistence/search concern.

## Dependencies

- Flutter Material
- `flutter_riverpod`
- `go_router`
- `packages/dart/local_db`
- `packages/dart/cards`
- `packages/dart/agent_runtime` event type constants

## Public Surface

- `application/TimelineRepository`
- `application/timelineSnapshotProvider`
- `application/timelineCardDetailProvider`
- `application/timelineItemDetailProvider`
- `presentation/TimelinePage`
- `presentation/TimelineSearchPage`
- `presentation/CardDetailPage`
- `presentation/TimelineItemDetailPage`
- shared widgets in `presentation/timeline_widgets.dart`

## Generated Artifacts

None.

## Related Context

- `docs/rfcs/mobile-entry-closure.md`
- `docs/research/2026-06-26-w7-current-integration-state.md`
