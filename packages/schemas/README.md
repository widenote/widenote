# Schemas

## Purpose

Shared schema package for cross-runtime contracts.

Initial schema families:

- Event
- Memory
- Agent Pack manifest
- Permission
- Task
- Runtime task/run
- Context Packet
- Provider/model metadata
- Backup and Owner Export manifest
- Trace

Generated Dart and TypeScript types should come from this package.

## Ownership Boundary

This package owns public runtime contracts. It should not own app-specific persistence tables, UI rendering details, or runner implementation logic.

## Public Surface

Current source schemas:

| Contract | Source |
| --- | --- |
| Event envelope | `src/event/event.schema.json` |
| Memory candidate/item | `src/memory/memory.schema.json` |
| Agent Pack manifest | `src/agent_pack/agent_pack_manifest.schema.json` |
| Agent Pack marketplace index | `src/agent_pack/agent_pack_marketplace.schema.json` |
| Permission declaration | `src/permission/permission.schema.json` |
| Trace event | `src/trace/trace.schema.json` |
| Runtime task/run | `src/runtime/runtime_task_run.schema.json` |
| Runtime approval request/decision | `src/runtime/approval.schema.json` |
| Context Packet | `src/context_packet/context_packet.schema.json` |
| Provider metadata and model routing | `src/model_provider/model_provider.schema.json` |
| Backup and Owner Export manifest | `src/backup_export/backup_export_manifest.schema.json` |

Synthetic fixtures live under `fixtures/valid/` and are indexed by `fixtures/manifest.json`.

Future public surfaces include generated Dart types, generated TypeScript types, and compatibility metadata.

## Dependencies

Schemas should remain implementation-light. Runtime packages may depend on schemas; schemas should not depend on runtime packages.

## Generated Artifacts

No generated artifacts exist yet.

Generated outputs must point back to schema sources in this package. Humans should edit schema sources, not generated bindings.

When generation is introduced, document:

- Source schema path
- Generator command
- Dart output path
- TypeScript output path
- Validation command

## Validation

Schema fixture smoke validation uses a dependency-free Node runner that covers
the JSON Schema subset used by the current contract files:

```sh
node packages/schemas/validate_fixtures.mjs
```

Current lightweight Agent Pack manifest validation checks parseability, basic shape, cross-references, and WideNote phase-one guardrails without adding repository dependencies:

```sh
node tools/pack_validator/validate.mjs packs/official/default/manifest.json packs/official/todo/manifest.json
```

The runtime task/run contract uses public JSON run modes
`read_only`, `confirm`, and `auto`. Dart bindings may map these to native enum
names such as `RunMode.readOnly`, but schema fixtures keep the wire contract in
snake case.

The Agent Pack manifest currently includes subscription dependencies through
`depends_on[]` and deterministic retry bounds through
`agents[].retry_policy.max_attempts`. It also exposes model profile routing
fields such as `routing_policy`, `provider_ref`, `model_ref`, and
`required_capabilities[]`. Tool declarations include capability metadata:
`access`, `risk`, `locality`, `approval_requirement`, `execution`, and required
permission ids. HTTP, MCP, web, file, network, shell, runner, webhook, and
script-like live capabilities are L1/L3 contract declarations only; current
validation allows them only as fake, deferred, or disabled. Script runtime and
script side effects are described only as deferred contract values; phase-one
validation rejects them until a sandbox RFC is accepted.

Agent Pack `ui_blocks[]` is currently a store-safe whitelist for structured
insight rendering: `claim_list`, `metric_row`, `source_refs`, and `note`.
Unknown block kinds are rejected by both the schema and the lightweight pack
validator.

Approval request and decision fixtures intentionally store action summaries,
reasons, expiry, pack/agent/task/run/tool/source refs, and
`redacted_input_keys` only. Do not add raw tool input, credentials, provider
keys, or private records to approval or trace fixtures.

Agent Pack `model_profiles[]` may omit routing fields while packs are still
declarative. A materialized provider routing object should apply conservative
defaults: `routing_policy: app_default`, empty `required_capabilities[]`, and
`allow_fallback: false` unless the pack or user settings say otherwise.

Provider metadata currently accepts canonical snake_case values and the current
Dart camelCase wire names for provider kinds and capabilities. Treat camelCase
entries as compatibility aliases until generated bindings or a migration close
the drift.

Validator self-tests:

```sh
node tools/pack_validator/validate_test.mjs
```

This is a lightweight validator, not a complete JSON Schema validator. Full JSON Schema validation should be introduced under repo tooling when schema codegen or installable pack loading lands.

The Agent Pack marketplace index schema defines the GitHub-first catalog shape
for `packs/marketplace/index.json`. The same lightweight pack validator checks
manifest paths, duplicate ids, edition/trust/status values, and the L1-L3
guardrails that keep community entries from declaring live script, remote,
HTTP, MCP, webhook, runner, or reserved replacement behavior before later RFCs
accept those execution paths.

## Related Context

- `docs/architecture/context-structure.md`
- `docs/architecture/runtime.md`
- `docs/decisions/0004-use-progressive-context-structure.md`
- `docs/rfcs/agent-pack-schema.md`
