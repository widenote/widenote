# Code Change Orchestration

Status: active

Scope: new requirements, bug fixes, code changes, and PR preparation

This workflow keeps human involvement small and high-leverage. Humans provide
vision, scenarios, key product decisions, and final acceptance. AI agents handle
research, plan synthesis, implementation, QA, review, validation evidence, and
PR preparation unless a gate below requires human judgment.

## Trigger

Use this workflow for:

- New requirements or feature slices.
- Bug fixes and regressions.
- Code changes that affect behavior, tests, docs, schemas, or workflows.
- PR preparation after local changes.

Do not use it for ordinary read-only research, code explanation, product
brainstorming, or lightweight discussion unless the task becomes a code-change
request.

## Default Flow

```text
human vision / scenario / rough interaction
  -> coordinator intake
  -> Design Scout subagent
  -> Implementation Worker
  -> QA subagent
  -> Review subagent
  -> Human Review Pack
  -> PR
```

The coordinator should pass bounded prompts to subagents and avoid forking the
full conversation unless the full context is necessary. Subagents should receive
only the goal, constraints, required context files, allowed write scope, and
expected report shape they need.

## Human Interruption Gates

The AI should keep moving without interrupting the human unless one of these is
true:

- The change would encode a long-term product direction or default UX.
- The plan conflicts with local-first ownership, source truth, privacy,
  permissions, public schemas, Agent Pack boundaries, or accepted ADR/RFC
  direction.
- The implementation requires high-risk permissions, secrets, external
  services, sync, background execution, broad filesystem/network access, or new
  runner behavior.
- The work needs to exceed the agreed write scope or modify unrelated changes.
- Core validation cannot run and the remaining risk affects user-visible
  behavior or source-truth integrity.
- The Design Scout finds multiple viable product directions with materially
  different user outcomes.

Routine engineering choices should be made by the AI using existing contracts,
module READMEs, tests, and local patterns.

## Subagent Roles

### Design Scout

Default: separate read-only subagent for non-trivial code-change tasks.

Responsibilities:

- Inspect current code, docs, contracts, and relevant references.
- Propose the smallest viable implementation plan.
- Identify affected modules, tests, README/project-map/docs updates, and risk.
- State whether human decision is required under the interruption gates.

Output:

```md
## Recommended plan
## Alternatives considered
## Human decision needed
## Affected files and contracts
## Required tests and validation
## Risks
```

### Implementation Worker

Default: separate worker subagent for non-trivial implementation or any task
with clear write-scope boundaries. For tiny single-file fixes, the coordinator
may implement directly, but QA and Review still use fresh contexts.

Responsibilities:

- Edit only the allowed write paths.
- Preserve unrelated user or worker changes.
- Add or update tests in the same work package.
- Report skipped tests with reasons.

Worker prompt must include:

- Goal and acceptance criteria.
- Allowed write paths.
- Prohibited paths.
- Required reading.
- Required tests.
- No-revert/no-reset/no-clean rule.
- Final report shape.

Output:

```md
## Files changed
## Behavior implemented
## Tests added or updated
## Tests run
## Tests not run and why
## Scope deviations
## Risks for coordinator
```

### QA Subagent

Required after implementation, scaled to the changed surface. Behavior changes
need black-box and white-box checks; docs-only changes can use link, path, and
diff hygiene checks.

Responsibilities:

- Design black-box user-scenario checks from the original request.
- Design white-box checks for branches, edge cases, errors, regressions, and
  contract-sensitive paths.
- Run targeted unit, widget, orchestration, emulator, or simulator checks when
  available and relevant.
- Name any coverage gaps and residual risk.

Output:

```md
## Black-box scenarios
## White-box coverage
## Commands run
## Results
## Gaps and residual risk
```

### Review Subagent

Required before final handoff or PR.

Responsibilities:

- Review the final diff in a fresh context.
- Check requirement coverage and whether the implementation matches the plan.
- Check relevant `AGENTS.md`, current contracts, module README, localization,
  source-ref, privacy, navigation, schema, and generated-artifact rules.
- Check whether README, project map, ADR/RFC, workflow docs, or tests needed
  updates and whether they were updated.
- Classify findings as blocker, should-fix, or note.

Output:

```md
## Requirement coverage
## Blockers
## Should-fix
## Notes
## Documentation and project-map status
## Human review focus
```

## Human Review Pack

Before asking for final human acceptance or opening a PR, provide:

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

The pack should be concise. It should make clear what the AI completed, what it
validated, what it could not validate, and where the human should focus review.

## First Version Boundary

This workflow is a documented coordination contract, not an automated gate. Add
hooks or scripts later only after repeated use shows which checks should become
hard enforcement.
