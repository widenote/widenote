# Packages

Shared package boundaries live here.

- `schemas`: shared contracts and generated types.
- `dart`: Dart packages used by the Flutter client.
- `ts`: TypeScript packages used by API, runner, and tooling.

## Ownership Boundary

Packages own reusable contracts and logic. Runnable entrypoints belong in `apps/`, and installable Agent Pack content belongs in `packs/`.

## Module Map

| Module | Context | Purpose |
| --- | --- | --- |
| Schemas | `schemas/README.md` | Shared runtime contracts and generated types |
| Dart | `dart/README.md` | Dart package area |
| TypeScript | `ts/README.md` | TypeScript package area |

## Generated Artifacts

Generated code should declare its source of truth, generator command, and target output in the package README that owns it.
