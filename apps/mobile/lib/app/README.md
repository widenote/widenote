# App Shell

## Purpose

Owns the Flutter application root, Material theme, top-level tab routing, and
production local database bootstrap providers.

## Ownership Boundary

This module composes feature pages and app-level providers. It does not own
feature state, public schemas, local database table semantics, or runtime
orchestration behavior.

## Dependencies

- Flutter Material
- `flutter_riverpod`
- `go_router`
- `path_provider`
- `packages/dart/local_db`
- `packages/dart/memory`

## Public Surface

- `WideNoteApp`
- `appRouter`
- `WideNoteShell`
- `WideNoteMobileBootstrap`
- `localDatabaseProvider`
- `localEventStoreProvider`
- `localTraceSinkProvider`
- `localMemoryRepositoryProvider`

## Generated Artifacts

None.
