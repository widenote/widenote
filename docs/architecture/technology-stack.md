# Technology Stack

## Client

- Flutter + Dart
- Riverpod for dependency injection and state
- go_router for navigation
- freezed / json_serializable for immutable models and JSON
- SQLite for local data; the current implementation uses hand-written
  `sqlite3` DAOs, while Drift remains the long-term client target
- SQLite FTS5 for MVP full-text search

Flutter is the recommended client stack because WideNote is mobile-first and needs a strong local runtime on iOS and Android. Native Swift/Kotlin modules can be added for platform-specific capture, share, notification, background, and file capabilities.

## Local Data

Use SQLite for core local data. The accepted long-term target is SQLite +
Drift, but the current phase-one implementation intentionally uses hand-written
`sqlite3` DAOs while the local object model is still settling:

- `event_log`
- `captures`
- `memory_items`
- `agent_runs`
- `agent_outputs`
- `attachments`
- `permissions`
- `sync_state`
- `plugin_state`

Do not make AI output destructive. Preserve raw records and write derived results separately.

## 2026-06-26 Amendment: Current SQLite Implementation

ADR-0002 still selects Flutter + SQLite + Drift as the durable client
direction. The W7 phase-one state has not introduced Drift-generated tables or
DAOs yet. Current local truth lives in `packages/dart/local_db` as explicit
SQLite schema, migrations, row mappers, and DAO APIs built on the pure Dart
`sqlite3` package.

Treat Drift as the migration target for a later stabilization pass, not as the
current implementation. Generated Drift artifacts must not be hand-written into
docs or source; when introduced, their source of truth and generation command
must be documented in the owning module README.

## Backend

- TypeScript
- Fastify initially
- PostgreSQL
- S3-compatible storage, with MinIO for self-hosting
- Redis + BullMQ initially for simple queues

Backend features are optional enhancements: sync, backup, registry, scheduling, push, hosted runner, and official cloud services.

## Runner

Start with a TypeScript runner. Later evaluate Hatchet or Inngest for self-hosted durable execution, and Temporal for high-reliability cloud or enterprise use.

## AI Providers

The mobile client should use thin provider adapters and support user-provided keys. Runner-side integrations can use provider abstraction libraries and agent SDKs, but those SDKs must not define WideNote's core runtime model.
