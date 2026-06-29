# Phase One Technical Plan

Status: planning baseline; superseded for current implementation state by
`docs/rfcs/phase-one-umbrella-technical-plan.md` and
`docs/research/2026-06-26-w7-current-integration-state.md`

Date: 2026-06-23

Scope: WideNote phase-one product and architecture plan

WideNote phase one should fully cover the MemeX product capability set except PKM/PARA as a core model. The product source of truth is native Memory, not Markdown notes, PARA folders, a vector index, or chat history. MemeX and Omi are references for behavior and interaction patterns only; WideNote must keep its own schemas, runtime, prompts, UI, and implementation.

## Goals

- Provide the full phase-one user loop: capture, timeline cards, Memory, insights, conversation, todos, Agent Packs, privacy, model setup, backup, and export.
- Keep the default product usable with no account and no official backend.
- Build a WideNote-owned event-driven Agent Runtime Kernel.
- Store important personal context as visible, editable, deletable Memory with provenance.
- Use progressive context disclosure in both product data and repository documentation.
- Keep behavior parity clean-room: product specs are allowed, copied implementation details are not.

## Non-Goals

- Do not make PKM/PARA, Markdown vaults, wiki pages, or backlinks the product core.
- Do not make an official cloud account, hosted model proxy, or remote runner mandatory.
- Do not let third-party agent frameworks define WideNote runtime semantics.
- Do not copy MemeX or Omi code, database schemas, prompts, UI assets, private APIs, or test fixtures.

## Architecture

```text
apps/mobile
  Flutter app, local database, local runtime host, model provider setup,
  permissions, trace review, and default offline UX

packages/schemas
  Event, Task, Run, Memory, Agent Pack, Permission, Tool, Trace,
  UI Block, Sync Object, Backup, and Export contracts

packages/dart/*
  core, local_db, agent_runtime, ui_blocks, memory,
  model_providers, and feature modules

packs/official/*
  default capture flow, memory core, file context, todo, companion,
  custom agent, export, and integration packs

apps/api and apps/runner-ts
  optional encrypted sync, backup, registry, scheduling, webhook ingress,
  remote runner, and hosted integration support
```

The mobile app is the canonical phase-one runtime. Backends and runners enhance reliability, ecosystem reach, and long-running work, but they do not own the user's canonical records or Memory.

## Phase-One Capability Contract

Phase one is not a tiny MVP. It should cover the complete MemeX-like surface, with capabilities split between the core app and official packs so the runtime remains clean.

| Area | Phase-One Coverage |
| --- | --- |
| Capture | Text, voice, image, screenshot/photo import, share sheet, links, files, raw attachment preservation |
| Timeline and cards | Raw record timeline, asynchronous AI cards, card types for tasks/events/routines/progress/articles/snippets/quotes/links/conversations/people/places/metrics/transactions/specs/ratings/gallery, tags, entities, cross references |
| Memory | Memory candidates, user review, accept/edit/delete/merge, provenance, confidence, lifecycle, recall, source citation |
| Insights | Today review, periodic summaries, trend/comparison/progress/map/timeline/gallery-style insight outputs |
| Conversation | Ask WideNote, Memory QA, conversation history, source citations, save answer as record/Memory/todo |
| Companion | Character/persona mode, long-term companion memory, auto-commentary on cards, 1:1 chat, character card import/export as pack features |
| Todos | AI-suggested tasks, manual tasks, source-linked action items, today/future/completed views |
| Agent Packs | Default pack, custom agent creation, per-agent model profile, event triggers, sync/async execution, dependencies, retry, traces, permission review |
| Providers | BYOK model setup, per-pack/per-agent model profiles, OpenAI-compatible first, Anthropic/Gemini/local/other adapters behind capability metadata |
| Privacy | Local-first default, app lock, permission broker, trace/audit, local-only/privacy-tier flags, sensitive remote execution gates |
| Backup/export | Current W7: safe backup/restore and readable Owner Export without provider secrets; future: encrypted full backup, JSON/JSONL archive export, Markdown/HTML/Obsidian-style projections, debug export behind explicit switch |
| Settings | Model providers, permissions, packs, backup/export, location context, trace review, privacy lock |

