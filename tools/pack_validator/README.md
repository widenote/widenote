# Pack Validator

## Purpose

Lightweight Agent Pack manifest validation for phase-one official packs.

## Ownership Boundary

This tool checks manifest parseability, basic cross-reference integrity, and current WideNote phase-one guardrails. It is not the source of truth for the full Agent Pack JSON Schema.

## Dependencies

Uses only the Node.js standard library. It must not add repository package dependencies.

## Public Surface

Run the validator with one or more manifest paths:

```sh
node tools/pack_validator/validate.mjs packs/official/default/manifest.json packs/official/todo/manifest.json
```

Current checks include:

- JSON parse
- Required manifest shape
- Unique agent ids
- Unique subscription ids
- Subscription agent references
- Subscription dependency references and dependency cycles
- Agent permission subset of pack permissions
- Model profile references
- Model profile routing field shape
- Non-empty agent output events
- Agent retry policy bounds
- Tool permission subset of pack permissions
- Agent tool references
- Run mode values and read-only/confirm/auto tool boundaries
- Tool capability metadata: access, risk, locality, approval requirement,
  execution mode, and required permission consistency
- Fail-closed handling for HTTP, MCP, web, file, network, shell, runner,
  webhook, and other deferred-only live capabilities
- Phase-one script runtime and script side-effect rejection
- `pack.default` and `pack.todo` phase-one guardrails

Validator self-tests:

```sh
node tools/pack_validator/validate_test.mjs
```

Self-tests also validate the current official default and todo manifests.

## Generated Artifacts

None.
