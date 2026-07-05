# Todos Feature

## Purpose

Owns the source-linked local task center: model-suggested action items,
schedule candidates, completed rows, and completion/reopen controls for
actionable rows.

## Ownership Boundary

This feature reads and updates the local `todos` table through
`packages/dart/local_db`. Durable task schemas and cross-pack task semantics
belong outside the app UI layer.

Schedule candidates come from the model-backed Todo agent, not from local
keyword, regex, NLP, embedding, or title-based fallback logic. They are displayed
separately from completable action items and do not write to system Calendar or
Reminder stores. The Todo agent stores suggestion metadata in
`TodoRecord.payload` (`suggestion_kind`, `suggestion_confidence`,
`suggestion_reason`, optional `scheduled_at_label`, and optional structured
metadata such as `due_at`, `scheduled_start`, `scheduled_end`, `priority`,
`completed_at`, and `subtasks`) so backup/restore and model context can preserve
the UI grouping without adding a system action table yet. The mobile UI may mark
action rows complete or reopen them, but it does not locally create semantic
todos, schedule candidates, priorities, due dates, or task hierarchies.

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