High-risk continuous capture surfaces such as notifications, SMS, screen content, automatic screenshots, and always-on listening should be implemented as explicit advanced/community packs, not enabled by default.

## Technology Stack

| Layer | Choice |
| --- | --- |
| Client | Flutter + Dart |
| State and DI | Riverpod |
| Navigation | go_router |
| Models | freezed + json_serializable, generated from public schemas where possible |
| Local DB | Current W7: hand-written `sqlite3` + SQLite; long-term target: Drift + SQLite |
| Search | SQLite FTS5 for MVP, with app-generated Chinese n-gram text; vector index as rebuildable projection |
| Attachments | Local filesystem plus SQLite metadata and checksums |
| OCR/STT | Platform adapters first; local or cloud providers behind permissions |
| Model access | BYOK provider adapters; official proxy only as optional enhancement |
| Backend | TypeScript + Fastify + PostgreSQL + S3-compatible object storage |
| Queue/runner | Local SQLite queue first; TypeScript runner for remote work; Hatchet/Inngest/Temporal remain later adapters |
| Plugin runtime | Declarative Agent Packs first; scripts/webhooks/native builtins behind stricter permission and sandbox RFCs |

## Local Data Model

SQLite owns structured local truth. Current W7 uses hand-written `sqlite3`
DAOs; Drift remains the long-term target from ADR-0002. The filesystem owns
large objects, backup/export packages, plugin bundles, and rebuildable
projections.

Initial table families:

| Table Family | Purpose |
| --- | --- |
| `event_log` | Append-only causal record of product and runtime events |
| `captures` | Raw user input and imported material |
| `attachments` | Original and derived media/file metadata, paths, hashes, OCR/transcript snippets |
| `cards` | Structured timeline objects derived from captures |
| `memory_items` | Long-term Memory source of truth |
| `memory_candidates` | AI-proposed Memory changes awaiting policy/user action |
| `memory_evidence` | Source references and quotes for Memory provenance |
| `memory_revisions` | User and system edits to Memory |
| `insights` | Derived review, trend, summary, map, gallery, and narrative outputs |
| `todos` | Source-linked tasks and action items |
| `conversations` / `messages` | Chat, companion, debug, and agent conversation history |
| `agent_runs` / `runtime_tasks` | Runtime run/task DAG state |
| `trace_events` / `trace_spans` | Local audit trail for agent/model/tool behavior |
| `plugins` / `pack_installations` | Installed pack/plugin metadata and state |
| `permissions` / `permission_grants` | Runtime permission grants and revocations |
| `settings` / `model_provider_configs` | User settings and model configuration metadata |
| `backup_jobs` / `export_jobs` | Backup, restore, and export task state |
| `search_documents` / FTS tables | Rebuildable local search projection |
| `index_state` / `index_jobs` | Rebuild progress for FTS/vector/projection indexes |

Raw captures and original attachments must be immutable or version-preserving. AI output is always stored separately as events, cards, candidates, Memory revisions, insights, todos, or UI blocks.

## Filesystem Layout

```text
db/
  widenote.sqlite
media/
  originals/yyyy/mm/{attachment_id}-{sha256}.{ext}
  derived/{attachment_id}/thumb.webp
  derived/{attachment_id}/waveform.json
exports/{export_job_id}/
backups/{backup_id}.widenote
plugins/
  installed/{plugin_id}/{version}/
  cache/{source_hash}/
projections/
  markdown/{projection_id}/
  character_cards/{projection_id}/
tmp/
```

`projections/`, FTS, and vector indexes are rebuildable. They must never become the canonical source for Memory or records.

## Memory-First Model

Memory lifecycle:

```text
draft -> active -> superseded
              -> deleted
              -> expired
              -> conflict -> active/superseded/deleted
```

Candidate lifecycle:

