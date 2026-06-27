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

Single-file and single-function rules:

- Do not add unrelated responsibilities to a file just because it is nearby.
- If a source file is already over budget, only make a narrow fix there; create a follow-up split plan before adding new feature behavior.
- Extract private helpers, small value objects, presenters, or widgets when a function needs multiple phases of logic.
- Prefer named boundaries over dense inline callbacks when state, permission, persistence, or runtime behavior crosses layers.
- Keep public APIs boring: small names, clear ownership, and README coverage before reuse.

## Test Rules

- Runtime, Memory, model routing, permissions, data storage, and migrations need unit tests.
- Any non-UI behavior change needs detailed unit coverage for the changed branch, edge case, or regression.
- Any UI view or interaction needs widget tests.
- Any feature crossing capture, event dispatch, Agent Pack, Memory, cards, insights, or todos needs an orchestration test.
- Tests must use deterministic fake agents and fake model clients by default.
- Real model-provider tests are opt-in and must not be required for CI.
- Do not store API keys in the repository, fixtures, snapshots, logs, or docs.

UI test gate:

- Rendering, state changes, navigation, dialogs, sheets, buttons, gestures, empty/loading/error states, localization, and user interaction all count as UI changes.
- Every UI change must include widget tests in the same work package unless the change is docs-only or purely non-rendered plumbing.
- Widget tests should assert the user-visible result, not only that a widget type exists.
- Golden tests are optional; they do not replace interaction and state coverage.
- When a UI change depends on runtime/model output, use fake runtime events or fake model clients.
- Pull requests with UI changes must list the widget tests that cover the changed rendering or interaction. If widget tests are skipped, the PR must explain why and name the remaining user-visible risk.

Localization gate:

- Every user-facing frontend string must go through Flutter localization resources. Do not hard-code display text in widgets, dialogs, sheets, buttons, empty states, errors, or navigation labels.
- Update both `apps/mobile/lib/l10n/app_en.arb` and `apps/mobile/lib/l10n/app_zh.arb` when adding or changing display text.
- Regenerate localization bindings with `flutter gen-l10n` when ARB files change.
- Widget tests for changed UI should assert localized user-visible text through the normal localization path instead of relying on private constants.

Validation gates:

- Docs-only changes can use lightweight checks such as `rg` link/text checks.
- Code changes should run the narrowest useful unit/widget/orchestration tests for the touched surface.
- Changes to cross-layer flows should include at least one end-to-end or orchestration proof with deterministic fakes.
- Android emulator validation is required for Android-specific behavior and high-risk mobile user journeys.
- Android emulator validation must be serialized across agents; only one agent owns the emulator at a time.
- If emulator validation is skipped, record why and list the remaining risk.

PR gate:

- PR titles and descriptions must be bilingual: Chinese and English.
- PR descriptions must include the exact unit, widget, orchestration, emulator, simulator, schema, or docs checks that ran.
- If any expected validation cannot run, the PR must explain the reason and the residual risk.

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

- Split by durable ownership boundary, not by arbitrary file count.
- Assign disjoint write scopes before work starts; overlapping files require coordinator approval.
- Give each subagent the required context files, related ADRs/RFCs, expected tests, and allowed write paths.
- Require tests in the same work package.
- Require module README updates when module shape changes.
- Require a summary of changed files, tests run, skipped checks, and known risks.
- Keep Android emulator validation in a single serialized lane coordinated by the main agent.
- Main coordinator owns final integration, conflict resolution, latest-state verification, and final risk call.

Good splits include:

- Schema/contracts vs generated bindings.
- Runtime kernel vs UI presentation.
- Local persistence vs feature read models.
- Independent feature modules with separate tests.

Bad splits include:

- Multiple agents editing the same navigation, bootstrap, database, or generated file at once.
- One agent changing public contracts while another consumes guessed contract behavior.
- UI changes without an assigned widget-test owner.

## External Review Rules

External model review is useful but not authoritative.

- Use Kimi or another configured model to review architecture, rules, code risk, or test gaps when credentials work.
- Never paste secrets into files.
- Redact or omit sensitive user data.
- Do not send raw private records, API keys, credentials, local database contents, or unpublished user data.
- Do not let external review override accepted ADRs/RFCs, public schemas, repository instructions, or local test evidence.
- Treat review findings as input; verify and fix confirmed issues locally.
- Keep durable review conclusions in `docs/research/` before linking them from ADRs or RFCs.
- Do not block local progress on external review when credentials, quota, network, or tool access fail; record the skipped review and continue with local checks.
