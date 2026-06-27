# Project Structure

WideNote starts as a product monorepo.

The goal is not to put everything into one package. The goal is to keep the product contracts close while they are still changing.

```text
apps/
  mobile/
  api/
  runner-ts/

packages/
  schemas/
  dart/
    core/
    local_db/
    agent_runtime/
    ui_blocks/
  ts/
    protocol/
    runner_core/
    agent_sdk/

packs/
  official/
    default/

docs/
infra/
tools/
```

## Boundaries

- `apps/mobile` hosts the Flutter app and local runtime.
- `apps/api` hosts optional cloud/self-hosted API features.
- `apps/runner-ts` hosts TypeScript runner execution.
- `packages/schemas` is the shared contract center.
- `packages/dart/core` must not depend on Flutter UI.
- `packages/dart/ui_blocks` may depend on Flutter rendering.
- `packages/ts/*` must not depend on mobile-private implementation details.
- `packs/*` may depend only on public schemas and SDKs.

## Module Documentation

Each durable module must include a `README.md` using the module README shape in `docs/templates/module-readme.md`.

At minimum, a module README should describe:

- Purpose
- Ownership boundary
- Public surface
- Dependencies
- Generated artifacts
- Related current contracts, ADRs, or RFCs

When a module changes shape, update the module README and the parent directory README in the same change.

## Evolution

Start with this monorepo. Split ecosystem repositories later when the contracts are stable:

- `widenote/agent-packs`
- `widenote/registry`
- `widenote/docs`
- `widenote/evals`
