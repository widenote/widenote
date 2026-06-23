# Engineering Rules

Status: draft

Date: 2026-06-23

Scope: implementation rules for WideNote code, tests, documentation, and agent collaboration

These rules keep the project navigable as humans and agents add code quickly.

## Complexity Budgets

Hard limits for production code:

| Unit | Limit |
| --- | --- |
| Source file | <= 800 lines, excluding generated files |
| Function/method | <= 40 lines by default; <= 60 only with clear extraction cost |
| Widget build method | <= 80 lines; split private widgets before it grows further |
| Class | One primary responsibility |
| Nesting | <= 3 control-flow levels |
| Public module API | Small, named, documented in module README |

When a limit is exceeded, split by responsibility before adding more behavior.

Generated files are exempt, but their source of truth and generator command must be documented.

## Test Rules

- Runtime, Memory, model routing, permissions, data storage, and migrations need unit tests.
- Any UI view or interaction needs widget tests.
- Any feature crossing capture, event dispatch, Agent Pack, Memory, cards, insights, or todos needs an orchestration test.
- Tests must use deterministic fake agents and fake model clients by default.
- Real model-provider tests are opt-in and must not be required for CI.
- Do not store API keys in the repository, fixtures, snapshots, logs, or docs.

## Agent Runtime Test Minimum

The phase-one runtime must include an end-to-end test that proves:

```text
capture created
  -> event appended
  -> pack subscription matched
  -> task executed
  -> Memory auto-accepted
  -> card created
  -> insight or todo output emitted
  -> trace contains the run
```

The test should use fake tools/model clients so it is fast, deterministic, and offline.

## Memory Write Policy

WideNote defaults to silent Memory creation for low-risk durable information. The product should not ask users to confirm every Memory.

Rules:

- Auto-accept durable, low-risk, non-conflicting Memory.
- Put low-confidence, conflicting, highly sensitive, or policy-unclear Memory into review.
- Every auto-accepted Memory must be source-linked, reversible, and visible in review surfaces.
- Deleting or correcting Memory must be easy and must write a tombstone or revision.
- No Memory is created from raw model inference without evidence.

## Subagent Work Rules

When using subagents:

- Assign disjoint write scopes.
- Require tests in the same work package.
- Require module README updates when module shape changes.
- Require a summary of changed files, tests run, and known risks.
- Main coordinator owns final integration, conflict resolution, and verification.

## External Review Rules

External model review is useful but not authoritative.

- Use Kimi or another configured model to review architecture and code when credentials work.
- Never paste secrets into files.
- Redact or omit sensitive user data.
- Treat review findings as input; fix confirmed issues locally.

