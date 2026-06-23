# Phase One Module Plan

Status: draft

Date: 2026-06-23

Scope: phase-one repository and module planning for WideNote / Guangji

WideNote is a local-first personal record, native Memory, and Agent Runtime product. Phase one should keep the kernel narrow while the product surface is complete:

```text
quick capture -> timeline/cards -> Memory -> insight
```

Todos, companion, custom agents, exports, documents, and integrations are phase-one capabilities, but they should be delivered through official packs and feature modules rather than being hardcoded into the runtime kernel.

## Module Rules

Every durable module must have a `README.md` that states:

- Purpose
- Ownership boundary
- Public surface
- Dependencies
- Generated artifacts
- Related ADRs or RFCs
- Notes for future agents

When adding, moving, renaming, or deleting a durable module:

- Update the module README.
- Update the parent directory README module map.
- Update `docs/agent-context/project-map.md`.
- Document generated artifacts with source of truth and generation command.
- Create or update an RFC/ADR if the change affects schemas, runtime, Memory, sync, privacy, plugin permissions, Agent Packs, technology stack, licensing, or default UX.

## Existing Module Map

| Module | Responsibilities | Key Interfaces | Suggested Internal Shape | Documentation Requirement |
| --- | --- | --- | --- | --- |
| `apps` | Runnable apps and services | App entrypoints, build commands, deploy commands | `mobile`, `api`, `runner-ts` | Keep `apps/README.md` as app map |
| `apps/mobile` | Flutter app, local UX, local runtime host | App bootstrap, router, DI graph, platform adapters, runtime wiring | See detailed plan below | List app-owned features, generated Flutter/Drift/l10n artifacts, platform boundaries |
| `apps/api` | Optional backend for sync, backup, registry, scheduling, runner coordination | HTTP routes, OpenAPI, sync endpoints, registry APIs, runner coordination APIs | `src/routes`, `src/modules/sync`, `src/modules/registry`, `src/modules/devices`, `src/modules/runner`, `src/storage` | State that API is optional and not required for core local use |
| `apps/runner-ts` | TypeScript runner for self-hosted or cloud execution | Task lease/complete APIs, trace emission, tool execution, model calls | `src/worker`, `src/executors`, `src/tools`, `src/providers`, `src/traces` | Must not define core runtime semantics privately |
| `packages/schemas` | Public runtime contracts | Event, Memory, Agent Pack, Permission, Task, Tool, UI Block, Sync, Trace schemas | `src/event`, `src/memory`, `src/agent_pack`, `src/permission`, `src/task`, `src/tool`, `src/ui_block`, `src/sync`, `src/trace`, `fixtures` | Generated Dart/TS bindings must point back here |
| `packages/dart/core` | Pure Dart primitives and utilities | IDs, clocks, result types, schema helpers, value objects | `lib/src/ids`, `lib/src/time`, `lib/src/result`, `lib/src/json` | Must not depend on Flutter or app-private code |
| `packages/dart/local_db` | Drift/SQLite local persistence | Database, DAOs, migrations, local query APIs | See detailed plan below | Document table ownership and migration commands |
| `packages/dart/agent_runtime` | Local Agent Runtime Kernel | Event dispatch, task queue, pack registry, permission broker, tool registry, traces | See detailed plan below | Link ADR-0003 and runtime docs |
| `packages/dart/ui_blocks` | Flutter rendering for structured UI blocks | Safe UI block widgets/renderers | `lib/src/renderers`, `lib/src/widgets`, `lib/src/theme`, `test/fixtures` | Must not execute arbitrary plugin UI in store-safe path |
| `packages/ts/protocol` | TypeScript schema helpers and validators | Generated types, validators, helpers | `src/generated`, `src/validators`, `src/helpers` | Generated outputs must cite `packages/schemas` |
| `packages/ts/runner_core` | Reusable runner primitives | Task execution, checkpoints, trace helpers, tool boundaries | `src/tasks`, `src/execution`, `src/checkpoints`, `src/traces`, `src/tools` | Must not own API routes or schema definitions |
| `packages/ts/agent_sdk` | Developer-facing SDK for runner-side agents/tools | SDK APIs, examples, compatibility helpers | `src/pack`, `src/tools`, `src/context`, `examples` | Must depend only on public schemas/protocol helpers |
| `packs/official/default` | Default capture-to-insight pack | Manifest, subscriptions, prompts, output event declarations | See official packs below | Must stay conservative and store-safe |
| `docs` | Product and architecture memory | Product docs, ADRs, RFCs, research, agent context | Existing subdirs are appropriate | Project map must remain short and canonical |
| `infra` | Deployment and self-hosting assets | Compose files, deployment examples, infra docs | `docker`, `compose`, `migrations`, `runner`, `observability` when needed | Distinguish official cloud from self-hosted |
| `tools` | Repo automation and generators | Schema generation, validation, linting, pack tooling | `schema_codegen`, `pack_validator`, `doc_lint`, `dev` when introduced | Generated artifact tools must be documented |