```text
pending -> auto_accepted -> memory_items.active
        -> accepted -> memory_items.active
        -> rejected
        -> merged
        -> needs_review
        -> auto_dismissed
```

Default policy:

- AI first writes proposed Memory changes through the Memory service, which records evidence and policy results.
- Durable, low-risk, non-conflicting Memory is auto-accepted by default.
- Low-confidence, conflicting, highly sensitive, or policy-unclear Memory enters review.
- Every Memory has provenance, confidence, sensitivity, scope, lifecycle status, and revision history.
- Deletions create tombstones so sync and restore do not resurrect removed Memory.
- Conflicts must be visible rather than silently overwritten.
- The user experience should be mostly silent: review surfaces are for correction and audit, not a required queue for every fact.

## Agent Runtime

Core runtime flow:

```text
raw capture
  -> event_log append
  -> subscription matcher
  -> run/task DAG
  -> local executor or authorized runner
  -> PermissionBroker gated model/tool/context calls
  -> output events
  -> cards, Memory candidates, insights, todos, UI blocks
  -> trace/audit review
```

Runtime rules:

- Events are append-only.
- Delivery is at least once.
- Handlers must be idempotent.
- Sync work is local, light, low-risk, and deadline-bound.
- Async work uses durable task rows, dependencies, retry policy, leases, and dead-letter states.
- External side effects require effect ids and tool-level dedupe.
- Permission denied, schema validation, and user rejection are not auto-retried.
- Prompt injection risks from captures, web pages, and attachments are handled through context redaction and tool approval.

Agent Pack manifest v1 should include metadata, compatibility, entrypoint kind, subscriptions, DAG nodes, agents, model profiles, permissions, tools, UI block types, settings schema, secrets schema, storage quota, checksum, and signature metadata.

Pack lifecycle:

```text
discover
  -> verify checksum/signature
  -> compatibility check
  -> permission preview
  -> install disabled
  -> grant permissions
  -> enable subscriptions
```

Disable stops subscriptions but keeps user-visible outputs. Uninstall can remove pack state while preserving user-visible records by default.

## UI and Interaction

Phase one uses four primary tabs:

| Tab | Role | Key Surfaces |
| --- | --- | --- |
| Home / Record | Record first, then key information | Quick text/voice/image/share input, today timeline, AI processing state, Memory candidates, review, insights, recent conversations |
| Conversations | Chat history and companion modes | Conversation list, Memory QA, source citations, role/persona selector, save as record/Memory/todo |
| Todos | Source-linked action layer | Inbox, today, future, completed, AI suggestions, source record backlinks |
| Packs | Capability marketplace and control room | Official packs, installed packs, custom agents, permissions, model providers, backup/export, trace review |

Important states:

- Raw record is visible immediately even when AI processing is pending.
- AI failures never hide or destroy the raw record.
- Permission prompts explain capability, scope, data access, remote access, and revocation.
- Memory candidates are reviewable in context, not hidden inside settings.
- Trace UI is a trust feature, not just a developer debug screen.

## Backend and Runner

The backend is optional in phase one.

| Capability | Default | Optional Backend Role |
| --- | --- | --- |
| Capture, cards, Memory, local search | Mobile | None |
| Backups | Local package | Store encrypted backup objects |
| Sync | Deferred from core phase one | E2EE object sync with tombstones after RFC |
| Pack registry | Static signed index | Search, revoke, rating, paid distribution |
| Runner | Local executor | Long tasks, scheduling, webhooks, external integrations |
| Model access | BYOK direct | Optional proxy for enterprise/account billing |
| Push/schedule | Device best effort | Reliable push and remote scheduling |

Remote runners receive only authorized task envelopes and minimal context. They return output events and trace data; they do not write mobile-private tables directly.

## Official Pack Set

