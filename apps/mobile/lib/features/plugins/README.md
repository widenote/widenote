# Plugins Feature

## Purpose

Owns the Agent Pack and runtime control-entry tab.

## Ownership Boundary

This feature presents pack, Agent Platform queue/status, permission, model,
backup, and trace entry points. It routes pack, permission, backup, trace, and
model-provider rows to dedicated pages. Pack Library displays installed and
bundled marketplace metadata, including source, trust level, categories,
capabilities, and additive/replacement slot declarations. It can enable or
disable built-in official Packs for future local runtime registration, but does
not dynamically download remote Packs or grant high-risk permissions. Built-in
official pack metadata comes from the mobile embedded manifest bridge and is
checked against `packs/official/*` manifest JSON in focused tests. Agent
Platform status reads local trace events.

## Dependencies

- Flutter Material
- `go_router`
- `widenote_agent_runtime`

## Public Surface

- `application/AgentPlatformController`
- `application/official_pack_manifests.dart`
- `application/pack_catalog.dart`
- `presentation/AgentPlatformPanel`
- `presentation/PluginsPage`
- `presentation/PackLibraryPage`
- `presentation/PermissionGatePage`

## Generated Artifacts

None.