## `apps/mobile`

`apps/mobile` owns the runnable Flutter application and local runtime host. It assembles packages; it should not absorb all product logic.

Responsibilities:

- Quick capture and immediate local save.
- Four-tab app shell: Home/Record, Conversations, Todos, Packs.
- Timeline, cards, Memory review, insights, settings, permissions, traces, model providers, backup/export, and pack management screens.
- Flutter navigation, theming, localization, and dependency injection.
- Platform integrations: share sheet, voice input, image/file import, notifications, background hooks, secure storage, app lock.
- Local database lifecycle and runtime startup.
- User-visible permission prompts and trace review.

Key interfaces:

- `AppBootstrap`: initializes database, runtime, provider registry, settings, and enabled packs.
- `AppRouter`: owns app navigation and feature route composition.
- `RuntimeHost`: starts/stops local runtime and connects UI to runtime events.
- `CapturePort`: app-facing capture API that preserves raw input before async processing.
- `PermissionPromptPresenter`: UI boundary for runtime permission requests.
- `ModelProviderSettingsPresenter`: UI boundary for BYOK setup.
- `FeatureModule`: optional interface for feature packages to expose routes, providers, and settings panels.

Suggested internal directories:

```text
apps/mobile/lib/
  app/
  bootstrap/
  navigation/
  theme/
  l10n/
  runtime_host/
  features/
    capture/
    home/
    timeline/
    cards/
    memory/
    insights/
    chat/
    companions/
    todos/
    packs/
    permissions/
    traces/
    settings/
    backup_export/
    privacy_lock/
    model_providers/
  platform/
    share/
    audio/
    camera/
    files/
    notifications/
    background/
    secure_storage/
  generated/
```

Boundary rules:

- Product semantics that must be shared or tested independently should move to `packages/dart/*`.
- Mobile must not define public Event, Memory, Agent Pack, Permission, Task, or Sync contracts privately.
- Platform-specific code may live in the app, but must expose narrow Dart interfaces.

## `packages/dart/local_db`

`packages/dart/local_db` owns local persistence and migrations. It is the SQLite/Drift implementation detail for local-first storage, not the public protocol authority.

Key interfaces:

- `WideNoteDatabase`
- `EventLogDao`
- `CaptureDao`
- `AttachmentDao`
- `CardDao`
- `MemoryDao`
- `MemoryCandidateDao`
- `InsightDao`
- `TodoDao`
- `ConversationDao`
- `AgentRunDao`
- `TaskQueueDao`
- `PermissionDao`
- `PackInstallationDao`
- `TraceDao`
- `SyncStateDao`
- `BackupExportDao`
- `FtsSearchDao`
- `DatabaseMigrations`

Suggested internal directories:

```text
packages/dart/local_db/lib/
  src/database/
  src/tables/
  src/daos/
  src/migrations/
  src/converters/
  src/queries/
  src/fts/
  src/testing/
```

Initial table families:

- `event_log`
- `captures`
- `attachments`
- `cards`
- `memory_items`
- `memory_candidates`
- `memory_evidence`
- `memory_revisions`
- `insights`
- `todos`
- `conversations`
- `messages`
- `runtime_runs`
- `runtime_tasks`
- `agent_outputs`
- `permissions`
- `pack_installations`
- `sync_state`
- `plugin_state`
- `model_provider_configs`
- `trace_events`
- `backup_jobs`
- `export_jobs`
- `search_documents`
- `index_state`

Boundary rules:

- Do not depend on Flutter UI.
- Do not define public schema semantics here; use `packages/schemas`.
- Do not call model providers or external tools.
- Raw captures must be immutable or version-preserving; AI output is stored separately.

## `packages/dart/agent_runtime`

`packages/dart/agent_runtime` owns the local Agent Runtime Kernel implementation.

Responsibilities:

- Append-only event dispatch.
- Agent Pack subscription matching.
- Local task queue coordination.
- Run/task DAG scheduling.
- Permission checks before sensitive actions.
- Tool registry and invocation boundaries.
- Runtime context passed to local agents.
- Trace and audit emission.
- Idempotent handler execution for at-least-once delivery.
- Adapter interfaces for Memory, model providers, and persistence.

Key interfaces:

- `RuntimeKernel`
- `EventDispatcher`
- `SubscriptionMatcher`
- `TaskScheduler`
- `TaskExecutor`
- `PackRegistry`
- `PermissionBroker`
- `ToolRegistry`
- `TraceSink`
- `RuntimeContext`
- `RuntimeTool`
- `RuntimeAgent`
- `MemoryStorePort`
- `ModelGatewayPort`

Suggested internal directories:

```text
packages/dart/agent_runtime/lib/
  src/kernel/
  src/events/
  src/tasks/
  src/packs/
  src/permissions/
  src/tools/
  src/traces/
  src/execution/
  src/adapters/
  src/testing/
```

Boundary rules:

- Runtime writes outputs as new events.
- Runtime must not mutate or overwrite raw captures.
- Runtime must not hardcode default product prompts; those belong in Agent Packs.
- Runtime must not depend on backend or runner-private code.
- External frameworks are adapters, not the kernel.

## Proposed `packages/dart/memory`

Add this package because Memory is a product-semantic layer, not just database rows.

Responsibilities:

- Memory domain model helpers and local service APIs.
- Memory visibility, editability, deletion, provenance, confidence, lifecycle, and invalidation policies.
- Memory candidate acceptance/rejection/merge flows.
- Memory query, scoping, ranking, and source tracking.
- Conversion between events, candidates, accepted Memory, and derived insight context.

Key interfaces:

- `MemoryRepository`
- `MemoryService`
- `MemoryCandidateService`
- `MemoryQuery`
- `MemoryScope`
- `MemoryPolicy`
- `MemoryProvenance`
- `MemoryInvalidationService`
- `MemoryExportView`

Boundary rules:

- Storage implementation should use `packages/dart/local_db`.
- Public Memory contracts belong in `packages/schemas`.
- UI belongs in mobile or `feature_memory`.
- AI extraction prompts belong in Agent Packs, not this package.

## Proposed `packages/dart/model_providers`

Add this package because BYOK provider support is a core zero-account requirement.

Responsibilities:

- Provider-agnostic model interfaces.
- Chat, completion, embedding, vision, audio, and streaming adapter contracts.
- Provider registry and capability metadata.
- Request policy checks for privacy tier, cost, and permission.
- Usage events for trace/audit.
- Credential storage interface, implemented by the app/platform layer.

Key interfaces:

- `ModelProvider`
- `ChatModelClient`
- `EmbeddingClient`
- `VisionModelClient`
- `AudioModelClient`
- `ModelProviderRegistry`
- `ModelRequest`
- `ModelResponse`
- `ModelStreamEvent`
- `ModelCapability`
- `ModelUsageReporter`
- `CredentialStorePort`

Boundary rules:

- Do not store raw secrets directly in this package.
- Do not define Agent Runtime semantics here.
- Do not force official backend or official model proxy.
- Runtime and packs call models through this abstraction.

## Proposed Feature Packages

Feature packages should be introduced when a feature has durable logic or boundaries worth separating from `apps/mobile`. Small screens can remain inside the app until they need a package boundary.

Recommended phase-one feature packages:

- `feature_capture`
- `feature_home`
- `feature_timeline`
- `feature_cards`
- `feature_memory`
- `feature_insights`
- `feature_chat`
- `feature_companions`
- `feature_todos`
- `feature_packs`
- `feature_permissions`
- `feature_traces`
- `feature_settings`
- `feature_backup_export`

Common key interface:

```text
FeatureModule
  id
  dependencies
  routes
  providers
  settingsPanels
  permissionSurfaces
```

Boundary rules:

- Feature packages may depend on Flutter if they own reusable UI.
- Feature packages must not depend on `apps/mobile`.
- Feature packages must not define schemas privately.
- Feature packages should not own database migrations.

## Official Packs

Official packs are product capability bundles. They must depend only on public schemas and SDK boundaries.

Recommended pack shape:

```text
packs/official/<pack_id>/
  README.md
  manifest.json
  subscriptions/
  agents/
  prompts/
  tools/
  permissions/
  ui_blocks/
  outputs/
  fixtures/
  tests/
```

Phase-one pack set:

