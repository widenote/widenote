# Mobile Dart Source

## Purpose

Flutter source for the WideNote mobile client.

## Ownership Boundary

This tree owns app composition, feature UI, local runtime wiring, and app-local
read state used by the mobile shell. Shared schemas, runtime logic, and local
database code live under `packages/`.

## Dependencies

- Flutter Material widgets
- `flutter_riverpod` for local state wiring
- `go_router` for tab routing
- `path_provider` for production database location
- `sqlite3_flutter_libs` for packaged SQLite on Flutter targets
- `packages/dart/local_db` for local runtime event and trace persistence

## Public Surface

- `main.dart`
- `app/WideNoteMobileBootstrap`
- `app/localDatabaseProvider`
- `app/WideNoteApp`
- feature pages under `features/*/presentation`

## Generated Artifacts

None.
