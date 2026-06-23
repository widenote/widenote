# Mobile App

## Purpose

Flutter mobile client and local runtime host.

Responsibilities:

- Quick capture
- Timeline and cards
- Local event store
- Local memory
- Local search
- Local Agent Runtime Kernel
- Permissions and trace review
- BYOK model provider configuration

## Ownership Boundary

The mobile app owns the immediate user experience, local persistence host, local runtime host, and platform integrations. Shared pure Dart logic should live under `packages/dart`.

The mobile app must not become the only source of truth for public Event, Memory, Agent Pack, Permission, Task, or Sync schemas.

## Public Surface

Initial public surfaces are the Flutter app entrypoint, platform integration boundaries, and local runtime wiring.

Current source layout:

- `lib/main.dart`: app process entrypoint, production bootstrap, and Riverpod scope.
- `lib/app`: app shell, theme, routing, and local database provider wiring.
- `lib/features`: feature-owned UI and app-local controllers.

The current client boots a device-local SQLite database at
`local-data/widenote.sqlite` and injects `LocalDbEventStore` /
`LocalDbTraceSink` into the local runtime by default. It also injects
`LocalDbMemoryRepository` so Memory candidates and reviewed Memory items are
written to SQLite. Capture UI read models are still held in feature state after
processing; restart hydration remains a phase-one follow-up work item.

## Dependencies

Allowed dependencies:

- `packages/dart/core`
- `packages/dart/local_db`
- `packages/dart/agent_runtime`
- `packages/dart/ui_blocks`
- `packages/schemas`

Flutter plugin dependencies used by the app bootstrap:

- `path_provider`
- `sqlite3_flutter_libs`

## Generated Artifacts

Generated Flutter, Drift, localization, or platform files must document their source of truth and generator command here when introduced.

## Related Context

- `docs/architecture/technology-stack.md`
- `docs/decisions/0002-use-flutter-and-drift-for-client.md`
