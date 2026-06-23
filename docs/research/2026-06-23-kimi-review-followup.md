# Kimi Review Follow-Up

Date: 2026-06-23

## Context

Kimi CLI login was fixed after an earlier `invalid_authentication_error`. The successful invocation used explicit `--no-thinking`; the prior default configuration pointed at `kimi-code/kimi-for-coding` and had failed before the login/config path was refreshed.

## Architecture Review Takeaways

Kimi agreed with the main direction:

- Memory-first instead of PKM core.
- Local-first Flutter client with pure Dart runtime packages.
- Event-driven Agent Packs.
- Clean-room parity target for MemeX functions except PKM.
- Progressive context disclosure through root, area, module, and file-level docs.

It highlighted missing contracts:

- Memory auto-accept thresholds and sensitivity taxonomy.
- Agent Pack manifest and permission schema.
- Sync placeholders for future device/cloud sync.
- Runner task envelope and output event schema.
- Schema code generation between Dart and TypeScript.

## Code Review Takeaways

Kimi flagged three high-priority implementation risks:

- Flutter capture UI was not connected to the runtime and Memory service.
- `agent_runtime` and `model_providers` had separate model abstractions without a bridge.
- Runtime boundary tests were too narrow.

## Actions Taken

- Added `CaptureOrchestrator` to connect mobile quick capture to `RuntimeKernel` and `MemoryService`.
- Added a mobile orchestration test covering capture event publication, agent output, Memory auto-acceptance, and runtime trace output.
- Added `RuntimeModelClientAdapter` so `ModelProvider` implementations can satisfy the runtime `ModelClient` contract.
- Added runtime tests for handler failure, missing handler, tool permission denial, and empty handler output.
- Added RFC drafts for Memory Model and Agent Pack Schema.
- Updated the project map to include active RFCs, Memory package, and Model Providers package.

## Second Review Actions

Kimi's follow-up review found no P0 issues. It flagged P1 gaps around Memory type policy, missing event defenses, model adapter failure translation, and the imperative-to-manifest Agent Pack transition.

Actions taken:

- Added `MemoryType` to `MemoryProposal` and `MemoryItem`.
- Updated `DefaultMemoryPolicy` so review-only types such as health, finance, location, and credentials cannot be silently auto-accepted.
- Added tests for review-only Memory types.
- Added `CapturePipelineException` and explicit missing-event checks in the mobile capture orchestration path.
- Wrapped provider failures in `RuntimeModelProviderException`.
- Added adapter failure tests.
- Updated Agent Pack Schema RFC with an explicit migration plan from native imperative built-in packs to manifest-first loading.

## Deferred With Rationale

- Splitting `RuntimeKernel`: still under the 800-line hard threshold and currently easier to review as a single vertical slice. Revisit before adding retries, timeouts, parallel dispatch, or persistent queues.
- Sync schemas: cloud sync is explicitly deferred from phase one, but sync object placeholders should be added before implementing local DB migrations.
- Shared Flutter UI components: useful soon, but current UI is still a skeleton and can wait until repeated controls stabilize.

## Third Review Actions

Kimi, Xiaomi `mimo-v2.5-pro`, and isolated subagent reviews were run again after the phase-one foundation landed. The confirmed high-priority findings were:

- Raw capture must be visible before agent processing succeeds.
- `pack.default` and `pack.todo` boundaries must be enforced by tests and manifest validation.
- `model.complete` must be a real runtime permission, not only a manifest declaration.
- `local_db` must expose contract-aligned event, trace, and Memory fields before mobile persistence integration.
- Android emulator QA should verify the actual four-tab app and capture flow.

Actions taken:

- Updated mobile capture state so raw records are inserted as locally saved before async agent processing; failures keep the raw record visible with an agent-failed status.
- Split mobile native packs into `pack.default` for Memory/card/insight and `pack.todo` for source-linked todos.
- Added trace origin fields so the UI shows pack id, agent id, and run id.
- Added sensitive-capture tests so credential-like input routes Memory to review instead of silent auto-accept.
- Added runtime enforcement for `model.complete` through a permission-checked model client wrapper.
- Added runtime tests for official-style default/todo pack output ownership and model-call permission denial.
- Added source schemas, official pack manifests, and `tools/pack_validator`.
- Upgraded `packages/dart/local_db` to schema version 2 with event privacy/subject refs, Memory body/source refs/policy fields, trace schema aliases, pagination, and v1-to-v2 migration tests.

## Android Emulator QA

Manual emulator QA ran on `memex_api35` with package `app.widenote.widenote_mobile`.

Evidence was stored outside the repository at `/tmp/widenote-android-qa-20260623`.

Verified flows:

- App launches to Home/Record.
- Quick capture creates a local record, auto-accepted Memory, source-linked todo, and trace entries.
- Trace UI shows both `pack.default / agent.capture_loop` and `pack.todo / agent.todo_loop` runs.
- Todos tab shows the generated todo with source event provenance.
- Conversation and Plugin tabs render their phase-one control surfaces.
- Final logcat scan found no WideNote fatal exception or ANR pattern.

Known QA note: adb text input encoded spaces in the manual capture text as `%20`; this is an adb input-method artifact, not a product rendering issue.

## Remaining Gaps

- Production mobile bootstrap now initializes `WideNoteLocalDatabase` and injects `LocalDbEventStore` / `LocalDbTraceSink` by default. The remaining persistence gap is restart hydration for user-visible read models, plus durable Memory review, conversation, pack installation, permissions, model settings, backup/export, and richer local tables.
- Conversation, backup/export, plugin installation, and Memory review are currently phase-one surfaces rather than full MemeX-parity implementations.
- Full JSON Schema validation and generated Dart/TypeScript bindings are still deferred until pack loading/codegen becomes active.

## Fourth Review Actions

An architecture subagent reviewed the persistence boundary and confirmed the dependency direction:

```text
agent_runtime -> core
local_db -> agent_runtime + sqlite3
apps/mobile -> agent_runtime + local_db + memory
```

Actions taken:

- Added `LocalDbEventStore` and `LocalDbTraceSink` in `packages/dart/local_db`.
- Kept `agent_runtime` independent from SQLite, Drift, and local DB record types.
- Added runtime adapter tests that publish `wn.capture.created` through `RuntimeKernel`, read back capture/output events from SQLite, and read back run traces from SQLite.
- Added duplicate-event and `appendAll` rollback tests so append-only event semantics are preserved.
- Added a mobile widget-level persistence test that injects an in-memory `WideNoteLocalDatabase` into `CaptureOrchestrator` and reads back runtime events/traces after quick capture.
- Upgraded `local_db` to schema version 3 so trace records preserve runtime `name`, `level`, `message`, `details`, `packId`, `agentId`, and schema-facing trace fields.

Fifth review actions:

- Added `WideNoteLocalDatabase.openPath` so mobile can open a real SQLite file without importing `sqlite3` directly.
- Added `WideNoteMobileBootstrap.production`, which creates `local-data/widenote.sqlite` under the app support directory and exposes Riverpod overrides for local DB wiring.
- Changed `captureOrchestratorProvider` to use `LocalDbEventStore` and `LocalDbTraceSink` from the app-level database provider by default.
- Added mobile bootstrap and widget tests that verify the production bootstrap creates a schema-backed database and the default quick capture path persists runtime events/traces through SQLite.
