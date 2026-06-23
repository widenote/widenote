# Technology Stack

## Client

- Flutter + Dart
- Riverpod for dependency injection and state
- go_router for navigation
- freezed / json_serializable for immutable models and JSON
- Drift + SQLite for local data
- SQLite FTS5 for MVP full-text search

Flutter is the recommended client stack because WideNote is mobile-first and needs a strong local runtime on iOS and Android. Native Swift/Kotlin modules can be added for platform-specific capture, share, notification, background, and file capabilities.

## Local Data

Use SQLite + Drift for core local data:

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
