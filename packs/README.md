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

## Generated Artifacts

Generated manifests, schema docs, or pack indexes must document their source of truth and generation command when introduced.
