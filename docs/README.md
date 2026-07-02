# WideNote Docs

This directory is the project memory for humans and agents.

```text
product/          Product positioning, users, default experience, and roadmap.
architecture/     Runtime, data, privacy, project structure, and technical design.
decisions/        Accepted, rejected, superseded, and deprecated ADRs.
rfcs/             Design proposals and accepted implementation baselines.
research/         External research and summarized discussion evidence.
agent-context/    Entry points for future AI agents working in this repo.
templates/        Reusable ADR, RFC, and conversation-summary templates.
```

For cross-cutting preflight triggers, start with
[Operational Principles](./architecture/operational-principles.md). For current
target-state contracts, use
[Current Architecture Contracts](./architecture/current-contracts.md). For
historical decisions, rationale, and supersession history, use
[decisions/index.md](./decisions/index.md).

## Current Phase-One State And Plans

- [Current Architecture Contracts](./architecture/current-contracts.md)
- [Operational Principles](./architecture/operational-principles.md)
- [Chat Session Management Plan](./research/2026-07-01-chat-session-management-plan.md)
- [W7 Current Integration State](./research/2026-06-26-w7-current-integration-state.md) is dated integration evidence; use current contracts for the current target state.
- [W7 Integration QA](./research/2026-06-26-w7-integration-qa.md)
- [Cross-Platform Long Conversation Test Plan](./research/2026-06-27-cross-platform-long-conversation-test-plan.md)
- [Cross-Platform Core Smoke Results](./research/2026-06-27-cross-platform-core-smoke-results.md)
- [Live LLM Long Journey QA](./research/2026-06-27-live-llm-long-journey-qa.md)
- [Marketplace and PKM Plan](./research/2026-06-28-marketplace-pkm-plan.md)
- [Local Semantic Rule Audit](./research/2026-06-27-local-semantic-rule-audit.md)
- [Agent Runtime Roadmap Research](./research/2026-06-27-agent-runtime-roadmap-research.md)
- [Agent Orchestration Parity](./research/2026-06-27-agent-orchestration-parity.md)
- [Phase One Technical Plan](./architecture/phase-one-technical-plan.md) is a planning baseline; use current contracts and the umbrella RFC for current target state.
- [Phase One Module Plan](./architecture/phase-one-module-plan.md) is a planning baseline; update module READMEs and project map as modules land.
- [Engineering Rules](./architecture/engineering-rules.md) for complexity budgets, test gates, subagent collaboration, external review boundaries, and emulator validation
- [Phase One Technical Research](./research/2026-06-23-phase-one-technical-research.md)
- [MemeX Design Critique](./research/2026-06-23-memex-design-critique.md)
- [Kimi Review Follow-Up](./research/2026-06-23-kimi-review-followup.md)
- [External Review Follow-Up](./research/2026-06-24-external-review-followup.md)
- [Android Emulator QA](./research/2026-06-24-android-emulator-qa.md)
- [MemeX Phase-One Parity Gap Audit](./research/2026-06-24-memex-phase-one-gap-audit.md)
- [Product and Technical Direction Summary](./research/2026-06-26-product-technical-direction-summary.md)
- [Storage and Export Selection Options](./research/2026-06-26-storage-export-selection-options.md)
- [Kimi Technical Direction Review](./research/2026-06-26-kimi-technical-direction-review.md)
- [Implementation Readiness Review](./research/2026-06-26-implementation-readiness-review.md)
- [Phase-One Acceptance Matrix](./research/2026-06-26-phase-one-acceptance-matrix.md)
- [Current Implementation Baseline](./research/2026-06-26-current-implementation-baseline.md) is historical pre-wave evidence; use current contracts for the current implementation boundary.
- [Wave One Coordination](./research/2026-06-26-wave-one-coordination.md)
- [Wave One Results](./research/2026-06-26-wave-one-results.md)
- [Wave Two Coordination](./research/2026-06-26-wave-two-coordination.md)
- [Wave Two Results](./research/2026-06-26-wave-two-results.md)
- [Wave Three Coordination](./research/2026-06-26-wave-three-coordination.md)
- [Wave Three Results](./research/2026-06-26-wave-three-results.md)
- [Android Emulator QA](./research/2026-06-26-android-emulator-qa.md)
- [iOS Simulator QA](./research/2026-06-26-ios-simulator-qa.md)
- [Daily Recap QA](./research/2026-06-26-daily-recap-qa.md)
- [Settings and Privacy QA](./research/2026-06-26-w7-settings-privacy-qa.md)
- [Backup Restore QA](./research/2026-06-26-w7-backup-restore-qa.md)
- [Real Media Capture QA](./research/2026-06-26-w7-real-media-capture-qa.md)

## Phase-One RFC State

- [Phase-One Umbrella Technical Plan](./rfcs/phase-one-umbrella-technical-plan.md): accepted implementation baseline.
- [Phase-One Product Scope](./rfcs/phase-one-product-scope.md): accepted scope, amended by ADR-0013 full-backup credential boundary.
- [Model Provider Settings](./rfcs/model-provider-settings.md): accepted provider-settings slice, amended by ADR-0013 full-backup credential boundary.
- [Memory Model](./rfcs/memory-model.md): accepted phase-one contract with follow-ups open.
- [Agent Pack Schema](./rfcs/agent-pack-schema.md): accepted phase-one contract; scripted/community runtime deferred.
- [Agent Runtime Capability Boundaries](./rfcs/agent-runtime-capability-boundaries.md): proposed implementation guardrail under ADR-0011.
- [Mobile Entry Closure](./rfcs/mobile-entry-closure.md): implemented slice; current target-state amendments live in current contracts and newer ADRs.
- [Mobile Visual Style](./rfcs/mobile-visual-style.md): accepted.

## Contract Sources

- [Current Architecture Contracts](./architecture/current-contracts.md)
- [Schema sources](../packages/schemas/README.md)
- [Official default Agent Pack manifest](../packs/official/default/manifest.json)
- [Official todo Agent Pack manifest](../packs/official/todo/manifest.json)
- [Official PKM Agent Pack manifest](../packs/official/pkm_library/manifest.json)
- [Official transcript correction Agent Pack manifest](../packs/official/transcript_correction/manifest.json)
- [Marketplace index](../packs/marketplace/index.json)

## Contract Validation

Validate phase-one official Agent Pack manifests with the lightweight validator:

```sh
node tools/pack_validator/validate.mjs packs/official/default/manifest.json packs/official/todo/manifest.json packs/official/pkm_library/manifest.json packs/official/transcript_correction/manifest.json packs/marketplace/index.json
```

This is a lightweight validator, not a complete JSON Schema validator.

## Context Structure

Project context should be discoverable in layers:

- Root docs explain the whole project.
- Current architecture contracts state the target-state rules agents should
  maintain by default.
- Area READMEs explain top-level directories.
- Module READMEs explain ownership boundaries and generated artifacts.
- `agent-context/project-map.md` points to the current context entrypoints.
