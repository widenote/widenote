# WideNote / 广记

WideNote / 广记 is a local-first personal record, memory, and agent runtime.

The first product loop is intentionally narrow:

```text
quick capture -> timeline / cards -> memory -> insight
```

The long-term system is broader: user records become durable personal context, and Agent Packs can turn that context into memories, insights, actions, exports, and tool integrations.

## Current Status

This repository is in the phase-one local-first usable-state integration stage.
The current W7 state has a Flutter mobile app, hand-written SQLite local truth,
local runtime outputs, runtime-enforced built-in Pack permissions, Settings /
Privacy, compressed `.widenote` safe backup / restore, real media permission
handling, Daily Recap, timeline / search / detail surfaces, and
cross-platform QA evidence. Safe backup restore rejects secret-bearing
`encrypted_full` imports until a real encryption and credential-restore
boundary exists. Use
[Current Architecture Contracts](./docs/architecture/current-contracts.md)
for the target-state contracts agents should maintain by default, use
[W7 Current Integration State](./docs/research/2026-06-26-w7-current-integration-state.md)
for the current implementation boundary, and keep the original product brief in
[widenote_project_brief.md](./widenote_project_brief.md) for product intent.

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
tools/                 Repository automation, validation scripts, and generation helpers.
```

## Broad Orientation

For coding agents, [AGENTS.md](./AGENTS.md) is the canonical instruction file.
Use the links below for broad orientation rather than as mandatory pre-work for
every change.

- [Project positioning](./docs/product/positioning.md)
- [Current architecture contracts](./docs/architecture/current-contracts.md)
- [Architecture overview](./docs/architecture/overview.md)
- [Project structure](./docs/architecture/project-structure.md)
- [Context structure](./docs/architecture/context-structure.md)
- [Technology stack](./docs/architecture/technology-stack.md)
- [Decision index](./docs/decisions/index.md)
- [Agent context entrypoint](./docs/agent-context/START_HERE.md)

## Initial Decisions

The current foundation is:

- Use a product monorepo for the client, backend, runner, schemas, docs, and default Agent Pack.
- Use Flutter + Dart for the mobile-first client.
- Use SQLite for the local-first data layer. The current implementation uses
  hand-written `sqlite3`; Drift remains the accepted long-term client target.
- Keep backend services optional and enhancing, not required for core use.
- Build a lightweight WideNote Agent Runtime Kernel inside the product.
- Treat external agent/workflow frameworks as runner adapters or integration targets.
- Maintain decision history with ADRs and RFCs.

## License

This repository includes the AGPLv3 license in [LICENSE](./LICENSE). A future
commercial dual-license path remains a product/business option, but AGPLv3 is
the current checked-in license text.
