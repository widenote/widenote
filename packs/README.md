# Agent Packs

## Purpose

Agent Packs are installable bundles of capability.

They may contain:

- Manifest
- Event subscriptions
- Prompts
- Agent definitions
- Tool declarations
- Permission requests
- UI blocks
- Output adapters
- Defaults and examples

## Ownership Boundary

Packs own declarative capability bundles. They must not depend on private app tables or private runner implementation details.

## Module Map

| Module | Context | Purpose |
| --- | --- | --- |
| Official default | `official/default/README.md` | Default capture to insight loop |
| Official todo | `official/todo/README.md` | Source-linked todo suggestion loop |
| Official PKM library | `official/pkm_library/README.md` | Source-linked derived PKM profile artifacts |
| Marketplace index | `marketplace/index.json` | GitHub-first Agent Pack catalog index |

## Generated Artifacts

Generated manifests, schema docs, or pack indexes must document their source of truth and generation command when introduced.

## Developer Flow

1. Start from a Pack manifest and public event/permission contracts.
2. Add `marketplace` metadata so the GitHub-first catalog can display source,
   trust, install mode, categories, capabilities, and status.
3. Prefer `additive_slots` for extension behavior. `replacement_slots` are
   reserved for official/local-dev experiments until permission, rollback, and
   trace review gates are accepted.
4. Emit public runtime events and preserve source refs. Packs must not mutate
   raw captures, accepted Memory, or mobile-private tables directly.
5. Add or update the Pack README, marketplace index entry, validator tests, and
   mobile Pack Library/runtime tests when the Pack is bundled.

## Validation

Validate phase-one official pack manifests with:

```sh
node tools/pack_validator/validate.mjs packs/official/default/manifest.json packs/official/todo/manifest.json packs/official/pkm_library/manifest.json packs/marketplace/index.json
```

Validator self-tests:

```sh
node tools/pack_validator/validate_test.mjs
```

This is a lightweight validator, not a complete JSON Schema validator.
