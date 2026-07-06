# Plugins Feature

## Purpose

Owns the Agent Pack and runtime control-entry tab.

## Ownership Boundary

This feature presents pack and Agent Platform queue/status entry points. It
owns Pack Library and Pack detail navigation under `/plugins/packs`.
Permissions, model providers, backup/restore, and traces are Settings-owned
pages; Plugins may show visual shortcuts to them, but those shortcuts keep the
durable `/settings/...` routes instead of declaring duplicate plugin-owned
pages. The Permission Gate shortcut uses `/plugins` as its source parent so Back
returns to the Plugins tab; Settings-owned entries and direct links to
`/settings/permissions` still return through Settings. Pack Library displays
installed and bundled marketplace metadata, including source, trust level,
categories,
capabilities, additive/replacement slot declarations, and host-rendered UI
contributions. It can enable or disable built-in official Packs for future local
runtime registration, but does not dynamically download remote Packs or grant
high-risk permissions. Built-in official pack metadata comes from the mobile
embedded manifest bridge and is checked against `packs/official/*` manifest JSON
in focused tests. Agent Platform status reads local trace events.

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
