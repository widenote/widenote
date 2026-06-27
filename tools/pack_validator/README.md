# Pack Validator

## Purpose

Lightweight Agent Pack manifest and marketplace index validation for phase-one
official packs.

## Ownership Boundary

This tool checks manifest parseability, basic cross-reference integrity, and current WideNote phase-one guardrails. It is not the source of truth for the full Agent Pack JSON Schema.

## Dependencies

Uses only the Node.js standard library. It must not add repository package dependencies.

## Public Surface

Run the validator with one or more manifest or marketplace index paths:

```sh
node tools/pack_validator/validate.mjs packs/official/default/manifest.json packs/official/todo/manifest.json packs/official/pkm_library/manifest.json packs/marketplace/index.json
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
- Marketplace metadata values and tag shape
- Additive and replacement slot declaration shape
- Reserved replacement slots limited to official or local-dev packs
- Marketplace index parseability, duplicate pack ids, manifest path existence,
  and index-to-manifest metadata alignment
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

Self-tests also validate the current official default, todo, PKM manifests, and
the GitHub-first marketplace index.

## Generated Artifacts

None.