| Pack | Phase-One Role |
| --- | --- |
| `official/default` | Default capture-to-card-to-Memory-candidate-to-insight flow |
| `official/memory-core` | Candidate dedupe, merge, provenance, recall policy |
| `official/file-context` | Image/audio/file/link parsing, OCR/transcript extraction |
| `official/todo` | Source-linked action items and reminders |
| `official/companion` | Character/persona chat, auto-commentary, companion memory |
| `official/custom-agent` | User-created agents with guided setup and advanced controls |
| `official/export` | JSON/JSONL/Markdown/HTML/Obsidian-style projections |
| `official/integrations` | Calendar/task/files/webhook/MCP/HTTP integrations behind permissions |

These packs are part of phase-one coverage. The split is architectural: it keeps the kernel small while making the product feature-complete.

## Clean-Room Development

Allowed references:

- Public product behavior, user journey, and capability lists.
- Public documentation about local-first storage, Agent Packs, marketplaces, and APIs.
- Public framework principles such as durable execution, tracing, guardrails, and human review.

Forbidden:

- Copying MemeX/Omi source code, database schemas, prompts, UI assets, internal algorithms, migrations, private APIs, or test data.
- Renaming a reference schema and placing it into `packages/schemas`.
- Making Agent Packs depend on reference-project private structures.

Process:

1. Summarize reference behavior into `docs/research/`.
2. Convert it into WideNote-owned RFCs and schemas.
3. Implement only from WideNote specs.
4. Keep acceptance tests based on WideNote behavior, not copied fixtures.

## Reference Design Issues We Intentionally Fix

The current public MemeX implementation is a useful reference, but WideNote should not inherit its structural debt.

| MemeX Pressure Point | WideNote Correction |
| --- | --- |
| PKM/Markdown leaks into prompts, UI, events, and onboarding | Native Memory is core; PKM-like output is projection/export |
| Filesystem, SQLite, Markdown, JSON memory, cache, and FTS all act semi-authoritative | One canonical structured truth per durable concept; projections are rebuildable |
| Profile Memory is summarized JSON/Markdown rather than itemized lifecycle objects | `memory_items`, `memory_candidates`, provenance, revisions, conflicts, tombstones |
| Router/facade owns too much initialization and wiring | Bootstrap, runtime, data, feature, and pack registration have separate modules |
| Event payloads are app-specific strings without full envelope semantics | Schema-defined events with privacy, trace, causation, correlation, idempotency, retention, redaction |
| Task executor is powerful but monolithic | Scheduler, executor, lease, retry, dead-letter, run store, and trace are separate runtime concepts |
| Permissions are strong around files but not product-wide | PermissionBroker gates records, Memory, models, network, tools, runner, side effects, UI blocks |
| Custom agents are configuration-heavy rather than installable products | Agent Packs are signed/versioned manifests with lifecycle, permissions, outputs, and traces |
| Legacy HTML/dynamic UI can leak rendering complexity into screens | Store-safe `ui_blocks`; WebView/generated UI is advanced and permission-gated |
| Product concepts compete: timeline, PKM, Memory, insights, companion, schedule | Four-tab UX organized by user jobs: Record, Conversations, Todos, Packs |

See `docs/research/2026-06-23-memex-design-critique.md` for the full critique.

## Required RFCs

- Memory model, lifecycle, provenance, deletion, conflict, and recall.
- Agent Pack manifest, subscriptions, DAG, permissions, tools, UI blocks, and lifecycle.
- BYOK model provider abstraction and model routing.
- Local data layer, backup, restore, export, and search.
- E2EE sync, device pairing, tombstones, and runner trust model.
- Plugin sandbox, script runtime, marketplace signature/revocation, and community/official capability split.
- UI interaction spec for four tabs, Memory review, trace review, and permissions.
- Engineering complexity and test enforcement.

## Open Decisions

- Whether Todo is enabled by default or enabled during onboarding as an official pack.
- Whether Companion appears as a first-class mode inside Conversations or as a pack-installed preset only.
- The exact low-risk threshold for auto-accepting Memory candidates.
- E2EE sync is post-core phase one; phase one keeps schema placeholders and local tombstone/revision concepts.
- Whether script plugins are allowed in store builds, community builds, or only self-hosted runner environments.
- How much location context is enabled by default.
- Which local STT/OCR path is acceptable for app size, language support, and privacy.
