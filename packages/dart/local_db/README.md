# Dart Local DB

## Purpose

Pure Dart SQLite local truth package for local-first WideNote storage.

This package owns local tables, migration bootstrap, and DAO APIs for the
minimum phase-one record surfaces: events, captures, Memory, cards, insights,
todos, attachment metadata, durable runtime state, Agent Pack install state,
permission grants/revocations, runtime approval queue metadata, context packet
caches, and traces.

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
- `LocalBackupArchiveCodec`
- `LocalBackupArchiveManifest`
- `LocalBackupCodec`
- `LocalBackupManifest`
- `LocalBackupImportReport`
- `LocalDataBackup`
- `LocalMarkdownExportService`
- `EventLogDao`
- `CapturesDao`
- `AttachmentsDao`
- `MemoryItemsDao`
- `MemoryCandidatesDao`
- `CardsDao`
- `InsightsDao`
- `TodosDao`
- `RuntimeTasksDao`
- `RuntimeRunsDao`
- `RuntimeApprovalsDao`
- `PackInstallationsDao`
- `PermissionGrantsDao`
- `ContextPacketCachesDao`
- `TraceEventsDao`
- `LocalDbEventStore`
- `LocalDbTraceSink`
- `LocalDbApprovalStore`
- `LocalDbMemoryRepository`
- `LocalDbCoreToolCatalog`
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
  backup mode, `includes_secrets`, encryption metadata placeholder, and
  per-section record counts.
- `event_log`, `captures`, `attachments`, `memory_items`, `memory_candidates`, `cards`,
  `insights`, `chat_sessions`, `chat_messages`, `model_provider_configs`,
  `todos`, `runtime_tasks`, `runtime_runs`, `pack_installations`,
  `permission_grants`, `context_packet_cache`, and `trace_events`: JSON rows
  reconstructed through the package record models.

Format v2 adds `attachments`; v1 backups without that section are imported as
empty attachment sets so older local backups remain restorable. Format v3 adds
durable runtime, pack, permission, and context cache sections. Older backups
without those sections import them as empty. `context_packet_cache` is
rebuildable derived state, so restore also tolerates that section missing from a
current backup.

`LocalBackupArchiveCodec` wraps that safe restore document in the user-facing
`.widenote` format. The archive is a zip-compatible compressed directory with:

- `widenote-backup/manifest.json`: archive format, nested backup format,
  backup mode, counts, entry sizes, and sha256 checksums.
- `widenote-backup/restore/safe-backup.json`: the restorable
  `widenote.local_data_backup` JSON.
- `widenote-backup/owner-export/owner-export.md`: the readable secret-free
  Owner Export projection.

Archive writes use a file-streaming zip encoder and temp-file rename. Archive
imports extract entries to a staging directory and verify checksums before the
existing safe restore JSON is imported. The `.widenote` MIME type is
`application/x-widenote-backup`.

`LocalBackupMode.safe` is the default and excludes provider API key values while
preserving provider metadata, default-provider state, and whether a key was
present. `LocalBackupMode.encryptedFull` is reserved for a future encrypted
full-backup path that can carry provider API key values only after callers have
a real encryption boundary. The W7 mobile app does not expose encrypted full
backup yet. Keys must stay out of logs, generated docs, test output, and
automated review prompts.

`LocalBackupImportReport` summarizes restore effects for UI and QA without
exposing backup contents. It reports backup mode, secret inclusion, restored
provider/pack/permission/runtime/cache counts, and whether provider keys need
user re-entry after a safe restore.

`LocalMarkdownExportService` is a human-readable projection of a decoded
backup. It is not restorable and intentionally reports only whether provider
API keys are present; it does not include key values. It summarizes runtime
pack/task/permission status and excludes Context Packet cache contents from the
readable Owner Export projection. It also writes an explicit export boundary so
users and agents do not confuse Markdown with the restore source.

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
persistence, v1-to-current migrations, v9 runtime/pack/approval/permission/
context-cache tables, migration indexes/foreign keys/repeated bootstrap/failure
rollback, pagination, capture/event/task transactional enqueue, permission revoke terminal
state, pending approval storage, approval decisions, canceled/expired approval
records, backup import/export, cache-tolerant restore, tombstone restore behavior,
secret-boundary manifest validation, safe-backup provider credential re-entry
reports, encrypted-full guardrails, and runtime EventStore/TraceSink adapters.
Backup tests also cover the
Markdown projection and verify that provider API key values and Context Packet
cache contents stay out of the readable export.
Core tool catalog tests cover DB-backed Context Packet, Memory read/propose,
todo suggestion, and redacted trace read tools, including required permission
metadata, source refs, limits, redaction, and invalid-input behavior.

The runtime approval store is a persistence boundary, not an execution bridge.
It records pending approval requests and decisions with redacted metadata only.
Approved decisions must be claimed by a future RuntimeKernel control provider in
the same unit of work that resumes or creates the affected run; this package
does not execute approved tools by itself.

## Related Context

- `docs/decisions/0002-use-flutter-and-drift-for-client.md`
- `docs/decisions/0003-build-agent-runtime-kernel.md`
- `docs/decisions/0005-use-memory-first-instead-of-pkm-core.md`
- `docs/rfcs/memory-model.md`
