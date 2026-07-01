# RFC: Phase-One Umbrella Technical Plan

Status: Accepted implementation baseline

Date: 2026-06-26

## Context

This RFC turns the accepted phase-one product/runtime direction into one
implementation-oriented umbrella plan. It is intentionally broader than a
single ADR: it connects module boundaries, source-of-truth rules, runtime flow,
storage, export, backup, Agent Pack permissions, UI read models, validation
gates, external review, and implementation order.

Related sources:

- `docs/decisions/0009-use-object-truth-and-context-packets.md`
- `docs/research/2026-06-26-product-technical-direction-summary.md`
- `docs/research/2026-06-26-kimi-technical-direction-review.md`
- `docs/research/2026-06-26-implementation-readiness-review.md`
- `docs/research/2026-06-26-phase-one-acceptance-matrix.md`
- `docs/research/2026-06-26-technical-plan-research-synthesis.md`
- `docs/research/2026-06-26-storage-export-selection-options.md`
- `docs/rfcs/phase-one-product-scope.md`
- `docs/rfcs/model-provider-settings.md`
- `docs/rfcs/agent-pack-schema.md`
- `docs/rfcs/memory-model.md`

## Summary

WideNote phase one uses a local-first object model:

```text
raw capture and source material
  -> append-only event evidence
  -> Agent Pack runtime
  -> source-linked Memory/cards/recaps/insights/todos/chat outputs
  -> generated UI read models and Context Packets
  -> backup/export/control surfaces
```

The mobile app remains the canonical phase-one runtime host. SQLite/Drift
object tables hold current object truth. Source media and attachments live as
files with metadata and stable source refs. Append-only events are canonical for
audit, routing, idempotency, and future sync evidence, but phase one does not
adopt full event sourcing.

AI and conversation use generated Context Packets rather than raw private
tables or a canonical Markdown vault. Context Packets are permission-aware,
source-linked, progressively expandable read models. Important packets may be
cached in SQLite, but those caches are rebuildable derived state.

## Goals

- Preserve original user input and source material before any AI processing.
- Keep core usage working without an account, official backend, or live model
  provider.
- Define clear module boundaries so implementation slices can proceed without
  private cross-module coupling.
- Keep Agent Packs dependent on public schemas, manifests, permissions, and
  runtime SDK boundaries.
- Separate restorable Backup from safe Owner Export.
- Make UI surfaces consume read models instead of mutating storage or runtime
  tables directly.
- Define validation gates, emulator acceptance, and Kimi review flow before
  implementation begins.

## Non-Goals

- Do not make Markdown, PKM/PARA, a vector index, a generated card fact, or
  chat history the canonical product truth.
- Do not require cloud sync, an official hosted model proxy, or a remote runner
  for core phase-one use.
- Do not enable community script execution before sandbox, signing, and
  permission ADRs are accepted.
- Do not define exact migration numbers, table names, widget layouts, or copy.
- Do not require live provider calls in CI.

## Module Boundaries

### `apps/mobile`

Owns the runnable Flutter app and local runtime host.

Responsibilities:

- Compose Sheet, camera/photo/audio/text capture, and immediate raw save.
- Home, Chat, Todos, Plugins, Settings, record detail, Memory review, provider
  settings, backup/export, permissions, and trace UI.
- App bootstrap, routing, DI, localization, platform adapters, local database
  lifecycle, and runtime startup.
- User-facing permission prompts and restore/export warnings.

Boundary rules:

- Mobile code may assemble repositories and presenters, but must not define
  public Event, Memory, Agent Pack, Permission, Backup, Export, or Context
  Packet contracts privately.
- UI writes go through feature services/repositories, not direct table edits.
- Platform integrations expose narrow Dart ports.

### `packages/schemas`

Owns public runtime and data contracts.

Phase-one schema families should include:

- Event envelope and source refs.
- Capture/source material metadata.
- Memory candidate/item/provenance.
- Agent Pack manifest, permissions, tools, tasks, runs, and traces.
- Context Packet and citation/source-disclosure envelopes.
- Backup manifest and Owner Export object streams.
- UI block/read-model contracts only when they cross package or pack
  boundaries.

