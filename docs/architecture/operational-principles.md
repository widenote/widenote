# Operational Principles

Status: active

Date: 2026-07-02

Scope: cross-cutting preflight triggers for day-to-day WideNote work

This file is a lightweight preflight checklist. It does not replace
`current-contracts.md`, ADRs, RFCs, module READMEs, or engineering rules. Use it
to notice cross-cutting principles before changing code, then open the linked
current contract or decision only when the task touches that area.

## How To Use

Before editing, scan the triggers below. If a trigger matches the task, apply
the rule and read the linked source when the boundary is unclear or changing.

Keep this file short. Each principle should state:

- Trigger: what kind of task activates the principle.
- Rule: what must stay true.
- Allowed deterministic checks: local logic that is still permitted.
- Sources: current contracts, ADRs, RFCs, or research notes that carry detail.

## Principle Index

### Model-Governed Semantic Decisions

Trigger:

- User natural-language content is used for semantic classification, ranking,
  routing, admission, fallback, summarization, masking, or user-visible
  intelligence.
- A change touches capture, Memory, cards, insights, todos, chat answers,
  Context Packets, source selection, review routing, or AI-derived UI.

Rule:

- WideNote core must not use local keyword, regular-expression, substring, or
  stop-word heuristics over user natural-language content to infer meaning.
- Route semantic judgment through governed model or context boundaries.
- When no model-backed answer is available, fail closed or show a retryable
  unavailable state instead of inventing a local "smart" fallback.

Allowed deterministic checks:

- Schema validation and enum normalization.
- Exact technical parsing of model output, IDs, dates already emitted by a
  model, paths, MIME types, file names, or protocol fields.
- Permission gates, risk gates based on declared capability metadata, platform
  error-code handling, and generated contract validation.
- Test-injected fake models or fake retrievers.

Sources:

- `docs/architecture/current-contracts.md`: Semantic selection.
- `docs/decisions/0010-delegate-semantic-selection-to-models.md`.

### Source Truth And Derived Output

Trigger:

- A change creates, edits, displays, backs up, restores, exports, summarizes, or
  answers from user records, attachments, transcripts, Memory, todos, cards,
  insights, recaps, or chat messages.

Rule:

- Original user records and source material are source truth.
- AI output is derived state and must not overwrite raw input.
- Derived outputs must preserve source references when they depend on user
  records or reviewed actions.

Allowed deterministic checks:

- Source-ref validation, hash checks, restore integrity checks, and rebuildable
  projection updates.
- UI grouping or filtering based on stored structured metadata.

Sources:

- `docs/architecture/current-contracts.md`: Source truth.
- `docs/decisions/0009-use-object-truth-and-context-packets.md`.

### Local-First Ownership

Trigger:

- A change makes account, backend, runner, sync, registry, import, or hosted
  service behavior part of first use or core capture behavior.

Rule:

- The mobile client owns immediate capture, local persistence, local runtime
  hosting, permissions, and first-use UX.
- Backend, runner, sync, backup, registry, and ecosystem services may enhance
  the product, but they must not become prerequisites for core local use unless
  an accepted decision changes that boundary.

Allowed deterministic checks:

- Local persistence, local runtime, local permission, and offline fallback
  checks that preserve raw user input and source refs.

Sources:

- `docs/architecture/current-contracts.md`: Local-first ownership.
- `docs/decisions/0003-build-agent-runtime-kernel.md`.
- `docs/decisions/0007-defer-cloud-sync-from-core-phase-one.md`.

### Privacy, Secrets, And High-Risk Capabilities

Trigger:

- A change touches credentials, local databases, backup files, private records,
  raw prompts, raw traces, location, microphone, camera, contacts,
  notifications, files, network, shell, external review, or plugin permissions.

Rule:

- Do not commit or externalize secrets, private records, local databases,
  secret-bearing backups, raw private prompts, or full traces containing user
  content.
- Sensitive or high-risk capabilities require explicit permissions,
  reviewable traces, and ADR/RFC coverage where the boundary is new.
- External review is advisory and must receive only non-secret, task-relevant
  code, docs, and redacted context.

Allowed deterministic checks:

- Secret-boundary tests, permission metadata validation, redaction assertions,
  restore integrity checks, and trace-shape validation that does not inspect
  private user content semantically.

Sources:

- `AGENTS.md`: Privacy, Secrets, And External Review.
- `docs/architecture/current-contracts.md`: Agent Packs, marketplace, and
  permissions.
- `docs/architecture/privacy.md`.

### Public Contracts And Generated Artifacts

Trigger:

- A change touches Event, Memory, Permission, Agent Pack, Trace, Backup, Sync,
  Tool, Task, UI Block, schema fixtures, generated bindings, or official pack
  manifests.

Rule:

- Public runtime contracts belong in `packages/schemas` unless an accepted ADR
  says otherwise.
- Do not hand-edit generated artifacts without updating the documented source
  of truth and generation command.
- Agent Packs must depend on public schemas and SDK boundaries, not private app
  tables or UI internals.

Allowed deterministic checks:

- Schema validation, pack validation, generated-binding regeneration, manifest
  alignment tests, and exact structural parsing.

Sources:

- `docs/architecture/current-contracts.md`: Public contracts.
- `docs/rfcs/agent-pack-schema.md`.
- `packages/schemas/README.md`.

## Maintenance

- Add a principle only when it is cross-cutting and likely to be missed during
  task preflight.
- Keep detailed rationale in ADRs, RFCs, or research notes. Link them here
  instead of copying their history.
- When a principle changes target state, update `current-contracts.md`, affected
  module READMEs, and executable or documented validation in the same change.
