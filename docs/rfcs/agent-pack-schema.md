# RFC: Agent Pack Schema

Status: Accepted phase-one contract; scripted/community runtime deferred
Date: 2026-06-23

## Context

WideNote is event-driven. Agent Packs subscribe to events, request permissions, call tools, and emit new events. Packs are the extension boundary for default capture, todo extraction, companion behavior, plugin integrations, and future community automation.

## Goals

- Keep the local runtime generic.
- Make permissions explicit and reviewable.
- Make pack behavior inspectable through traces.
- Allow clean-room feature parity without copying external implementation.
- Support store-safe packs first, with script packs deferred.

## Manifest Shape

Phase-one code may register built-in packs imperatively in Dart while the schema stabilizes. That is a bootstrap path only. Every imperative built-in pack must map cleanly to this manifest shape before it becomes user-installable or store-distributed.

```yaml
id: pack.default
name: Default Capture Loop
version: 0.1.0
schema_version: 1
publisher: widenote
edition: official
marketplace:
  source: bundled
  trust_level: official
  install_mode: bundled
  repository_url: https://github.com/widenote/widenote
  docs_path: packs/official/default/README.md
  categories:
    - capture
    - memory
  capabilities:
    - memory.propose
  status: available
additive_slots: []
replacement_slots: []
permissions:
  - model.complete
  - memory.propose
  - card.write
  - insight.write
subscriptions:
  - id: sub.capture_created
    event_types:
      - wn.capture.created
    agent_id: agent.capture_loop
    depends_on: []
agents:
  - id: agent.capture_loop
    runtime: native
    prompt_ref: null
    concurrency_key: null
    retry_policy:
      max_attempts: 2
    output_events:
      - wn.memory.proposed
      - wn.card.created
      - wn.insight.created
```

## Pack Fields

| Field | Required | Notes |
| --- | --- | --- |
| `id` | Yes | Stable namespaced identifier |
| `name` | Yes | Human-readable display name |
| `version` | Yes | Semver-compatible |
| `schema_version` | Yes | Manifest schema version |
| `publisher` | Yes | Official, user, or community publisher |
| `edition` | Yes | `official`, `store`, `community`, or `local_dev` |
| `marketplace` | No | Display and catalog metadata for GitHub-first marketplace entries |
| `additive_slots[]` | No | Declares extension points that add capability without replacing core flow |
| `replacement_slots[]` | No | Declares replacement points; phase-one validator allows only `official` and `local_dev` packs |
| `permissions[]` | Yes | Pack-level requested permissions |
| `subscriptions[]` | Yes | Event triggers |
| `agents[]` | Yes | Agent handlers and prompts |
| `tools[]` | No | Tool declarations used by agents |
| `ui_blocks[]` | No | Store-safe structured UI blocks exposed by the pack. Phase-one block kinds are `claim_list`, `metric_row`, `source_refs`, and `note`. |

## Schema Source Paths

Phase-one source schemas live under `packages/schemas/src`:

| Contract | Source |
| --- | --- |
| Event envelope | `packages/schemas/src/event/event.schema.json` |
| Memory candidate/item | `packages/schemas/src/memory/memory.schema.json` |
| Agent Pack manifest | `packages/schemas/src/agent_pack/agent_pack_manifest.schema.json` |
| Agent Pack marketplace index | `packages/schemas/src/agent_pack/agent_pack_marketplace.schema.json` |
| Permission declaration | `packages/schemas/src/permission/permission.schema.json` |
| Trace event | `packages/schemas/src/trace/trace.schema.json` |

Official phase-one pack manifests live under `packs/official/*/manifest.json`.
The bundled GitHub-first catalog lives at `packs/marketplace/index.json`.

## Manifest Validation

Phase-one official manifests are checked with the lightweight validator:

```sh
node tools/pack_validator/validate.mjs packs/official/default/manifest.json packs/official/todo/manifest.json packs/official/pkm_library/manifest.json packs/official/transcript_correction/manifest.json packs/marketplace/index.json
```

This is a lightweight validator, not a complete JSON Schema validator. It currently checks JSON parse, required manifest shape, intra-manifest references, subscription dependency references and cycles, agent permission subsets, non-empty output events, retry policy bounds, script-execution rejection, and the `pack.default` / `pack.todo` phase-one guardrails. `depends_on[]` may reference a same-pack subscription id such as `sub.prepare` or a fully-qualified external subscription such as `pack.default::sub.capture_created`; only same-pack dependencies participate in local cycle detection.

Run validator self-tests after schema or guardrail changes:

```sh
node tools/pack_validator/validate_test.mjs
```

## Marketplace Contract

Phase one uses a GitHub-first marketplace rather than a hosted registry:

- `packs/marketplace/index.json` is the bundled catalog index.
- Each catalog entry points to a manifest path and repeats display metadata
  used for cheap listing and drift checks.
- Each manifest may carry a `marketplace` block with source, trust level,
  install mode, docs path, categories, capabilities, and status.
- The mobile Pack Library currently displays installed/bundled Pack metadata
  and enable/disable state. Remote download, update channels, signatures, and
  hosted registry search are deferred.
- Index validation checks entry ids, duplicate ids, manifest path existence,
  manifest validity, and metadata alignment for name, version, source, trust
  level, categories, capabilities, and status.

Supported phase-one marketplace enum values:

| Field | Values |
| --- | --- |
| `marketplace.source` | `bundled`, `github`, `local`, `remote_registry` |
| `marketplace.trust_level` | `official`, `verified`, `community`, `local_dev` |
| `marketplace.install_mode` | `bundled`, `manual_git`, `remote_registry`, `local_dev` |
| `marketplace.status` | `available`, `experimental`, `deprecated`, `disabled` |