Generated Dart/TS bindings must point back to these schema sources.

### `packages/dart/local_db`

Owns SQLite/Drift persistence and migrations.

Responsibilities:

- Object tables for captures, attachments, Memory, cards, recaps, insights,
  todos, conversations, messages, provider configs, pack installations,
  permissions, settings, backup/export jobs, and context caches.
- Append-only event log, task/run state, trace/audit rows, and tombstones.
- Rebuildable FTS/search documents, index state, and cache tables.

Boundary rules:

- Local DB does not own product policy. It provides transactional storage,
  DAOs, migrations, and query adapters.
- Local DB does not call model providers, runtime tools, or UI.
- Raw capture writes must be immutable or version-preserving.

### `packages/dart/agent_runtime`

Owns the local Agent Runtime Kernel.

Responsibilities:

- Event dispatch, subscription matching, task DAG scheduling, retry, leases,
  dead-letter states, and idempotency.
- Pack registry, permission broker, tool registry, trace sink, and local native
  executor.
- Ports for Memory, model providers, context building, and persistence.

Boundary rules:

- Runtime outputs are events or service calls that create derived objects. It
  must never overwrite raw captures.
- Runtime must not hardcode product prompts. Prompts and output declarations
  belong to Agent Packs.
- External frameworks are adapters, not the kernel.

### Product-Semantic Dart Packages

These packages own domain policy above storage:

| Package | Boundary |
| --- | --- |
| `packages/dart/memory` | Memory candidate policy, auto-accept/review/merge/delete semantics, provenance, revision, source-linked query. |
| `packages/dart/model_providers` | Provider config models, fake clients, request builders, error taxonomy, model capability metadata, credential-store port. |
| `packages/dart/cards` | Source-linked cards and lightweight insight derivation. |
| Future `context` service or module | Context Packet building and invalidation if it outgrows runtime/read-model adapters. Do not create this package until the boundary is real. |

### `packs/official/*`

Official packs are product capability bundles. They use the same manifest,
permission broker, trace, and revocation path as future installable packs.

Phase-one pack boundaries:

| Pack | Default | Boundary |
| --- | --- | --- |
| `pack.default` | Enabled | Capture to summary/card, Memory candidate, policy evaluation, lightweight insight, rolling/final daily recap. It does not emit todos. |
| `pack.todo` | Visible, separately enableable | Source-linked todo suggestions and task lifecycle. |
| `pack.conversation` | Enabled | Chat over local context and Memory; may propose writes only through policy services. |
| `pack.backup_export` | Enabled | Backup/export/import jobs and readable projections. |
| `pack.file_context` | Permission-gated | OCR/transcript/file extraction from user-selected source material. |
| `pack.companion` | Deferred | Companion behavior can return later as a conversation mode or optional pack, but it is not part of the implementation-critical phase-one path. |

## Object Truth and Derived Layers

Phase one has four layers.

### Canonical Source Layer

Canonical source objects are user-owned and must be preserved:

- Raw captures: typed text, audio recording metadata, camera/photo selection,
  and future share/file imports.
- Source files: original audio, images, and attachments on disk with metadata,
  hashes, source refs, and sensitivity/export flags.
- User corrections/revisions to raw captures. Corrections do not silently erase
  original input.

### Runtime Evidence Layer

Events, tasks, runs, and traces are append-only evidence for processing:

- Event log: capture, raw edit/delete, agent outputs, Memory lifecycle, backup
  jobs, permission decisions, and audit facts.
- Task/run state: subscription matches, dependencies, retries, leases, terminal
  states, and dead letters.
- Trace/audit rows: model calls, tool calls, permission checks, output events,
  review actions, and errors.

These rows support routing, idempotency, audit, and future sync. They are not
the only source from which every object must be replayed.

### Semantic Layer

Accepted Memory is canonical for retrieval and personalization, but remains
source-linked derived knowledge. Each accepted Memory item must preserve:

- source refs and evidence snippets or URIs
- candidate id or policy event id
- policy decision and reasons
- sensitivity, memory type, confidence, durability
- user review action when applicable
- revision and tombstone lifecycle

### Derived Object Layer

These objects are durable and user-visible, but not original facts:

- Cards
- Daily recaps
- Insights
- Todo suggestions/items
- Conversation answers
- OCR/transcripts
- Context Packet caches
- Search/FTS/vector indexes, thumbnails, projections

Derived objects must keep source refs and generator metadata. Regenerating or
deleting a derived object must not delete raw captures or source files.

## Context Packets

Context Packets are AI-facing and UI-facing read models generated from source
objects, accepted Memory, and derived objects.

They are not source truth.

### Disclosure Order

```text
0. Current turn and visible app context
1. Accepted Memory
2. Derived summaries/cards/recaps/insights
3. Targeted raw capture/transcript/OCR/source excerpts
4. Attachments only when needed and allowed
```

### Minimum Packet Fields

The schema should include:

- `id`
- `schema_version`
- `surface`: home, chat, recap, pack_run, export_preview, trace_review
- `request_ref` or `subject_ref`
- `source_refs[]`
- `source_versions[]` or content hashes
- `permission_scope`
- `disclosure_level`
- `generator_id`
- `generator_version`
- `pack_id` and `agent_id` when generated for a pack
- `created_at`
- `expires_at` or cache policy when applicable
- `sections[]` with text-first content, citations, redactions, and sensitivity
  markers

### Cache Semantics

Important packets may be persisted in SQLite as rebuildable caches.

Cache invalidation inputs:

- source content hash or version changes
- accepted Memory revision, tombstone, or sensitivity change
- permission grant, revocation, or high-risk classification change
- generator version, pack version, or prompt version change
- local date boundary for daily recap packets
- privacy/export setting changes

Owner Export excludes Context Packet caches. Full `.widenote` backup may carry
them as rebuildable SQLite rows, but restore must tolerate missing, stale, or
invalidated caches.

## Runtime Flow

### Capture Flow

```text
Compose input
  -> validate local permission for the action
  -> save raw capture and source material metadata
  -> store original source files
  -> append `wn.capture.created`
  -> enqueue matching pack tasks in the same transaction
  -> show raw record immediately
  -> run immediate default-pack task
  -> write output events and derived objects
  -> update read models and traces
```

Capture write, event append, and initial task enqueue should be transactionally
tied together. If AI or model processing fails, the raw capture remains visible
and exportable.

### Default Pack Flow

```text
wn.capture.created
  -> pack.default immediate handler
      -> source-linked summary/card
      -> Memory candidate
      -> Memory policy evaluation
      -> lightweight insight candidate
      -> trace
  -> rolling daily recap trigger
  -> final daily recap trigger
```

Daily recap groups by device local date at capture time. Captures preserve
timestamp and time-zone metadata for future travel-aware grouping.

### Conversation Flow

```text
user message
  -> persist conversation/message
  -> build Context Packet progressively
  -> call deterministic fake or configured provider
  -> produce sourced answer
  -> optionally propose Memory/card/todo through policy path
  -> trace model/context/permission decisions
```

Chat cannot directly mutate canonical objects. It may propose writes through the
same services and permission checks used by packs.

### Permission and Idempotency Rules

- Delivery is at least once.
- Handlers must be idempotent.
- Task identity should include event id, subscription id, pack id/version, and
  handler role.
- Permission denied, schema validation failure, user rejection, and revoked
  capability are terminal unless a user action re-enables the task.
- External side effects require effect ids and tool-level dedupe.

## Storage, Backup, Export, and Delete

### Storage Shape

SQLite/Drift stores object state, event evidence, runtime state, permissions,
settings, provider config, pack state, and rebuildable indexes/caches.

The filesystem stores:

```text
media/originals/
media/derived/
backups/
exports/
plugins/
projections/
tmp/
```

Files should use stable ids and hashes so backup/export can verify integrity and
future content-addressing remains possible.

### Backup

Backup restores app state. The current mobile path implements a full
`.widenote` compressed directory backup by default. It includes the SQLite
object snapshot, local media files, and provider credentials needed for direct
use after restore.

