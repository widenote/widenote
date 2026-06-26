# Current Implementation Baseline

Status: historical pre-wave baseline; superseded for current state by
`2026-06-26-w7-current-integration-state.md`
Date: 2026-06-26
Scope: current code inventory before phase-one implementation waves

> Historical note: this document was the read-only inventory before the W7
> implementation and integration wave landed. Use it for pre-wave gap evidence
> only. For the current phase-one usable-state boundary, read
> `docs/research/2026-06-26-w7-current-integration-state.md` and
> `docs/research/2026-06-26-w7-integration-qa.md`.

## Global Conclusion

The strongest current implementation baseline is:

```text
apps/mobile
  + packages/dart/local_db
  + packages/dart/agent_runtime
```

The repository already has a working vertical slice:

```text
capture
  -> runtime event
  -> native pack handler
  -> Memory / card / insight / todo
  -> trace
  -> local DB / read models
```

The main gaps are contract closure and durability:

- schema/status drift across `packages/schemas`, Dart runtime, Memory, and
  local DB
- runtime task/run/permission/pack state still not fully durable
- official packs exist as manifests but mobile/runtime still duplicate pack
  definitions in code
- Context Packet/read-model layer is not implemented
- provider/model routing is mostly global default/fallback

## Recommended First Implementation Order

1. Align `packages/schemas` with Dart runtime, Memory, and local DB names and
   required fields.
2. Add durable runtime task/run, pack, and permission persistence.
3. Build manifest-to-native pack registry so mobile stops hardcoding pack
   definitions in multiple places.
4. Add mobile RuntimeHost and real pack/permission status wiring.
5. Add Context Packet/read-model and per-pack/per-agent model routing.

## Module Baseline

### `apps/mobile`

Existing:

- Flutter shell, Riverpod, GoRouter, four main tabs, timeline, Memory, chat,
  todos, plugins, backup, traces, and model providers.
- Production bootstrap opens `local-data/widenote.sqlite`.
- `CaptureOrchestrator` already runs a local capture-to-derived-output slice.

Gaps:

- `capture_orchestrator.dart` is the largest hotspot and currently hardcodes
  default/todo pack behavior.
- Pack definitions exist in orchestrator, manifests, and catalog, creating drift.
- Plugin/permission pages are mostly static control surfaces.
- Voice/image paths use fake adapters.
- No dedicated RuntimeHost, feature module boundary, or Context Packet layer.

First cut:

- Add a manifest-aligned runtime/pack registry or RuntimeHost boundary so mobile
  loads native handlers from one source of pack truth.

Conflict-prone files:

- `apps/mobile/lib/features/capture/application/capture_orchestrator.dart`
- `apps/mobile/lib/features/capture/application/capture_controller.dart`
- `apps/mobile/lib/app/app_router.dart`
- `apps/mobile/lib/features/plugins/application/pack_catalog.dart`
- `apps/mobile/lib/app/model_client.dart`

### `packages/dart/local_db`

Existing:

- Handwritten SQLite schema v7.
- Tables for event log, captures, attachments, Memory, cards, insights,
  conversations/messages, provider configs, todos, and trace events.
- Runtime adapters, Memory repository adapter, JSON backup v2, and Markdown
  projection.

Gaps:

- Not yet Drift.
- Missing phase-one durable tables for runtime tasks/runs, pack installations,
  permissions, sync/plugin/index/search/context cache, and backup/export jobs.
- Raw capture upsert exists but immutability/versioning needs stronger guardrails.
- Provider API key is still local DB/backup secret-bearing data.
- No FTS/context packet cache table.

First cut:

- Add runtime task/run plus pack/permission durable tables and DAOs, then include
  them in backup/import/migration tests.

Conflict-prone files:

- `packages/dart/local_db/lib/src/models.dart`
- `packages/dart/local_db/lib/src/migration.dart`
- `packages/dart/local_db/lib/src/daos.dart`
- `packages/dart/local_db/lib/src/backup_export.dart`
- `packages/dart/local_db/lib/src/runtime_adapters.dart`

### `packages/dart/agent_runtime`

Existing:

- Local runtime kernel with event publish, subscription matching, in-memory
  tasks/runs, dependencies, retry/cancel, permission checks, tool registry,
  trace, and script-runtime rejection.

Gaps:

- Task/run/pack status not durable.
- Permission broker only has an in-memory implementation.
- No manifest loader.
- Handler output is not fully validated against declared `output_events`.
- Event/schema idempotency, retention, and redaction are not fully represented in
  Dart.

First cut:

- Add `RuntimeStore` / `PackRegistry` ports so local DB can persist task/run and
  pack state without bloating the kernel.

### `packages/dart/memory`

Existing:

- Memory domain model, default auto-accept policy, review queue, accept/edit/
  reject/merge, tombstone delete, and exact-key conflict detection.

Gaps:

- Memory schema and Dart state names drift.
- No source-linked query/ranking/export/context packet API.
- Revision history is not a separate table.
- Conflict detection is exact-key only.

First cut:

- Align Memory schema, Dart model, and local DB states before extending query or
  Context Packet use.

### `packages/dart/model_providers`

Existing:

- Provider config, safe JSON, fake provider/http, OpenAI-compatible and
  Anthropic-compatible adapters, Kimi/MIMO presets, connection tests, and runtime
  `ModelClient` adapter.

Gaps:

- No provider schema.
- No per-pack/per-agent model profile routing.
- Streaming/embedding/vision/audio are capability enums but not implemented.
- Secure storage is not abstracted.

First cut:

- Define model profile to provider selection contract and connect it to Agent
  Pack `model_profile_ref`.

### `packs/official/default` and `packs/official/todo`

Existing:

- Official manifests exist and the lightweight validator enforces default/todo
  guardrails.

Gaps:

- Manifests are not yet loaded by mobile/runtime.
- No prompts/agents/fixtures/tests folder.
- Pack definitions are duplicated in mobile code.

First cut:

- Build manifest-to-native registry and tests that assert manifest and runtime
  definitions are aligned.

### `packages/schemas`

Existing:

- Event, Memory, Agent Pack manifest, Permission, and Trace JSON Schemas.

Gaps:

- No Task, Tool, UI Block, Sync, Context Packet, or provider schema.
- No generated Dart/TypeScript bindings.
- Event/Trace/Memory schema requirements drift from current Dart behavior.

First cut:

- Add schema fixtures and validation/codegen entrypoints, then add task/context
  packet schemas.

### `tools/pack_validator`

Existing:

- Node stdlib validator for parse shape, references, permission subset,
  dependency cycles, model profile refs, output events, retry bounds, script
  deferral, and default/todo guardrails.

Gaps:

- Not full JSON Schema validation.
- No manifest-to-runtime consistency test.
- Only official lightweight rules are covered.

First cut:

- Add official manifest fixture validation command and manifest/runtime
  consistency checks before full schema validation.
