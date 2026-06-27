# Agent Instructions

This repository is the foundation for WideNote / 广记: a local-first personal
record, memory, and agent runtime.

## Canonical Source

`AGENTS.md` is the canonical repository instruction file for AI coding agents.

Tool-specific entry files, including `CLAUDE.md`, should point here instead of
duplicating project rules. If an instruction changes, update this file first.

## Project Identity

WideNote is a mobile-first, local-first personal record, memory, and agent
runtime.

The default product loop is intentionally narrow:

```text
quick capture -> timeline / cards -> memory -> insight
```

Backend services, remote runners, sync, hosted registries, broad imports,
community Agent Packs, and advanced exports are optional enhancements unless an
ADR or RFC says otherwise.

## Read First

Before architectural, product, runtime, schema, privacy, plugin, or UX changes,
read these in order:

1. `docs/agent-context/START_HERE.md`
2. `docs/decisions/index.md`
3. `docs/agent-context/project-map.md`
4. The nearest area or module `README.md`
5. Any ADR or RFC related to the files you plan to touch
6. `widenote_project_brief.md` only when product intent is unclear

For narrow edits, load only the context needed for the touched area. Do not make
agents or humans read the whole repository by default.

## Durable Product Constraints

- Core usage must work without an account or official backend.
- The mobile client owns immediate capture, local persistence, local runtime
  hosting, and the first user experience.
- Original user records are source truth. AI output must not overwrite raw
  input.
- Memory, cards, insights, recaps, todos, summaries, and chat answers are
  derived outputs. They must preserve source references when they depend on
  user records.
- Backend services enhance sync, backup, scheduling, runner execution,
  registry, and ecosystem features. They are not the canonical brain.
- Agent Packs must depend on public schemas and SDK boundaries, not private app
  tables or UI internals.
- Sensitive or high-risk capabilities belong behind explicit permissions,
  reviewable traces, and, where needed, community-edition or local-dev gates.

## Where To Look First By Task Type

| Task type | Start with |
| --- | --- |
| Repo orientation | `docs/agent-context/START_HERE.md`, `docs/agent-context/project-map.md`, `README.md` |
| Product or default UX | `docs/product/positioning.md`, `widenote_project_brief.md`, relevant RFCs |
| Mobile UI or user flow | `apps/mobile/README.md`, `apps/mobile/lib/README.md`, `docs/architecture/engineering-rules.md` |
| Flutter feature module | Nearest `apps/mobile/lib/features/*/README.md` |
| Local runtime or Memory | `docs/architecture/runtime.md`, `packages/dart/agent_runtime/README.md`, `packages/dart/memory/README.md` |
| Local persistence or backup | `packages/dart/local_db/README.md`, backup/export research and RFCs |
| Schemas or generated bindings | `packages/schemas/README.md`, `docs/rfcs/agent-pack-schema.md` |
| Agent Pack behavior | `packs/README.md`, target pack README, `docs/rfcs/agent-pack-schema.md` |
| API or remote runner | `apps/api/README.md`, `apps/runner-ts/README.md`, `packages/ts/*/README.md` |
| Docs, ADRs, or RFCs | `docs/README.md`, `docs/templates/`, `docs/decisions/README.md`, `docs/rfcs/README.md` |
| Privacy, secrets, permissions | `docs/architecture/privacy.md`, relevant ADRs/RFCs, `docs/architecture/engineering-rules.md` |

## Change-Type Validation Matrix

Run the narrowest useful checks for the changed surface. Broaden the checks when
the change crosses module boundaries or user-visible flows.

