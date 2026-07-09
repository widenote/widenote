---
name: widenote-code-change-orchestrator
description: Use for WideNote code-change work implementing new requirements, bug fixes, code changes, or PR preparation. Do not use for ordinary read-only research or product discussion. Coordinates isolated subagents for design, implementation, QA, review, and a final Human Review Pack while minimizing human interruption.
---

# WideNote Code Change Orchestrator

Use this skill only for code-change work:

- New requirements or feature slices.
- Bug fixes and regressions.
- Behavior, test, docs, schema, workflow, or PR-prep changes.

Do not use it for ordinary read-only research, code explanation, product
brainstorming, or lightweight discussion unless the user asks to change code.

Reference workflow:

- `docs/workflows/code-change-orchestration.md`

## Operating Principle

Minimize human participation. Humans provide vision, scenarios, key product
decisions, and final acceptance. The coordinator and subagents handle research,
planning, implementation, QA, review, validation evidence, and PR preparation.

Use fresh, bounded subagent contexts for key stages. Pass only the necessary
goal, constraints, files, scope, and report format; avoid dumping the whole
conversation into each subagent unless it is necessary.

## Before Editing

1. Read `AGENTS.md`.
2. Read `docs/workflows/code-change-orchestration.md`.
3. Load only task-relevant current contracts, module READMEs, and decision docs.
4. Determine whether any human interruption gate is triggered.
5. If no gate is triggered, proceed without asking the human for routine
   engineering choices.

## Required Subagent Shape

Use a Design Scout subagent for non-trivial changes before implementation.

Use an Implementation Worker subagent for non-trivial implementation or any
clear write-scope slice. Tiny single-file fixes may be implemented by the
coordinator, but QA and Review still need fresh contexts.

Use a QA subagent after implementation, scaled to the changed surface. Behavior
changes need black-box and white-box checks; docs-only changes can use link,
path, and diff hygiene checks.

Use a Review subagent before final handoff or PR to inspect requirement
coverage, repo-principle alignment, tests, docs, project map, and residual risk.

## Human Interruption Gates

Pause and ask the human only when:

- Product direction or default UX would be encoded long term.
- The plan conflicts with local-first ownership, source truth, privacy,
  permissions, public schemas, Agent Pack boundaries, or accepted ADR/RFC
  direction.
- High-risk permissions, secrets, external services, sync, background
  execution, broad filesystem/network access, or new runner behavior are needed.
- The work must exceed the agreed write scope or touch unrelated changes.
- Core validation cannot run and the residual risk affects user-visible
  behavior or source-truth integrity.
- Multiple viable product directions have materially different user outcomes.

## Final Response

End with a Human Review Pack:

```md
## What changed
## Impacted areas
## Requirement coverage
## Tests and validation
## Skipped checks and residual risk
## Project-principle conflicts
## Docs, README, project map, ADR/RFC status
## Subagent reports summarized
## Human acceptance focus
```

If preparing a PR, make the title and description bilingual as required by
`AGENTS.md`.
