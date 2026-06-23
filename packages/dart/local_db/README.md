# Dart Local DB

## Purpose

Pure Dart SQLite local truth package for local-first WideNote storage.

This package owns local tables, migration bootstrap, and DAO APIs for the
minimum phase-one record surfaces: events, captures, Memory, todos, and traces.

## Ownership Boundary

Owns local persistence and migrations. It must not own public protocol
semantics, Memory policy, runtime orchestration, sync protocol behavior, or UI
rendering.

## Public Surface

- `WideNoteLocalDatabase`
- `WideNoteLocalDatabase.openPath`
- `openInMemoryWideNoteLocalDatabase`
- `LocalDbMigrator`
- `EventLogDao`
- `CapturesDao`
- `MemoryItemsDao`
- `MemoryCandidatesDao`
- `TodosDao`
- `TraceEventsDao`
- `LocalDbEventStore`
- `LocalDbTraceSink`
- `JsonMap`
- record models for each DAO

## Dependencies

Depends on the pure Dart `sqlite3` package and the runtime port interfaces from
`packages/dart/agent_runtime`. Must not depend on Flutter UI.

The dependency direction is intentional:

```text
agent_runtime -> core
local_db -> agent_runtime + sqlite3
apps/mobile -> agent_runtime + local_db + memory
```

`agent_runtime` must not import SQLite, Drift, or local DB record types.

The accepted long-term client decision still points to SQLite + Drift. This
MVP intentionally uses hand-written SQLite with no code generation so the local
truth tables can be tested before mobile integration.

`WideNoteLocalDatabase.rawDatabase` is intentionally retained as a narrow escape
hatch for migrations, low-level inspection, and tests. Product code should
prefer DAO APIs so table fields stay aligned with public schemas.

## Generated Artifacts

None. If Drift-generated files are introduced later, document their source
`.drift` or Dart table definitions and generation command.

## Tests

Run:

```sh
dart test
```

Current tests cover capture insert/read, event append/read, Memory item and
candidate storage, todo status updates, trace reads, in-memory schema bootstrap,
file-path reopen persistence, v1-to-current migrations, pagination, and runtime
EventStore/TraceSink adapters.

## Related Context

- `docs/decisions/0002-use-flutter-and-drift-for-client.md`
- `docs/decisions/0003-build-agent-runtime-kernel.md`
- `docs/decisions/0005-use-memory-first-instead-of-pkm-core.md`
- `docs/rfcs/memory-model.md`
