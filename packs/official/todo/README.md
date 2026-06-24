# Todo Agent Pack

## Purpose

The todo pack turns source records into lightweight, source-linked action items.

It is separate from the default capture pack so capture cards, Memory, insights,
and todos can evolve independently while still running by default in phase one.

## Ownership Boundary

Owns todo extraction and todo suggestion events. It must not own calendar sync,
notification delivery, task collaboration, or the persisted todo table.

## Public Surface

Current public surface:

| Surface | Source |
| --- | --- |
| Agent Pack manifest | `manifest.json` |

The manifest declares:

- Permission requests: `todo.suggest`
- Subscription: `wn.capture.created`
- Native agent: `agent.todo_loop`
- Retry policy: `max_attempts = 2`
- Output event: `wn.todo.suggested`

## Dependencies

May depend on public Agent Pack, Event, Permission, and Trace schemas.

## Generated Artifacts

No generated artifacts exist yet.

Generated pack indexes or manifest docs must point back to `manifest.json` when introduced.

## Related Context

- `docs/rfcs/agent-pack-schema.md`
- `packages/schemas/src/agent_pack/agent_pack_manifest.schema.json`
