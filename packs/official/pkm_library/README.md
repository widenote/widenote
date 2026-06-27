# PKM Personal Library Pack

## Purpose

The PKM Personal Library Pack projects captures into source-linked personal
knowledge base artifacts.

It is an example marketplace Pack, not a replacement for WideNote Memory. Raw
captures and accepted Memory stay source truth. PKM entries are derived outputs
that can be regenerated, disabled for future captures, or deleted without
deleting source records.

## Ownership Boundary

Owns PKM-style derived organization artifacts.

It must not:

- overwrite raw captures
- mutate accepted Memory
- write private mobile tables directly
- export user records off-device
- claim exclusive control over Memory policy or agent orchestration

## Public Surface

| Surface | Source |
| --- | --- |
| Agent Pack manifest | `manifest.json` |

The manifest declares:

- Permission requests: `model.complete`, `artifact.write`
- Subscription: `wn.capture.created`
- Native agent: `agent.pkm_profile_builder`
- Prompt reference: `pkm.profile_entry.v1`
- Additive slot: `knowledge.organization`
- Output event: `wn.artifact.created`

## Runtime Behavior

For each capture, the native mobile handler asks the configured model for a
compact PKM profile entry. It writes a `pkm_profile_entry` derived artifact with
source refs back to the capture and runtime event.

If the model output is incomplete, the handler still keeps the artifact
source-linked and records conservative confidence/sensitivity metadata.

## Generated Artifacts

No generated artifacts exist yet.

Generated pack indexes or docs must point back to `manifest.json` when
introduced.

## Related Context

- `docs/rfcs/agent-pack-schema.md`
- `docs/rfcs/agent-runtime-capability-boundaries.md`
- `docs/research/2026-06-28-marketplace-pkm-plan.md`
- `packages/schemas/src/agent_pack/agent_pack_manifest.schema.json`
