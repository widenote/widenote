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
- Non-empty agent output events
- Agent retry policy bounds
- Phase-one script runtime and script side-effect rejection
- `pack.default` and `pack.todo` phase-one guardrails

Validator self-tests:

```sh
node tools/pack_validator/validate_test.mjs
```

## Generated Artifacts

None.
