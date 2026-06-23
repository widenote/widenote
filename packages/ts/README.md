# TypeScript Packages

TypeScript packages used by API, runner, and tooling.

## Ownership Boundary

TypeScript packages own reusable server, runner, and tooling logic. Runnable services belong in `apps/`.

## Module Map

| Module | Context | Purpose |
| --- | --- | --- |
| Protocol | `protocol/README.md` | TypeScript protocol helpers |
| Runner Core | `runner_core/README.md` | Runner execution primitives |
| Agent SDK | `agent_sdk/README.md` | Runner-side Agent Pack SDK |
