# Todos Feature

## Purpose

Owns the source-linked local action center: action items, schedule candidates,
and completion/reopen controls for actionable rows.

## Ownership Boundary

This feature reads and updates the local `todos` table through
`packages/dart/local_db`. Durable task schemas and cross-pack task semantics
belong outside the app UI layer.

Phase-one schedule candidates are local suggestions only. They are displayed
separately from completable action items and do not write to system Calendar or
Reminder stores. The model-backed Todo agent stores suggestion metadata in
`TodoRecord.payload` (`suggestion_kind`, `suggestion_confidence`,
`suggestion_reason`, and optional `scheduled_at_label`) so backup/restore can
preserve the UI grouping without adding a system action table yet.

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
