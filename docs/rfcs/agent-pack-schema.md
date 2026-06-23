# RFC: Agent Pack Schema

Status: Draft  
Date: 2026-06-23

## Context

WideNote is event-driven. Agent Packs subscribe to events, request permissions, call tools, and emit new events. Packs are the extension boundary for default capture, todo extraction, companion behavior, plugin integrations, and future community automation.

## Goals

- Keep the local runtime generic.
- Make permissions explicit and reviewable.
- Make pack behavior inspectable through traces.
- Allow clean-room feature parity without copying external implementation.
- Support store-safe packs first, with script packs deferred.

## Manifest Shape

Phase-one code may register built-in packs imperatively in Dart while the schema stabilizes. That is a bootstrap path only. Every imperative built-in pack must map cleanly to this manifest shape before it becomes user-installable or store-distributed.

```yaml
id: pack.default
name: Default Capture Loop
version: 0.1.0
schema_version: 1
publisher: widenote
edition: official
permissions:
  - memory.propose
  - card.write
  - insight.write
  - todo.suggest
subscriptions:
  - id: sub.capture
    event_types:
      - wn.capture.created
    agent_id: agent.capture
agents:
  - id: agent.capture
    runtime: native
    prompt_ref: prompts/capture.md
    output_events:
      - wn.memory.proposed
      - wn.card.created
      - wn.insight.created
      - wn.todo.suggested
```

## Pack Fields

| Field | Required | Notes |
| --- | --- | --- |
| `id` | Yes | Stable namespaced identifier |
| `name` | Yes | Human-readable display name |
| `version` | Yes | Semver-compatible |
| `schema_version` | Yes | Manifest schema version |
| `publisher` | Yes | Official, user, or community publisher |
| `edition` | Yes | `official`, `store`, `community`, or `local_dev` |
| `permissions[]` | Yes | Pack-level requested permissions |
| `subscriptions[]` | Yes | Event triggers |
| `agents[]` | Yes | Agent handlers and prompts |
| `tools[]` | No | Tool declarations used by agents |
| `ui_blocks[]` | No | Structured UI blocks exposed by the pack |

## Subscription Contract

Subscriptions are declarative:

- `event_types[]` match append-only runtime event names.
- `agent_id` must point to an agent declared in the same pack.
- One event may trigger multiple packs.
- Runtime traces must include pack id, agent id, task id, and run id.

## Permission Model

Permissions are pack-scoped and tool-scoped.

Examples:

- `memory.propose`
- `card.write`
- `insight.write`
- `todo.suggest`
- `file.read.user_selected`
- `network.call.declared_host`
- `model.complete`

High-risk permissions require explicit user grant and should not ship as default store-safe behavior:

- broad filesystem read
- shell/script execution
- background network to arbitrary hosts
- continuous location/audio capture
- credential access

## Runtime Output

Agents emit events, not direct UI mutations.

Minimum event envelope fields:

- `id`
- `type`
- `schema_version`
- `actor`
- `pack_id`
- `agent_id`
- `subject_ref`
- `payload`
- `privacy`
- `causation_id`
- `correlation_id`
- `device_id`
- `created_at`

## Prompt and Context Loading

Pack prompts should follow progressive context disclosure:

- Prompt files declare required local docs and schemas.
- Agents receive event payload and source refs first.
- Additional context is loaded only when needed.
- Generated outputs must preserve source refs when creating Memory.

## Phase-One Official Packs

| Pack | Default | Purpose |
| --- | --- | --- |
| `pack.default` | Yes | Capture to Memory/card/insight/todo suggestions |
| `pack.todo` | Yes | Source-linked todos and lightweight action review |
| `pack.conversation` | Yes | Chat over local Memory and records |
| `pack.backup_export` | Yes | Local export/import and backup |
| `pack.companion` | Optional mode | Companion behavior inside Conversations |

## Migration Plan

1. Implement built-in official packs as native Dart handlers to prove the event model and tests.
2. Keep each native pack's id, permissions, subscriptions, agents, and output events aligned with this RFC.
3. Add a manifest validator under `tools/pack_validator`.
4. Generate or load a manifest for every built-in pack.
5. Move user-installable packs to manifest-first loading.
6. Defer scripted handlers until sandbox and store/community edition rules are accepted.

## Deferred

- Script pack runtime.
- Community pack store.
- Remote runner execution.
- Dynamic UI block scripting.
- Cross-device sync of pack state.

## Open Questions

- Whether Todo remains part of `pack.default` or becomes a separate always-on official pack.
- Whether companion mode should share the conversation pack or ship as a separate pack.
- How strict pack schema validation should be before store distribution exists.
