# Usage Statistics Dashboard Pack

## Purpose

Official read-only Agent Pack that exposes a host-rendered Settings dashboard for
local usage statistics.

The dashboard summarizes recent local evidence from captures, Memory records,
runtime traces, tool traces, and context packet cache rows. It does not execute
an agent, call a model, write Memory, or mutate source records.

## Ownership Boundary

- Owns declarative Pack metadata for the usage statistics Settings entry.
- Declares a host-rendered `settings.pack_detail` panel contribution.
- Does not read mobile-private tables directly. The mobile host owns the actual
  aggregation and rendering implementation.
- Does not create subscriptions, tools, model profiles, output events, or
  storage beyond existing local traces and object tables.

## Public Surface

- `manifest.json`
- UI contribution: `settings.usage_stats.dashboard`

## Generated Artifacts

None.

## Related Context

- `docs/architecture/current-contracts.md`
- `docs/rfcs/agent-pack-schema.md`
- `apps/mobile/lib/features/usage_stats/README.md`
