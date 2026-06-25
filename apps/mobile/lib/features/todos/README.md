# Todos Feature

## Purpose

Owns the source-linked todo tab and local todo completion/reopen controls.

## Ownership Boundary

This feature reads and updates the local `todos` table through
`packages/dart/local_db`. Durable task schemas and cross-pack task semantics
belong outside the app UI layer.

## Dependencies

- Flutter Material
- `flutter_riverpod`
- `apps/mobile/lib/app/local_database.dart`
- `packages/dart/local_db`

## Public Surface

- `presentation/TodosPage`
- `application/todoControllerProvider`

## Generated Artifacts

None.
