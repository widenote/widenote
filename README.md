# WideNote / 广记

WideNote / 广记 is a local-first personal record, memory, and agent runtime.

The first product loop is intentionally narrow:

```text
quick capture -> timeline / cards -> memory -> insight
```

The long-term system is broader: user records become durable personal context, and Agent Packs can turn that context into memories, insights, actions, exports, and tool integrations.

## Current Status

This repository is at the foundation stage. The project brief has been preserved in [widenote_project_brief.md](./widenote_project_brief.md), and the first implementation work should start from the docs and boundaries in this repository rather than from a generated app scaffold.

## Repository Map

```text
apps/                  Runnable apps and services.
  mobile/              Flutter mobile client and local runtime host.
  api/                 Optional backend API for sync, backup, registry, and cloud features.
  runner-ts/           TypeScript runner for self-hosted or cloud agent execution.

packages/              Shared packages and runtime boundaries.
  schemas/             Event, Memory, Agent Pack, Permission, Task, and Sync schemas.
  dart/                Dart packages used by the Flutter client.
  ts/                  TypeScript packages used by API, runner, and tooling.

packs/                 Agent Pack definitions.
  official/default/    Default capture -> card -> memory -> insight pack.

docs/                  Product, architecture, decisions, RFCs, and agent context.
infra/                 Deployment and self-hosting assets.
tools/                 Repository automation and generation scripts.
```

## Read First

- [Project positioning](./docs/product/positioning.md)
- [Architecture overview](./docs/architecture/overview.md)
- [Project structure](./docs/architecture/project-structure.md)
- [Technology stack](./docs/architecture/technology-stack.md)
- [Decision index](./docs/decisions/index.md)
- [Agent context entrypoint](./docs/agent-context/START_HERE.md)

## Initial Decisions

The current foundation is:

- Use a product monorepo for the client, backend, runner, schemas, docs, and default Agent Pack.
- Use Flutter + Dart for the mobile-first client.
- Use SQLite + Drift for the local-first data layer.
- Keep backend services optional and enhancing, not required for core use.
- Build a lightweight WideNote Agent Runtime Kernel inside the product.
- Treat external agent/workflow frameworks as runner adapters or integration targets.
- Maintain decision history with ADRs and RFCs.

## License

The intended license is AGPLv3 with a future commercial dual-license path. A full license file should be added before public release.