## Slot Contract

Slots document where Packs extend or replace behavior:

- Additive slots add output or capability while preserving the main flow. The
  PKM Pack uses `knowledge.organization` to create derived PKM artifacts.
- Replacement slots replace a core mechanism such as Memory write policy,
  retrieval, model routing, or orchestration. They are reserved for `official`
  and `local_dev` packs in phase one.
- Replacement slots must not ship as community/store behavior until the project
  accepts permission design, rollback behavior, trace review, and conflict
  policy.
- Slots are declarative in the manifest first. Runtime arbitration and UI
  conflict resolution are future work.

## Subscription Contract

Subscriptions are declarative:

- `event_types[]` match append-only runtime event names.
- `agent_id` must point to an agent declared in the same pack.
- `depends_on[]` points to prerequisite subscription ids in the same pack or
  fully-qualified external subscription ids such as
  `pack.default::sub.capture_created`.
- One event may trigger multiple packs.
- Runtime traces must include pack id, agent id, task id, and run id.

## Queue and Retry Contract

Phase-one local execution is task-queue based:

- Matching subscriptions create queued tasks.
- Tasks run only after every `depends_on[]` prerequisite task succeeds.
- Failed, denied, canceled, or missing prerequisite tasks block dependent tasks.
- `retry_policy.max_attempts` controls deterministic fake/native executor
  retries. Omitting the policy defaults to two attempts; explicit pack values
  may choose 1 through 5 attempts.
- Stale running runs or tasks recovered after an expired lease consume the same
  retry budget as handler failures, so native-crash-like loops eventually
  become failed tasks and block downstream work.
- Agent `concurrency_key` serializes tasks that share a constrained local
  resource while still allowing unrelated captures to use global queue slots.
- Permission denied, unsupported script runtime, and user cancellation are terminal states and are not auto-retried.
- Pack status surfaces derive from queued task/run state, not from private app tables.

## Permission Model

Permissions are pack-scoped and tool-scoped.

Examples:

- `memory.propose`
- `card.write`
- `insight.write`
- `todo.suggest`
- `artifact.write`
- `file.read.user_selected`
- `network.call.declared_host`
- `model.complete`

High-risk permissions require explicit user grant and should not ship as default store-safe behavior:

- broad filesystem read
- shell/script execution
- background network to arbitrary hosts
- continuous location/audio capture
- credential access

## Runtime Output

Agents emit events, not direct UI mutations.

Minimum event envelope fields:

- `id`
- `type`
- `schema_version`
- `actor`
- `pack_id`
- `agent_id`
- `subject_ref`
- `payload`
- `privacy`
- `causation_id`
- `correlation_id`
- `device_id`
- `created_at`

## Prompt and Context Loading

Pack prompts should follow progressive context disclosure:

- Prompt files declare required local docs and schemas.
- Agents receive event payload and source refs first.
- Additional context is loaded only when needed.
- Generated outputs must preserve source refs when creating Memory.

## Phase-One Official Packs

| Pack | Default | Purpose |
| --- | --- | --- |
| `pack.default` | Yes | Capture to Memory/card/insight |
| `pack.todo` | Yes | Source-linked todos and lightweight action review |
| `pack.pkm_library` | Yes | Official PKM example that writes source-linked derived artifacts through `knowledge.organization` |
| `pack.transcript_correction` | Yes | Source-linked transcript correction revisions through `transcript.correction` |

## Pack Developer Flow

1. Create a Pack folder under `packs/official/<id>` for official examples or a
   separate GitHub repository for community experiments.
2. Add `manifest.json` with public permissions, subscriptions, agents,
   `marketplace`, and slot declarations.
3. Use additive slots for extension behavior. Do not declare replacement slots
   for community/store packs.
4. Emit public runtime events only. Derived output should use source refs and
   must not mutate raw capture or accepted Memory directly.
5. If the Pack should appear in the bundled catalog, add it to
   `packs/marketplace/index.json`.
6. If it is a native official Pack, embed the manifest in
   `apps/mobile/lib/features/plugins/application/official_pack_manifests.dart`,
   register the native handler in the capture/runtime host, and add Pack
   Library/permission/runtime tests.
7. Update `packs/README.md`, affected module READMEs, and
   `docs/agent-context/project-map.md`.
8. Run schema fixtures, pack validator tests, targeted runtime tests, and
   mobile widget tests for user-visible Pack Library changes.

## Migration Plan

1. Implement built-in official packs as native Dart handlers to prove the event model and tests.
2. Keep each native pack's id, permissions, subscriptions, agents, and output events aligned with this RFC.
3. Maintain a lightweight manifest validator under `tools/pack_validator`.
4. Generate or load a manifest for every built-in pack.
5. Move user-installable packs to manifest-first loading.
6. Defer scripted handlers until sandbox and store/community edition rules are accepted.

## Deferred

- Script pack runtime. Manifest fields may describe it, but phase-one validators and the local runtime reject execution until a sandbox RFC is accepted.
- Community pack store.
- Hosted marketplace registry and remote install/update.
- Remote runner execution.
- Dynamic UI block scripting.
- Cross-device sync of pack state.

## Resolved Phase-One Decisions

- `pack.todo` is a separate always-on official pack, not part of `pack.default`.

## Open Questions

- Whether companion mode should share the conversation pack or ship as a separate pack.
- How strict pack schema validation should be before store distribution exists.