A full restorable backup design includes:

- SQLite/object state
- source file metadata and required source files
- provider/model configs, selected defaults, and routing
- installed pack state and settings
- permissions and revocation state
- backup/export job state needed for recovery
- credentials/secrets required to keep the restored app usable

Accepted backup design modes:

```text
Full .widenote backup
  -> compressed directory archive with SQLite snapshot and local media
  -> includes provider secrets needed for direct-use restore
  -> implemented as the default mobile path

Safe JSON / Markdown projection
  -> excludes provider secrets
  -> compatibility/export surface, not the default mobile restore path

Encrypted full backup envelope
  -> future encrypted wrapper around secret-bearing backup data
  -> deferred; do not describe as implemented
```

Current Backup UX must make the full backup's secret-bearing nature explicit
and let users choose the destination through platform save/share surfaces.

### Owner Export

Owner Export is portable user data. It excludes credentials and secrets by
default.

Recommended archive:

```text
manifest.yaml
events.jsonl
records.jsonl
memory.jsonl
derived/cards.jsonl
derived/recaps.jsonl
derived/insights.jsonl
derived/todos.jsonl
conversations.jsonl
attachments/
readable/
checksums.sha256
```

Owner Export may include provider/model metadata without secrets. Derived
outputs must be labeled as AI Derived or App Derived. Soft-deleted and purged
content are excluded by default; a full audit export can be a later advanced
mode.

### Delete and Purge

Working phase-one default:

- Delete is recoverable soft delete.
- Recoverable window is 30 days.
- Purge removes user content and source files, then keeps minimal tombstone
  metadata needed for references, audit, and future sync conflict avoidance.

Keep the 30-day window fixed in phase one, while modeling it so an advanced
configurable setting can be added later.

## Agent Pack Permissions

All packs, including official packs, go through the manifest and Permission
Broker path.

### Permission Vocabulary

Initial vocabulary should cover:

- `source.read.metadata`
- `source.read.text`
- `source.read.transcript`
- `attachment.read.user_selected`
- `memory.read`
- `memory.propose`
- `card.write`
- `insight.write`
- `recap.write`
- `todo.suggest`
- `todo.write`
- `conversation.read`
- `model.complete`
- `network.call.declared_host`

High-risk capabilities require explicit grant and revocation support:

- broad filesystem read
- arbitrary network
- shell/script execution
- background or continuous capture
- raw audio/image/transcript expansion
- location, health, finance, credential-adjacent data
- credential or secret access

### Install and Revocation Behavior

Pack lifecycle:

```text
discover
  -> validate manifest
  -> preview permissions
  -> install disabled
  -> grant permissions
  -> enable subscriptions
  -> run tasks
  -> revoke or disable
```

Revocation must:

- stop future source/context/tool access for the revoked capability
- invalidate affected Context Packet caches
- deny or cancel queued tasks that require the revoked permission
- preserve already-created user-visible outputs unless the user deletes them
- record a permission event and trace

## UI Read Models

UI surfaces consume repositories/read models. They do not directly own canonical
storage semantics.

### Home

Home is a daily return surface:

- bottom Compose Sheet entry
- daily recap grouped by device local date at capture time
- recent 2-3 records
- recent accepted Memory or review-needed Memory candidate highlights
- processing and failure states that never hide raw records
- entry points to Records, Insights, Chat, Todos, Plugins, and Settings

### Records and Detail

Record detail shows:

```text
raw capture/source summary
  -> derived card or summary
  -> source refs and evidence
  -> transcript/OCR/source excerpts on expansion
  -> attachments only when allowed
  -> trace/context status when relevant
```

### Chat

Chat shows:

- persistent local sessions and messages
- sourced answers with record/Memory/todo citations
- empty context, model failure, retry, and offline deterministic states
- write proposals routed through Memory/card/todo policy paths

### Todos

Todos is a first-level tab:

- empty or enable-pack state when `pack.todo` is not active
- inbox, today, future, completed
- suggestion review and source backlinks
- source-linked task status, not recap text as task authority

