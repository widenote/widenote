# Todos Feature

## Purpose

Owns the source-linked local task center: action items, schedule candidates,
completed rows, local task metadata, and completion/reopen controls for
actionable rows.

## Ownership Boundary

This feature reads and updates the local `todos` table through
`packages/dart/local_db`. Durable task schemas and cross-pack task semantics
belong outside the app UI layer.

Phase-one schedule candidates are local suggestions only. They are displayed
separately from completable action items and do not write to system Calendar or
Reminder stores. The model-backed Todo agent stores suggestion metadata in
`TodoRecord.payload` (`suggestion_kind`, `suggestion_confidence`,
`suggestion_reason`, optional `scheduled_at_label`, and optional task-manager
metadata such as `due_at`, `priority`, `sort_order`, `indent_level`,
`completed_at`, and `subtasks`) so backup/restore and model context can preserve
the UI grouping without adding a system action table yet.

Todos uses `TodoRecord.payload.todo_schema_version = 1` for first-slice
task-manager metadata. Stable fields can move into table columns later if the
list grows beyond Dart-side sorting and bucketing.

## Dependencies

- Flutter Material
- `flutter_riverpod`
- `apps/mobile/lib/app/local_database.dart`
- `packages/dart/local_db`

## Public Surface

- `presentation/TodosPage`
- `presentation/TodoDetailPage`
- `application/todoControllerProvider`

## Generated Artifacts

None.
