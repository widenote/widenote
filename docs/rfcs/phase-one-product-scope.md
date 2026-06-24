# RFC: Phase-One Product Scope

Status: Draft

Date: 2026-06-24

## Context

The phase-one target is no longer a narrow architecture MVP. It is a usable local-first product baseline that covers the core WideNote loop and the highest-priority MemeX-parity gaps through WideNote-owned designs.

The product remains Memory-first. WideNote should not copy MemeX's P.A.R.A model as the core organizing principle. Cards, insights, chat, backup, and agents should all preserve source links back to raw captures and accepted Memory.

## In Scope

Phase one must include these five product areas:

| Area | Required outcome |
| --- | --- |
| Capture console and import readiness | Home opens around a local-first capture console with text, voice-draft, photo/share import, attachment review, and raw input preservation. Real microphone recording and live ASR remain permissioned follow-ups. |
| i18n | The mobile app supports at least Chinese and English through Flutter localization, not hardcoded strings. |
| Model providers | Users can configure, test, and select local/BYOK model providers through a provider abstraction. |
| Backup, import, migration | Users can export and import local data through a versioned WideNote backup format, with migration/error handling. |
| Memory-first cards and insights | The app turns captures and Memory into source-linked cards and lightweight insights without adopting P.A.R.A as the core model. |
| Conversation system | The chat tab becomes a real local conversation surface with persistent messages and source-linked context from records/Memory/todos. |

## Out of Scope Unless Explicitly Reopened

- Copying MemeX code, schemas, prompts, migrations, or private data.
- Making P.A.R.A the core WideNote model.
- Requiring an account or official backend for core usage.
- Shipping community script execution before sandbox and permission rules are accepted.
- Requiring real model-provider calls in CI.

## Acceptance Gates

Every in-scope area must ship with:

- Unit tests for domain logic, persistence, migrations, and failure paths.
- Widget tests for every user-visible screen, state, dialog, button, gesture, empty/loading/error state, and localization path.
- At least one orchestration test that proves the cross-layer product loop:

```text
capture created
  -> event appended
  -> pack or local service matched
  -> Memory/card/insight/todo/conversation output created
  -> source link preserved
  -> trace or audit evidence available
```

- External review with Kimi when credentials/tooling are available. Review input must exclude secrets, raw private backup contents, API keys, and unpublished user records.
- Android emulator validation for high-risk mobile flows, using real taps and serialized emulator ownership.

## i18n Requirements

- Add a generated Flutter localization pipeline.
- Support `zh` and `en` at minimum.
- Persist the selected locale locally.
- Cover app shell, capture, Memory review, todos, provider settings, backup, cards/insights, and chat.
- Widget tests must pump at least zh and en app shells and one core flow in each locale.

## Model Provider Requirements

- Provider config must be stored without leaking secrets into logs, generated
  docs, automated review prompts, or test output. User-initiated backup JSON is
  intentionally secret-bearing and includes provider API keys.
- Package-level provider contracts should support fake, OpenAI-compatible, Anthropic-compatible, MIMO-compatible, and Kimi-compatible routing shapes.
- UI must support adding/editing/testing a provider and selecting a default provider.
- Unit tests use fake HTTP/model clients by default.
- Live-provider tests are opt-in and environment-driven.

## Backup, Import, and Migration Requirements

- Backup files must include a manifest with schema version, app version, created time, and record counts.
- Export/import must round-trip existing local data families first: captures, event log, Memory items/candidates, todos, and traces.
- Cards, insights, chat, and provider config must join the backup format as those modules land.
- Provider API keys are included in user-initiated backups for portability; the
  UI and docs must make the secret-bearing nature of backups explicit.
- Tests must cover successful round-trip, unsupported version, malformed payload, missing sections, and migration from older supported versions.

## Cards and Insights Requirements

- Cards and insights are derived views over raw captures and Memory; they do not overwrite original records.
- Every card and insight must keep source refs.
- First version should prioritize summary, action, Memory, todo, and trend/count cards.
- P.A.R.A labels may appear later as optional projections, not as the core data model.
- Tests must cover empty input, single capture, multiple captures, source links, and rendering.

## Conversation Requirements

- Chat must support persistent local sessions and messages.
- The assistant must answer from local context first and show which records/Memory/todos informed the answer.
- Empty context, failed model, and retry states must be visible and tested.
- Provider-backed chat may use the provider abstraction, but a deterministic local assistant path is required for tests and offline use.

## Subagent Coordination

Implementation should use subagents by durable ownership boundary:

- i18n foundation
- model provider settings
- backup/import/migration
- Memory-first cards and insights
- conversation system

The coordinator owns route integration, migration conflict resolution, Kimi review, Android emulator serialization, final validation, and final risk call.

## Open Questions

- Whether companion characters are required in phase one or should become a phase-two module.
- Whether real microphone recording and ASR provider integration should land in
  the next media slice or wait for Agent Pack audio permissions.
- Whether provider secrets should later move from the local DB into platform
  secure storage while preserving full user-managed backup/restore.