### Plugins and Settings

Plugins:

- official pack catalog
- installed pack status
- permission preview and revocation
- trace links and run status

Settings:

- model providers
- backup/export/restore
- privacy/delete controls
- app locale
- advanced traces and diagnostics

## Validation Gates

### Unit and Contract Tests

Required coverage:

- schema validation and generated bindings
- source refs and object lifecycle policies
- local DB migrations, tombstones, and backup/export jobs
- event dispatch, subscription matching, idempotency, retries, and traces
- Memory candidate policy, auto-accept, review, merge, delete, and provenance
- Context Packet generation, redaction, cache invalidation, and permission
  scoping
- provider config safe metadata and future encrypted full-backup path
- Agent Pack manifest validation and permission vocabulary

### Widget Tests

Any UI change requires widget tests for rendering, state, navigation, dialogs,
sheets, buttons, gestures, empty/loading/error states, localization, and user
interaction.

At minimum, phase-one UI slices should test:

- zh and en app shells
- Compose Sheet text capture
- audio/camera/photo permission states with fakes
- Home daily recap and recent-record read models
- record detail source expansion
- Chat empty/offline/model-failure/sourced-answer states
- Todos disabled/enable/suggestion/completion states
- Plugins permission grant/revoke states
- Settings provider and backup/export flows

### Orchestration Tests

The core offline orchestration test must prove:

```text
capture created
  -> event appended
  -> pack subscription matched
  -> task executed
  -> Memory candidate created
  -> low-risk Memory auto-accepted
  -> card or insight created
  -> trace contains the run
  -> source links are preserved
```

Use deterministic fake agents and fake model clients by default.

### Android Emulator Acceptance

High-risk mobile flows require serialized Android emulator validation with one
agent owning the emulator at a time.

Acceptance journeys:

- first launch and locale visibility
- text capture and immediate raw record visibility
- microphone/camera/photo picker permission grant and denial paths
- Home to record detail source expansion
- Chat with deterministic local response and source citation
- Todo pack disabled state and enabled suggestion flow
- provider add/edit/test with fake service
- backup/export creation and warning surface
- plugin permission grant, denial, revocation, and trace visibility

If emulator validation is skipped, the implementation summary must record why
and list remaining risk.

## Kimi Review Flow

Kimi review is useful but not authoritative.

Use Kimi for:

- umbrella RFC review before splitting ADRs
- schema/runtime/permission risk review after contract drafts
- implementation readiness review before broad UI/runtime integration
- final risk review before PR publication when credentials/tooling are
  available

Rules:

- Send only sanitized docs, diffs, schemas, test summaries, and non-secret
  fixtures.
- Do not send raw user records, local database contents, backup artifacts, API
  keys, tokens, credentials, or unpublished private user data.
- Keep durable review conclusions in `docs/research/`.
- Resolve review findings through local verification, tests, and accepted
  ADR/RFC constraints.
- Do not block local progress if credentials, quota, network, or tool access
  fail; record the skipped review and continue with local checks.

## Implementation Order

This order minimizes contract churn and lets UI work consume stable read models.

## Coordination and Conflict Isolation

First-wave implementation should not start with broad mobile UI changes. The
current baseline shows that the main conflict hotspot is
`apps/mobile/lib/features/capture/application/capture_orchestrator.dart`, which
still mixes capture orchestration with native default/todo pack definitions.

Coordination rules:

- First stabilize public contracts, durable runtime state, and manifest-to-native
  pack registration.
- Keep mobile UI workers waiting until `RuntimeHost` / pack registry ports are
  stable enough to consume.
- Avoid parallel edits to `capture_orchestrator.dart`, `pack_catalog.dart`,
  `app_router.dart`, and `model_client.dart`.
- When a worker must touch a hotspot file, assign that file exclusively for the
  wave and have other workers consume the new port/interface instead.
- Each implementation worker must run a sanitized Kimi review for its module
  when Kimi CLI is available. Inputs must exclude secrets, real backups, local
  databases, API keys, tokens, and real user records.
