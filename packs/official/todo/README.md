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

- Permission requests: `model.complete`, `todo.suggest`
- Subscription: `wn.capture.created`
- Native agent: `agent.todo_loop`
- Prompt ref: `todo.suggestion.v1`
- Retry policy: `max_attempts = 2`
- Output event: `wn.todo.suggested`

`agent.todo_loop` asks the configured model whether the capture is `action`,
`schedule`, or `quiet`. `wn.todo.suggested` is emitted only when the model
returns `action` or `schedule`. Its payload includes:

- `text`: user-facing suggestion title
- `suggestion_kind`: `action` or `schedule`
- `status_label`: lifecycle/status display label
- `suggestion_confidence`: model confidence label
- `suggestion_reason`: short machine-readable reason
- `scheduled_at_label`: optional local time cue for schedule candidates
- `source_event_id` and runtime-added source refs

Captures that are ordinary diary, state, observation, or product-note records
must not emit `wn.todo.suggested`; they remain available through the source
timeline and other derived surfaces. Core must not put a local keyword or
regular-expression classifier in front of this model-backed decision.

## Dependencies

May depend on public Agent Pack, Event, Permission, and Trace schemas.

## Generated Artifacts

No generated artifacts exist yet.

Generated pack indexes or manifest docs must point back to `manifest.json` when introduced.

## Related Context

- `docs/rfcs/agent-pack-schema.md`
- `packages/schemas/src/agent_pack/agent_pack_manifest.schema.json`
