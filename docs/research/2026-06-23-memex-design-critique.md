# 2026-06-23 MemeX Design Critique

Status: draft

Reference commit: `memex-lab/memex@73c215f266b9ba0799971789dd84eb3377d017e0`

Scope: product and architecture issues in the current public MemeX implementation that WideNote should avoid or repair in its own design. This is a clean-room critique: it describes observable architecture and product tradeoffs, not code to copy.

## Summary

MemeX has strong product instincts: local-first capture, rich cards, custom agents, BYOK, companion memory, backup/restore, and a real test suite. The main problems are not missing ambition. They come from multiple product generations coexisting at once:

- File workspace as data model.
- SQLite as task/cache/status model.
- Markdown/PKM as knowledge model.
- JSON profile memory as agent context.
- Agent state and prompts as hidden behavior model.
- UI cache/rendering as another projection model.

WideNote should preserve the product capability surface but reduce the number of competing sources of truth.

## Design Issues To Avoid

### 1. PKM and Markdown became too central

MemeX positions Markdown/PKM as data freedom and knowledge organization. That is valuable for export, but it also leaks into prompts, UI, events, stats, onboarding, search labels, and skill names. The result is that capture, Memory, insights, and companion behavior can depend on a note-taking metaphor even when the user's real need is recall and action.

WideNote fix:

- Native Memory is the long-term context source of truth.
- Markdown, Obsidian, HTML, character cards, and documents are projections.
- No core prompt or runtime contract should require PKM/PARA.

### 2. Too many semi-authoritative storage layers

MemeX uses filesystem workspace data, YAML/JSON/Markdown files, Drift tables, event logs, task queues, card caches, FTS projections, character memory files, and JSON profile memory. Each is reasonable alone; together they create consistency and migration pressure.

WideNote fix:

- SQLite/Drift owns structured truth.
- Filesystem owns large objects and rebuildable artifacts.
- Projections are explicitly rebuildable.
- Memory, cards, tasks, conversations, permissions, and traces have public schemas.

### 3. Memory is not first-class enough

Current MemeX has Memory-related UI and services, but the observed profile Memory path is file-backed JSON with an archived Markdown profile plus a recent buffer. It can summarize, append, and condense, but it lacks a clear item lifecycle with candidate review, provenance, conflict state, tombstones, revision history, and source-linked recall as the default contract.

WideNote fix:

- `memory_items` is a structured table and schema family.
- AI writes `memory_candidates`.
- Active Memory has provenance, confidence, sensitivity, lifecycle, revisions, and deletion tombstones.
- Memory recall returns reasons and source refs.

### 4. The router/facade tends toward a god object

MemeX documentation says `MemexRouter` should be thin, but the current implementation still owns initialization, DB setup, task registration, event subscription, migrations, search startup, notification startup, backup scheduling, custom agent registration, and many repository-facing methods.

WideNote fix:

- `apps/mobile` owns bootstrap orchestration only.
- Runtime registration belongs to `packages/dart/agent_runtime`.
- Data migrations belong to `packages/dart/local_db`.
- Feature use cases belong to feature packages.
- Backend/runner registration is not routed through the mobile data facade.

### 5. Event protocol is not explicit enough

MemeX has a useful event bus, but current events are string-typed and app-specific, with limited shared envelope semantics. Some event payloads still carry PKM timestamps or namespaces. There is no single public schema for event privacy tier, idempotency key, trace id, causation/correlation, retention, redaction, and remote execution constraints.

WideNote fix:

- Define `Event` in `packages/schemas`.
- Every event has schema version, actor, subject ref, privacy tier, trace id, causation id, correlation id, idempotency key, redaction policy, and retention policy.
- Pack subscriptions consume schema-defined events, not private app payloads.

### 6. Task execution is powerful but too monolithic

MemeX has a persistent local task executor with retry, dependencies, queue ownership, background handling, stale recovery, and crash guards. It is useful, but concentrated in a large executor service and registered by router code. Task semantics are not clearly separated into public task envelope, scheduler, lease manager, execution adapter, retry policy, and dead-letter policy.

WideNote fix:

- Split runtime concepts: `TaskScheduler`, `TaskExecutor`, `RunStore`, `LeaseManager`, `RetryPolicy`, `DeadLetterStore`, and `TraceSink`.
- Put task/run schemas in `packages/schemas`.
- Keep local SQLite queue as one implementation, not the runtime contract.

### 7. Permission is too file-centric

MemeX has serious file permission work and action approvals, which is a strength. But the permission model is not yet a single product-wide contract for records, Memory, attachments, network, model calls, calendar/task writes, external side effects, remote runner access, plugin storage, UI blocks, and cross-pack calls.

WideNote fix:

- `PermissionBroker` is the only gate for data reads, model calls, tools, and side effects.
- Tool schemas declare permissions, side-effect kind, approval requirement, and effect id.
- Pack manifests declare requested permissions before install/enable.
- Permission grants are auditable and revocable.

### 8. Custom agents are powerful but not enough like installable products

MemeX custom agents expose event triggers, per-agent models, prompts, skills, working directories, JavaScript execution, dependencies, sync/async modes, and retry. The product direction is right, but WideNote should make capabilities installable, versioned, signed, permission-previewed, traceable Agent Packs rather than mostly configuration living inside app services.

WideNote fix:

- Agent Pack manifest is a first-class schema.
- Pack lifecycle: discover, verify, compatibility check, permission preview, install disabled, grant, enable.
- Pack output uses events and UI blocks.
- Pack upgrade and uninstall preserve user-visible outputs by default.

### 9. Generated UI and legacy rendering need a safer boundary

MemeX supports native card factories, dynamic timeline UI, and legacy HTML rendering. This provides flexibility but risks UI-specific special cases leaking into screens and card detail pages. Legacy rendering paths also increase security and maintenance burden.

WideNote fix:

- Store-safe UI uses `ui_blocks` with native renderers.
- WebView/HTML/generative UI is advanced and permission-gated.
- Screens render structured blocks; they do not branch on many card-specific internals.

### 10. Product navigation is feature-rich but mentally crowded

MemeX contains timeline, knowledge, insight, chat, memory, characters, calendar/schedule, settings, backup, model config, and agent activity. The breadth is impressive, but the center of gravity is less clear because PKM, cards, Memory, insight, and companion all compete as primary concepts.

WideNote fix:

- Four primary tabs: Home/Record, Conversations, Todos, Packs.
- Memory review appears as first-class cards and panels inside Home and Chat, not as hidden infrastructure.
- Pack/settings/trace/model controls live under Packs.
- Todo and companion are phase-one visible capabilities but implemented as official packs/modes.

### 11. Backup and workspace portability are valuable but should be manifest-first

MemeX supports workspace backup/restore and storage location options. The risk is that workspace layout and legacy formats become implicit APIs. As data families grow, restore/merge and cross-device sync become harder without a manifest-driven object model.

WideNote fix:

- Backup packages include a manifest, schema versions, checksums, encryption metadata, file list, and rebuild policy.
- Restore runs through staging, integrity check, schema migration, and explicit replace/merge modes.
- Generated indexes and projections are not backed up as truth.

### 12. Model/provider configuration is rich but should be capability-routed

MemeX supports many providers and per-agent model config. WideNote should keep that strength, but avoid letting UI/provider details leak into runtime behavior.

WideNote fix:

- Pack agents declare capability needs, not vendor names.
- `ModelRouter` selects provider based on user BYOK config, privacy tier, cost, context window, vision/audio/tool support, and local-only constraints.
- Model calls are traced and permission-gated.

## WideNote Design Rules Derived From This Critique

- One canonical structured truth per durable concept.
- Raw captures are immutable or version-preserving.
- AI output is always a new event or derived object.
- Memory is native, structured, source-linked, and user-controllable.
- Pack behavior is declared through manifests, not hidden in app initialization.
- Tools and side effects always pass through permission and trace.
- Exports and generated documents are projections.
- UI is organized around user jobs, not internal storage models.
- Legacy compatibility is quarantined behind import/export/migration paths.

## Follow-Up Specs

This critique should inform these RFCs:

- Memory model and lifecycle.
- Local data, filesystem, backup, restore, and export.
- Agent Pack manifest and lifecycle.
- Permission and tool side-effect model.
- UI block rendering and generated UI safety.
- Four-tab product interaction spec.