- Each module also needs a boundary-case review against
  `docs/research/2026-06-26-phase-one-acceptance-matrix.md`.

### 0. Implementation Baseline

Accepted before implementation:

- Backup UX uses a full `.widenote` directory backup with provider credentials
  as the implemented default, while legacy safe projections remain no-secret
  compatibility surfaces.
- Soft-delete uses a fixed 30-day recoverable window in phase one.
- Provider secrets remain local user data. Default `.widenote` backup exports
  provider credential values for user-managed restore; a future encrypted
  envelope may add stronger protection around the same full restore semantics.
- Companion behavior is deferred from the implementation-critical path.

### 1. Public Contracts

Define schemas for events, source refs, Memory provenance, permissions, Agent
Pack manifests, tasks/runs/traces, Context Packets, backup manifests, and Owner
Export streams.

Validation: schema fixtures, generated bindings, pack validator updates.

### 2. Local DB and Filesystem Adapters

Add or align tables, migrations, DAOs, file metadata, hash/checksum handling,
tombstones, event log, task/run state, trace rows, and context cache rows.

Validation: migration/unit tests, round-trip storage tests, malformed/missing
section tests.

### 3. Capture and Source-Material Lifecycle

Implement transactionally tied raw save, source-file storage, event append, and
initial task enqueue.

Validation: unit tests and widget tests for immediate raw visibility and
failure paths.

### 4. Runtime Kernel and Permission Broker

Implement subscription matching, task scheduling, idempotency keys, permission
checks, traces, denial/revocation, and deterministic fake execution.

Validation: runtime unit tests and the core orchestration test.

### 5. Default Pack Native Slice

Implement `pack.default` as native handlers aligned with manifest shape:
summary/card, Memory candidate, policy evaluation, lightweight insight, and
rolling/final recap trigger modes.

Validation: manifest validation, permission tests, orchestration tests.

### 6. Memory Service

Implement candidate policy, auto-accept, review actions, merge, revisions,
tombstones, provenance, and source-linked queries.

Validation: Memory unit tests plus UI review widget tests.

### 7. Context Packet Builder and Retrieval

Implement progressive disclosure, citation/source expansion, redaction,
permission scoping, cache write/read, and invalidation.

Validation: Context Packet unit tests, chat retrieval tests, permission revoke
tests.

### 8. UI Read Models

Implement Home, Records/detail, Chat, Todos, Plugins, Settings, backup/export,
provider settings, and trace views against repositories/read models.

Validation: widget tests in zh/en and Android emulator journeys.

### 9. Provider Settings and Model Gateway

Implement provider config, fake connection tests, safe metadata export,
encrypted-full-backup guardrails, and deterministic local/fake gateway path.

Validation: provider unit tests, widget tests, backup secret-boundary tests.

### 10. Backup, Export, and Restore

Implement safe Owner Export, backup modes, manifest/checksum validation,
derived-output labeling, restore warnings, and cache-tolerant restore.

Validation: successful round trip, unsupported version, malformed payload,
missing sections, secret-bearing warning/encryption path, and export redaction.

### 11. Todo, Conversation, Recap, and Optional Packs

Implement `pack.todo`, conversation write proposals through policy, stable daily
recap objects, and optional companion mode only after core contracts and
permissions are stable.

Validation: pack-specific tests, widget tests, emulator flows.

### 12. Hardening and Split ADRs

Run final Kimi review when available, close open findings, split stable
umbrella decisions into ADRs, update module READMEs/project map when actual
module changes land, and prepare implementation PRs.

## Open Engineering Follow-Ups

- Finalize exact Context Packet schema and invalidation keys.
- Decide which provider/model metadata belongs in `packages/schemas`.
- Decide whether companion mode returns later as conversation mode or a separate
  optional pack.
- Defer cloud sync conflict resolution, multi-device tombstone reconciliation,
  script sandboxing, and community marketplace rules to later ADRs/RFCs.

## Decision Outcome

Accepted as the implementation baseline for phase-one umbrella work. Stable
sub-decisions should still be split into ADRs after the first implementation
wave proves the module boundaries.
