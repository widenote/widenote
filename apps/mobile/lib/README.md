# Mobile Dart Source

## Purpose

Flutter source for the WideNote mobile client.

## Ownership Boundary

This tree owns app composition, feature UI, and temporary app-local state used by the mobile shell. Shared schemas, runtime logic, and local database code should move into `packages/` once those packages are available.

## Dependencies

- Flutter Material widgets
- `flutter_riverpod` for local state wiring
- `go_router` for tab routing

## Public Surface

- `main.dart`
- `app/WideNoteApp`
- feature pages under `features/*/presentation`

## Generated Artifacts

None.
