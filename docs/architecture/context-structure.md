# Context Structure

WideNote uses progressive disclosure for project context.

The goal is not to make every AI agent read everything. The goal is to make the repository navigable through stable maps, so humans and agents can load only the context required for the task.

## Layers

```text
root context
  README.md
  AGENTS.md
  docs/agent-context/START_HERE.md
  docs/agent-context/project-map.md

current contract context
  docs/architecture/current-contracts.md

area context
  apps/README.md
  packages/README.md
  packs/README.md
  docs/README.md

module context
  apps/mobile/README.md
  packages/dart/agent_runtime/README.md
  packages/schemas/README.md

file context
  source file name
  imports
  narrow comments only where the boundary is not obvious
```

## Rules

- Root documents explain the whole project at low resolution.
- Current architecture contracts state the target state to maintain during
  normal development. ADRs and RFCs remain the historical decision log and
  rationale source.
- Area READMEs explain how a directory is divided.
- Module READMEs explain ownership, public surface, dependencies, generated artifacts, and related decisions.
- Files should be understandable from their module context and imports. Add file headers only for complex boundary files.
- The project map must point to the canonical context entrypoints, not duplicate all details.

## Generated Artifacts

Generated code and generated documentation must declare:

- Source of truth
- Generator or command
- Output path
- Whether humans may edit the output

For example, generated Dart and TypeScript types should point back to `packages/schemas`.

## Complexity Control

When adding a new directory, package, app, runner, schema family, Agent Pack, or generated output:

1. Add or update the nearest `README.md`.
2. Update `docs/agent-context/project-map.md`.
3. Link related ADRs or RFCs.
4. Update `docs/architecture/current-contracts.md` if the target-state contract
   changes or the new module implements an existing contract.
5. Document generated artifacts and source-of-truth relationships.
