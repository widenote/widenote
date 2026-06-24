# Schemas

## Purpose

Shared schema package for cross-runtime contracts.

Initial schema families:

- Event
- Memory
- Agent Pack manifest
- Permission
- Task
- Tool
- UI Block
- Sync object
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
| Permission declaration | `src/permission/permission.schema.json` |
| Trace event | `src/trace/trace.schema.json` |

Future public surfaces include generated Dart types, generated TypeScript types, validation fixtures, and compatibility metadata.

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

Current lightweight Agent Pack manifest validation checks parseability, basic shape, cross-references, and WideNote phase-one guardrails without adding repository dependencies:

```sh
node tools/pack_validator/validate.mjs packs/official/default/manifest.json packs/official/todo/manifest.json
```

The Agent Pack manifest currently includes subscription dependencies through
`depends_on[]` and deterministic retry bounds through
`agents[].retry_policy.max_attempts`. Script runtime and script side effects are
described only as deferred contract values; phase-one validation rejects them
until a sandbox RFC is accepted.

Validator self-tests:

```sh
node tools/pack_validator/validate_test.mjs
```

This is a lightweight validator, not a complete JSON Schema validator. Full JSON Schema validation should be introduced under repo tooling when schema codegen or installable pack loading lands.

## Related Context

- `docs/architecture/context-structure.md`
- `docs/architecture/runtime.md`
- `docs/decisions/0004-use-progressive-context-structure.md`
- `docs/rfcs/agent-pack-schema.md`
