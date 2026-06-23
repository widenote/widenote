# Apps

Runnable applications and services live here.

- `mobile`: Flutter app and local runtime host.
- `api`: optional backend API.
- `runner-ts`: TypeScript runner for self-hosted or cloud execution.

## Ownership Boundary

Apps own executable entrypoints and deployment/runtime wiring. Shared contracts and reusable logic belong in `packages/`.

## Module Map

| Module | Context | Purpose |
| --- | --- | --- |
| Mobile | `mobile/README.md` | Flutter client and local runtime host |
| API | `api/README.md` | Optional backend API |
| Runner TS | `runner-ts/README.md` | TypeScript runner |

## Generated Artifacts

Generated app artifacts must document their source of truth and generation command in the module README that owns them.
