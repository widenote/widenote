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
- `docs/research/2026-06-24-external-review-followup.md`
- `docs/research/2026-06-24-external-review-round-gap-closeout.md`
- `docs/research/2026-06-24-android-emulator-qa.md`
- `docs/research/2026-06-24-android-followup-qa.md`
- `docs/research/2026-06-24-memex-phase-one-gap-audit.md`
- `docs/research/2026-06-25-mobile-entry-gap-audit.md`
- `docs/research/2026-06-25-mobile-entry-closure-review.md`
- `docs/research/2026-06-25-mobile-entry-closure-android-qa.md`
- `docs/research/2026-06-25-live-model-user-journey-qa.md`
- `docs/research/2026-06-25-mobile-ui-style-trends.md`
- `docs/research/2026-06-25-capture-provider-orchestration-ux.md`
- `docs/research/2026-06-24-omi-clean-room-plan.md`
- `docs/research/2026-06-24-omi-android-qa.md`

## RFCs

- `docs/rfcs/memory-model.md`
- `docs/rfcs/agent-pack-schema.md`
- `docs/rfcs/model-provider-settings.md`
- `docs/rfcs/phase-one-product-scope.md`
- `docs/rfcs/mobile-entry-closure.md`
- `docs/rfcs/mobile-visual-style.md`

## Contract Sources

- `packages/schemas/src/`
- `packs/official/default/manifest.json`
- `packs/official/todo/manifest.json`
- `tools/pack_validator/validate.mjs`

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
| Mobile backup | `apps/mobile/lib/features/backup/README.md` | Local JSON backup export/import UI |
| Mobile Memory | `apps/mobile/lib/features/memory/README.md` | Accepted Memory list, edit, tombstone delete, and restore UI |
| Mobile model providers | `apps/mobile/lib/features/model_providers/README.md` | Provider settings UI and local state |
| Mobile traces | `apps/mobile/lib/features/traces/README.md` | Read-only local Agent Runtime trace console |
| API service | `apps/api/README.md` | Optional backend API |
| TypeScript runner | `apps/runner-ts/README.md` | Self-hosted or cloud runner |
| Schemas | `packages/schemas/README.md` | Shared runtime contracts and generated types |
| Dart core | `packages/dart/core/README.md` | Pure Dart models and utilities |
| Dart cards | `packages/dart/cards/README.md` | Memory-first cards and source-linked insight derivation |
| Dart local DB | `packages/dart/local_db/README.md` | SQLite local truth layer; Drift remains the long-term client target |
| Dart agent runtime | `packages/dart/agent_runtime/README.md` | Local Agent Runtime Kernel |
| Dart memory | `packages/dart/memory/README.md` | Memory lifecycle and auto-accept policy |
| Dart model providers | `packages/dart/model_providers/README.md` | Provider contracts and runtime adapter |
| Dart UI blocks | `packages/dart/ui_blocks/README.md` | Structured UI block rendering |
| TS protocol | `packages/ts/protocol/README.md` | TypeScript protocol helpers |
| TS runner core | `packages/ts/runner_core/README.md` | Runner execution primitives |
| TS agent SDK | `packages/ts/agent_sdk/README.md` | Runner-side Agent Pack SDK |
| Default Agent Pack | `packs/official/default/README.md` | Default capture to insight loop |
| Todo Agent Pack | `packs/official/todo/README.md` | Source-linked todo suggestion loop |
| Pack validator | `tools/pack_validator/README.md` | Lightweight Agent Pack manifest checks |

## Maintenance Rule

When a durable module is added, moved, renamed, or deleted, update this map in the same change.
