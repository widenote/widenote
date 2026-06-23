# TypeScript Runner

## Purpose

Runner host for self-hosted or cloud Agent Pack execution.

Responsibilities:

- Execute authorized remote tasks
- Call model providers and external tools
- Emit output events
- Maintain task traces
- Respect privacy and permission scopes

## Ownership Boundary

The runner owns task execution outside the mobile app. It does not own WideNote's core runtime semantics; those are defined by schemas, Agent Pack contracts, permissions, memory, and event protocols.

## Public Surface

Future public surfaces may include runner registration, task execution APIs, trace emission, and tool execution boundaries.

## Dependencies

Allowed dependencies should flow through `packages/ts/runner_core`, `packages/ts/protocol`, `packages/ts/agent_sdk`, and `packages/schemas`.

## Generated Artifacts

Generated protocol bindings, runner manifests, or task API clients must document their source of truth and generation command here when introduced.

## Related Context

- `docs/architecture/runtime.md`
- `docs/decisions/0003-build-agent-runtime-kernel.md`
