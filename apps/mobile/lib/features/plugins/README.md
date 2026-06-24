# Plugins Feature

## Purpose

Owns the Agent Pack and runtime control-entry tab.

## Ownership Boundary

This feature presents pack, Agent Platform queue/status, permission, model, backup, and trace entry points.
It routes backup and model-provider rows to their dedicated settings pages, but
does not grant permissions. Agent Platform status uses a local preview
controller until persistent runtime task/run storage is wired in.

## Dependencies

- Flutter Material
- `go_router`
- `widenote_agent_runtime`

## Public Surface

- `application/AgentPlatformController`
- `presentation/AgentPlatformPanel`
- `presentation/PluginsPage`

## Generated Artifacts

None.
