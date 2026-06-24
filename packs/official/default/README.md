# Default Agent Pack

## Purpose

The default pack should support the first product loop:

```text
capture.created -> card extraction -> memory candidates -> lightweight insight
```

It should not enable todos, document generation, external export, or graphical agent flow by default.

## Ownership Boundary

Owns the default product capability bundle. It must stay conservative and store-safe.

## Public Surface

Current public surface:

| Surface | Source |
| --- | --- |
| Agent Pack manifest | `manifest.json` |

The manifest declares:

- Permission requests: `model.complete`, `card.write`, `memory.propose`, `insight.write`
- Subscription: `wn.capture.created`
- Native agent: `agent.capture_loop`
- Retry policy: `max_attempts = 2`
- Output events: `wn.card.created`, `wn.memory.proposed`, `wn.insight.created`

Future public surfaces include prompt definitions, richer permission requests, and UI/output declarations.

## Dependencies

May depend on public Agent Pack, Event, Memory, Permission, Tool, and UI Block schemas.

## Generated Artifacts

No generated artifacts exist yet.

Generated pack indexes or manifest docs must point back to `manifest.json` when introduced.

## Related Context

- `docs/product/positioning.md`
- `docs/architecture/runtime.md`
- `docs/rfcs/agent-pack-schema.md`
- `packages/schemas/src/agent_pack/agent_pack_manifest.schema.json`
