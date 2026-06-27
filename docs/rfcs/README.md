# RFCs

RFCs are for major proposed changes and implementation baselines that may later
split into ADRs.

Open an RFC when a change is cross-cutting, hard to reverse, or affects schemas,
runtime, memory, sync, privacy, Agent Packs, plugin permissions, or public APIs.

When an RFC resolves into durable policy, record the final decision as one or
more ADRs. Do not leave an implemented phase-one RFC listed as merely open.

When an accepted RFC is used as an implementation baseline, make sure the
current target-state rules that agents should follow are also reflected in
[`docs/architecture/current-contracts.md`](../architecture/current-contracts.md).
Use the RFC for proposal detail and implementation rationale; use current
contracts for the default development state.

## Current Phase-One RFC State

| RFC | Status |
| --- | --- |
| [Phase-One Umbrella Technical Plan](./phase-one-umbrella-technical-plan.md) | Accepted implementation baseline |
| [Phase-One Product Scope](./phase-one-product-scope.md) | Accepted phase-one scope; amended by W7 safe-backup boundary |
| [Model Provider Settings](./model-provider-settings.md) | Accepted phase-one slice; amended by W7 safe-backup boundary |
| [Memory Model](./memory-model.md) | Accepted phase-one contract; follow-ups open |
| [Agent Pack Schema](./agent-pack-schema.md) | Accepted phase-one contract; scripted/community runtime deferred |
| [Agent Runtime Capability Boundaries](./agent-runtime-capability-boundaries.md) | Proposed implementation guardrail under ADR-0011 |
| [Mobile Entry Closure](./mobile-entry-closure.md) | Implemented phase-one slice; current status superseded by W7 integration state |
| [Mobile Visual Style](./mobile-visual-style.md) | Accepted |

Current implementation status lives in
[`docs/research/2026-06-26-w7-current-integration-state.md`](../research/2026-06-26-w7-current-integration-state.md).