| Pack | Default | Responsibility |
| --- | --- | --- |
| `default` | enabled | Capture to cards, Memory candidates, lightweight insight |
| `memory-core` | enabled or built-in | Candidate dedupe, merge, provenance, recall policy |
| `file-context` | enabled with permissions | OCR, transcript, file/link parsing |
| `todo` | recommended enabled | Source-linked action items and reminders |
| `companion` | recommended enabled | Character/persona chat, auto-commentary, companion memory |
| `custom-agent` | visible advanced entry | Guided custom agent creation and runtime controls |
| `export` | visible | JSON/JSONL/Markdown/HTML/Obsidian-style projections |
| `integrations` | permission-gated | Calendar, task, files, webhook, MCP, HTTP tools |

`official/default` should stay conservative and store-safe. It should not include high-risk automatic capture, arbitrary script execution, or external side effects.

## Missing Directories To Add

Recommended phase-one additions:

| Path | Why Add It |
| --- | --- |
| `packages/dart/memory` | Memory needs product semantics beyond tables and UI |
| `packages/dart/model_providers` | BYOK and local model access need reusable abstraction |
| `packages/dart/feature_*` | Capture, Memory, chat, todos, packs, traces, and backup need testable feature boundaries |
| `packs/official/README.md` | Official pack namespace needs its own boundary document |
| `tools/schema_codegen` | Schema generation should be reproducible and documented |
| `tools/pack_validator` | Agent Pack manifests and fixtures need validation |
| `tools/doc_lint` | Progressive context and generated artifact rules should be enforceable |
| `docs/rfcs/memory-model.md` | Memory model is cross-cutting and still needs detailed design |
| `docs/rfcs/agent-pack-schema.md` | Manifest, permissions, subscriptions, tools, and UI blocks need RFC-level design |
| `docs/rfcs/model-provider-byok.md` | BYOK behavior affects privacy, UX, and runtime boundaries |
| `docs/rfcs/local-data-backup-export.md` | Data, filesystem, backup, restore, export, and search need a shared spec |

Likely later additions:

| Future Path | Why Later |
| --- | --- |
| `packages/dart/sync_engine` | E2EE sync should follow local data and schema stabilization |
| `packages/dart/search` | Search can start in `local_db`; split when ranking/vector policy grows |
| `apps/desktop` | Future local runtime host after mobile foundation |
| `apps/web` | Future management or cloud UI, not core local-first phase one |

## Progressive Context Loading Rules

AI agents should load context in layers:

1. Read root instructions and `docs/agent-context/START_HERE.md`.
2. Read `docs/decisions/index.md`.
3. Read `docs/agent-context/project-map.md`.
4. Read the nearest area README.
5. Read the target module README.
6. Read related ADRs/RFCs linked from that module.
7. Read only source files needed for the task.

Task-specific context:

| Task Type | Required Context |
| --- | --- |
| Product/default UX | `docs/product/positioning.md`, phase-one technical plan, relevant app/pack README |
| Schema change | `packages/schemas/README.md`, relevant schema family, generated artifact docs, ADR/RFC |
| Runtime change | `docs/architecture/runtime.md`, ADR-0003, `packages/dart/agent_runtime/README.md`, affected schema docs |
| Memory change | Memory RFC when present, ADR-0005, `packages/dart/memory/README.md`, `packages/dart/local_db/README.md` |
| Local DB change | ADR-0002, phase-one technical plan, `packages/dart/local_db/README.md`, migration docs |
| Model provider change | BYOK RFC when present, `packages/dart/model_providers/README.md`, privacy docs |
| Mobile UI change | `apps/mobile/README.md`, relevant `feature_*` README, app routing/bootstrap files |
| Agent Pack change | `packs/README.md`, target pack README, Agent Pack schema docs, permission schema docs |
| Runner/API change | Target app README, `packages/ts/*` README, relevant schema docs |
| Generated file change | Source-of-truth schema/template and generation command before reading output files |

Raw conversation history is not an authoritative decision. Important discussion context must be summarized into `docs/research/`, then linked from RFCs or ADRs.

## Generated Artifact Policy

Generated artifacts must declare:

- Source of truth
- Generator command
- Output paths
- Whether humans may edit the generated output

Expected generated families:

- Dart schema bindings from `packages/schemas`
- TypeScript schema bindings from `packages/schemas`
- Drift generated database code from `packages/dart/local_db`
- Flutter localization files from `apps/mobile`
- Pack manifest docs or pack indexes from `packs/official/*`
- OpenAPI clients/specs from `apps/api` when introduced

Humans should edit schema sources, table definitions, templates, and pack manifests, not generated outputs.