| Change type | Expected validation |
| --- | --- |
| Docs only | `git diff --check`; use `rg` to verify renamed links, project-map entries, and terminology when relevant. |
| Root instructions or project map | `git diff --check`; verify referenced files exist. |
| Flutter UI, navigation, state, dialog, sheet, localization, or interaction | Add or update widget tests; run targeted `flutter analyze` and `flutter test` from `apps/mobile`. |
| Mobile user journey or platform integration | Run focused Flutter tests and add Android emulator or iOS simulator proof when the behavior is platform-specific or high risk. |
| Dart runtime, Memory, model routing, local DB, backup, or orchestration | Run package-local `dart analyze` and `dart test`; add orchestration tests for cross-layer flows. |
| Schemas or schema fixtures | Run `node packages/schemas/validate_fixtures.mjs`; update schema docs and fixtures together. |
| Agent Pack manifests or permissions | Run `node tools/pack_validator/validate_test.mjs` and `node tools/pack_validator/validate.mjs packs/official/default/manifest.json packs/official/todo/manifest.json`. |
| Generated artifacts | Regenerate from the documented source of truth; do not hand-edit generated output. |
| Privacy, secrets, backup, sync, plugin permissions, or high-risk tools | Re-check ADR/RFC triggers and include explicit tests or documentation for permission, redaction, restore, and trace behavior. |
| GitHub publication | Fetch the latest target branch, update or create the work branch from it, verify the diff, run relevant checks, then push and open a draft PR unless the user asks otherwise. |

If a check cannot run because of missing dependencies, device availability, or
environment issues, record the exact reason and remaining risk.

## Pull Request Requirements

- PR titles and descriptions must be bilingual: Chinese and English. Put the
  Chinese summary first when the product owner has not requested otherwise.
- Before opening a PR, run detailed unit tests for non-UI behavior and widget
  tests for every Flutter UI or user-interaction change. The PR description
  must list the commands that ran and explain skipped checks with risk.
- All user-facing frontend strings must use localization resources. Do not
  hard-code display text in Flutter UI; update both English and Chinese ARB
  files and regenerate localization bindings when strings change.

## Structure Constraints

- Keep code structure clear, bounded, and navigable by humans and agents.
- Every durable module or package must have a `README.md` that states its
  purpose, ownership boundary, dependencies, public surface, generated
  artifacts, and related decisions.
- When adding, moving, renaming, or deleting a durable module, update its parent
  directory README and `docs/agent-context/project-map.md` in the same change.
- Generated files must have a documented source of truth and generation
  command. Do not hand-edit generated artifacts.
- Public runtime contracts belong in `packages/schemas` unless an ADR says
  otherwise.
- Feature modules must not define private copies of public Event, Memory,
  Permission, Agent Pack, Trace, Backup, Sync, or UI Block contracts.
- Keep `apps/mobile` focused on immediate UX, platform integration, local
  persistence hosting, and local runtime hosting. Move reusable pure logic into
  `packages/dart`.
- Keep backend, runner, and infrastructure code optional for core local-first
  usage unless an accepted decision changes that boundary.

## Privacy, Secrets, And External Review

- Never commit API keys, provider tokens, credentials, local databases, private
  records, full traces containing user content, or secret-bearing backup files.
- Never place secrets in fixtures, snapshots, generated docs, screenshots, logs,
  PR descriptions, or research notes.
- Do not send raw private records, local database contents, credentials,
  provider keys, unpublished user data, or secret-bearing exports to external
  model review tools.
- External review is advisory. Local ADRs/RFCs, repository instructions, tests,
  and user-approved product boundaries are authoritative.
- Do not introduce broad filesystem, network, location, microphone, camera,
  contacts, notification, shell, or credential access without explicit
  permission design and ADR/RFC coverage.
- Agent-generated content must flow through the same source-linked Memory,
  card, todo, insight, trace, and review policies as built-in behavior.

## Decision Hygiene

If a change affects schema, runtime, memory, sync, privacy, plugin permissions,
Agent Packs, technology stack, licensing, or default UX, update or create an
ADR/RFC.

Do not treat raw conversation history as an authoritative decision. Summarize it
into `docs/research/`, then link it from ADRs or RFCs.

Research notes are evidence. ADRs and accepted RFCs are decisions.
