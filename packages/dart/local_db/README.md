# Dart Local DB

## Purpose

Pure Dart SQLite local truth package for local-first WideNote storage.

This package owns local tables, migration bootstrap, and DAO APIs for the
minimum phase-one record surfaces: events, captures, Memory, cards, insights,
todos, attachment metadata, and traces.

## Ownership Boundary

Owns local persistence and migrations. It must not own public protocol
semantics, Memory policy, runtime orchestration, sync protocol behavior, or UI
rendering.

## Public Surface

- `WideNoteLocalDatabase`
- `WideNoteLocalDatabase.openPath`
- `openInMemoryWideNoteLocalDatabase`
- `LocalDbMigrator`
- `LocalBackupService`
- `LocalBackupCodec`
- `LocalBackupManifest`
- `LocalDataBackup`
- `EventLogDao`
- `CapturesDao`
- `AttachmentsDao`
- `MemoryItemsDao`
- `MemoryCandidatesDao`
- `CardsDao`
- `InsightsDao`
- `TodosDao`
- `TraceEventsDao`
- `LocalDbEventStore`
- `LocalDbTraceSink`
- `LocalDbMemoryRepository`
- `JsonMap`
- record models for each DAO

The DAO public surface is exported through `lib/src/daos.dart`. Individual DAO
implementations are split into `lib/src/daos_*.dart` part files to keep each
persistence responsibility small while preserving the existing import boundary.

## Dependencies

Depends on the pure Dart `sqlite3` package, runtime port interfaces from
`packages/dart/agent_runtime`, and the Memory repository interface from
`packages/dart/memory`. Must not depend on Flutter UI.

The dependency direction is intentional:

```text
agent_runtime -> core
memory -> pure Dart Memory semantics
local_db -> agent_runtime + memory + sqlite3
apps/mobile -> agent_runtime + local_db + memory
```

`agent_runtime` must not import SQLite, Drift, or local DB record types.
`memory` owns review policy and lifecycle semantics; `local_db` only maps those
interfaces to SQLite rows.

The accepted long-term client decision still points to SQLite + Drift. This
MVP intentionally uses hand-written SQLite with no code generation so the local
truth tables can be tested before mobile integration.

`WideNoteLocalDatabase.rawDatabase` is intentionally retained as a narrow escape
hatch for migrations, low-level inspection, and tests. Product code should
prefer DAO APIs so table fields stay aligned with public schemas.

## Backup / Export / Import

`LocalBackupService` provides the first local-only backup round-trip for the
current SQLite truth tables. The JSON document uses a WideNote-owned
`widenote.local_data_backup` format with:

- `manifest`: format version, local DB schema version, creation timestamp, and
  per-section record counts.
- `event_log`, `captures`, `attachments`, `memory_items`, `memory_candidates`, `cards`,
  `insights`, `chat_sessions`, `chat_messages`, `model_provider_configs`,
  `todos`, and `trace_events`: JSON rows reconstructed through the package
  record models.

Format v2 adds `attachments`; v1 backups without that section are imported as
empty attachment sets so older local backups remain restorable.

This V1 format covers the tables currently owned by this package. It exports
provider API keys as part of user-managed backup/restore portability. Backup
callers must treat exported JSON as secret-bearing user data and keep keys out
of logs, generated docs, test output, and automated review prompts.

## Generated Artifacts

None. If Drift-generated files are introduced later, document their source
`.drift` or Dart table definitions and generation command.

## Tests

Run:

```sh
dart test
```

Current tests cover capture insert/read, event append/read, Memory item and
candidate storage, source-linked card and insight storage, chat sessions and
messages, provider metadata, attachment metadata, Memory review
accept/edit/reject transitions, the SQLite-backed Memory repository adapter,
todo status updates, trace reads, in-memory schema bootstrap, file-path reopen
persistence, v1-to-current migrations, pagination, backup import/export, and
runtime EventStore/TraceSink adapters.

## Related Context

- `docs/decisions/0002-use-flutter-and-drift-for-client.md`
- `docs/decisions/0003-build-agent-runtime-kernel.md`
- `docs/decisions/0005-use-memory-first-instead-of-pkm-core.md`
- `docs/rfcs/memory-model.md`
