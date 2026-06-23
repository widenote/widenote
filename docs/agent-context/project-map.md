# Project Map

This map is the canonical entrypoint for progressive context disclosure.

It should stay short. It points to the right local context instead of duplicating every detail.

## Product

- `docs/product/positioning.md`
- `widenote_project_brief.md`

## Architecture

- `docs/architecture/overview.md`
- `docs/architecture/project-structure.md`
- `docs/architecture/context-structure.md`
- `docs/architecture/runtime.md`
- `docs/architecture/technology-stack.md`
- `docs/architecture/privacy.md`
- `docs/architecture/phase-one-technical-plan.md`
- `docs/architecture/phase-one-module-plan.md`
- `docs/architecture/engineering-rules.md`

## Decisions

- `docs/decisions/index.md`

## Research

- `docs/research/2026-06-23-phase-one-technical-research.md`
- `docs/research/2026-06-23-memex-design-critique.md`
- `docs/research/2026-06-23-kimi-review-followup.md`

## RFCs

- `docs/rfcs/memory-model.md`
- `docs/rfcs/agent-pack-schema.md`

## Areas

| Area | Context | Purpose |
| --- | --- | --- |
| Apps | `apps/README.md` | Runnable apps and services |
| Packages | `packages/README.md` | Shared package boundaries |
| Agent Packs | `packs/README.md` | Installable capability bundles |
| Docs | `docs/README.md` | Product, architecture, decisions, and research |
| Infra | `infra/README.md` | Deployment and self-hosting assets |
| Tools | `tools/README.md` | Repository automation and generators |

## Modules

| Module | Context | Purpose |
| --- | --- | --- |
| Mobile app | `apps/mobile/README.md` | Flutter client and local runtime host |
| API service | `apps/api/README.md` | Optional backend API |
| TypeScript runner | `apps/runner-ts/README.md` | Self-hosted or cloud runner |
| Schemas | `packages/schemas/README.md` | Shared runtime contracts and generated types |
| Dart core | `packages/dart/core/README.md` | Pure Dart models and utilities |
| Dart local DB | `packages/dart/local_db/README.md` | Drift and SQLite data layer |
| Dart agent runtime | `packages/dart/agent_runtime/README.md` | Local Agent Runtime Kernel |
| Dart memory | `packages/dart/memory/README.md` | Memory lifecycle and auto-accept policy |
| Dart model providers | `packages/dart/model_providers/README.md` | Provider contracts and runtime adapter |
| Dart UI blocks | `packages/dart/ui_blocks/README.md` | Structured UI block rendering |
| TS protocol | `packages/ts/protocol/README.md` | TypeScript protocol helpers |
| TS runner core | `packages/ts/runner_core/README.md` | Runner execution primitives |
| TS agent SDK | `packages/ts/agent_sdk/README.md` | Runner-side Agent Pack SDK |
| Default Agent Pack | `packs/official/default/README.md` | Default capture to insight loop |

## Maintenance Rule

When a durable module is added, moved, renamed, or deleted, update this map in the same change.
