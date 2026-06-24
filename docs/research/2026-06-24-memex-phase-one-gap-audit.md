# MemeX Phase-One Parity Gap Audit

Status: draft baseline

Date: 2026-06-24

Scope: heavier product and code gap audit for making WideNote phase one reach MemeX-like feature parity through clean-room behavior specs.

## Executive Verdict

WideNote is currently a solid local-first foundation, not yet a MemeX-parity product. The existing app proves the skeleton:

```text
text capture -> local event -> agent runtime -> memory candidate / todo / trace -> simple mobile UI
```

MemeX, by contrast, is already a full mobile journal product and local agent platform:

```text
text / photo / voice capture
  -> media and asset processing
  -> multi-agent knowledge extraction
  -> structured timeline cards
  -> insight cards, search, PKM, memory, chat, companion characters
  -> backup / restore / export / settings / app lock / provider management
```

If phase one means "only prove the WideNote architecture", the current roadmap is plausible. If phase one means "user-visible feature parity with MemeX", the phase-one scope must expand substantially and be treated as a parity release, not an MVP release.

Most important gaps:

- i18n is not implemented. WideNote has hardcoded UI strings and no Flutter localization pipeline.
- Capture is text-first. MemeX-parity requires text, photo, voice, attachments, asset safety, transcription, and share/import entrypoints.
- Timeline cards are missing as a durable product model. Current captures and memory records are not equivalent to MemeX cards.
- Knowledge, facts, cross-linking, search, insight cards, and PKM-like navigation are not implemented.
- Chat is a placeholder and does not yet have real memory-grounded assistant behavior.
- Companion characters, persona chat, auto-commentary, character memory, and Tavern import are absent.
- Custom Agent System is much narrower than MemeX: no custom agent authoring UI, no skill folder runtime, no JS execution, no async queue/retry, no dependency chains, no scoped working directory.
- Model provider settings are absent as a user-facing feature. Current live model use is a QA path, not BYOK product support.
- Backup / restore / Markdown export are absent.
- Privacy/security surfaces such as app lock, biometric auth, location context controls, and asset safety are absent.
- Emulator QA already proves the current narrow flow, but not MemeX-parity flows.

## Evidence Used

Reference sources:

- MemeX upstream GitHub repository and README, checked on 2026-06-24: <https://github.com/memex-lab/memex>.
- Local clean clone used for code inspection: `/tmp/memex-reference-1782264126`, `HEAD=68f18ef386422bbf4e8bad4d3a91e831d7650644`.
- User-provided MemeX backup: `/Users/guangmo/Downloads/memex_backup_2026-06-16T01-11-47-828425.memex`.
- WideNote workspace: `/Users/guangmo/.codex/worktrees/8a71/widenote`.
- Existing WideNote decisions and rules: ADR-0006, phase-one module plan, engineering rules, Android QA report.

Backup handling note:

- The backup was inspected structurally only. This report uses directory/table counts and feature-shape evidence. It does not quote private record contents or copy private prompts/data into WideNote.

Clean-room rule:

- Per ADR-0006, this report is a parity audit, not an instruction to copy MemeX code, schemas, migrations, prompts, private APIs, UI assets, or tests. Implementation subagents should work from WideNote-authored specs and tests.

## Current WideNote Baseline

Implemented or partially implemented:

- Flutter mobile shell with routes for home, chat, todos, and plugins.
- Local SQLite package with events, captures, memory items/candidates, todos, and traces.
- Local runtime kernel with in-process event dispatch, pack registration, permission checking, and traces.
- Official default and todo Agent Pack manifests as early contracts.
- Text capture orchestration and a deterministic fallback path when live model completion fails.
- Memory review surface and a simple todo path.
- QA-only MIMO model client path for live testing.
- Unit/widget tests for the current narrow loop.
- Android emulator QA report for the current app flow.

Not yet implemented as product-level parity:

- Durable card model, card detail pages, rich card rendering, media gallery, fact extraction, knowledge graph, insights, chat history, model settings, backup, export, i18n, app lock, custom agent authoring, skill runtime, JS execution, background queue, retry, and full provider matrix.

## MemeX Capability Map

The MemeX public surface and inspected code divide into these major modules:

| Area | MemeX user capability | MemeX code shape seen in inspection | WideNote parity implication |
| --- | --- | --- | --- |
| Capture | Text, photo, voice fragments | Input processing, media service, speech transcription, asset safety | WideNote needs capture ports for text/media/audio and raw-input preservation |
| Timeline cards | Structured cards for tasks, routines, events, metrics, quotes, people, places, galleries | Card repositories, renderers, card detail UI, timeline event publishing | WideNote needs `cards` schema/table/read model/UI, not only captures |
| Knowledge | P.A.R.A, facts, entity extraction, tags, cross-links | PKM/fact/tag repositories, search services, knowledge insight cards | WideNote needs a clean-room knowledge/fact/link model |
| Insights | Trend/bar/radar/bubble/composition/progress/map/route/timeline/gallery/summary cards | Insight card domain models and widgets | WideNote needs typed insight output and renderers |
| Chat | Assistant can discuss cards/topics | Super agent, chat services, chat history screens | WideNote chat must become grounded, persistent, and source-linked |
| Companion | Characters, auto-commentary, 1v1 chat, persistent character memory, SillyTavern import | companion/comment agents, character service, character memory, Tavern import UI | WideNote needs a companion module or explicit scope cut |
| Custom agents | User-created agents, triggers, prompts, per-agent models, skills, JS, working dirs, dependency chains, async/retry | custom agent configs, skill host agents, JS runtime, background coordinator, task handlers | WideNote runtime needs a larger execution platform |
| Providers | Gemini/OpenAI/Claude/Bedrock/Kimi/Qwen/Doubao/GLM/DeepSeek/MiniMax/MIMO/OpenRouter/Ollama | LLM client abstraction, model role config, model test service, settings UI | WideNote needs user-facing BYOK provider settings and adapter tests |
| Backup/export | iCloud/device/app storage, full backup/restore, Markdown export | backup service, filesystem service, storage settings | WideNote needs local file format, import/export service, restore validation |
| Privacy | Local-first, app lock, biometric auth, no account requirement | app lock UI/services, storage privacy choices, location context controls | WideNote needs app lock and explicit sensitive-context permission surfaces |
| i18n | `lib/l10n`, ARB files, generated localizations, locale settings | Flutter localization delegates and supported locales | WideNote needs first-class Flutter l10n |

## User-View Gap Matrix

Legend:

- `Current`: what a user can do in WideNote today.
- `Parity need`: what users would expect if phase one is benchmarked against MemeX.
- `Priority`: priority for a MemeX-parity phase-one release.

| User area | Current WideNote | MemeX-parity need | Priority | Acceptance shape |
| --- | --- | --- | --- | --- |
| Localization / i18n | No real i18n. UI strings are hardcoded. | At least zh/en generated Flutter localization, locale switch/persistence, tests for both locales. | P0 | Widget tests render core flows in zh and en; no hardcoded user-visible strings in new features. |
| First launch / setup | App opens into shell. No provider onboarding. | Local-first onboarding, optional provider setup, explain data stays local, allow skip. | P0 | Emulator first-run path covers skip and configure-provider flows. |
| Text capture | Works for current narrow flow. | Fast raw save, later async organization, error recovery, editing/deletion, traceability. | P0 | Unit/orchestration tests prove raw input survives model/runtime failures. |
| Photo capture | Not implemented. | Pick/camera/import images, preserve originals, gallery cards, safety checks. | P0 | Widget tests for attach/remove/preview; emulator taps image path; unit tests for asset metadata. |
| Voice capture | Not implemented. | Record/import audio, transcription provider, transcript review, raw audio preservation. | P0 | Fake transcription unit tests and emulator voice/import smoke; real provider opt-in tests. |
| Share/import entrypoints | Not implemented. | Android share intent and file import into capture. | P0 | Android emulator share-intent test and raw-input persistence proof. |
| Timeline | Current home list is a simple recent record view. | Chronological timeline with generated cards, filters, card detail navigation, update states. | P0 | Widget tests for empty/loading/error/card/detail/filter states. |
| Card types | No durable card model. | Task, routine, event, duration, progress, quote, snippet, link, conversation, person, place, metric, rating, transaction, spec sheet, gallery. | P0 | Clean-room card schema and renderer tests for each first-party card family. |
| Knowledge/facts | Memory exists, but no fact/entity/link graph. | Facts, entities, tags, cross-references, source-linked knowledge organization. | P0 | Unit tests for extraction output persistence, source links, conflict/revision handling. |
| Search | Not implemented as a user feature. | Search across records/cards/facts/chat with useful ranking and filters. | P0 | FTS/index unit tests and widget tests for search results/empty/error. |
| Insights | Not implemented. | Insight cards for trends, summaries, charts, maps/routes, timeline, gallery. | P0 for summaries/charts; P1 for maps/routes if location deferred. | Typed insight schema plus render tests for each supported card type. |
| Memory review | Basic review surface exists. | Full memory edit/delete/correction/revision, sensitive/conflict review, source backlinks. | P0 | Unit tests for auto-accept/review/tombstone; widget tests for edit/delete/revert. |
| Chat assistant | Placeholder. | Persistent assistant with chat history and source-grounded card/memory context. | P0 | Orchestration test: ask about prior capture -> answer cites stored source. |
| Companion characters | Absent. | Character creation, persona chat, auto-comments, character memory, import. | P0 if exact MemeX parity; P1 if phase one is staged. | Character service tests and widget tests for create/import/chat/comment. |
| Todos / schedule | Simple todo loop exists. | Todo, routine, schedule/calendar aggregation, stateful updates, card links. | P0 | End-to-end capture -> task/routine/card -> state update test. |
| Custom agents | Pack manifests exist; no user authoring. | Create agents, triggers, prompts, per-agent model, skills, dependency chains, async/retry. | P0 for parity platform; can be staged behind expert settings. | Runtime queue/dependency tests and settings widget tests. |
| Skill runtime | Not implemented. | SKILL.md folder loading, resource discovery, scoped file access, tool permissions. | P0 for custom agents. | Permission and sandbox tests; no private table dependency. |
| JS/tool execution | Not implemented. | Local JS execution with network/file permissions and audit traces. | P1 unless custom agents are P0. | Tool execution tests, timeout tests, permission denial tests. |
| Model providers | QA-only MIMO path. | BYOK settings for providers, model testing, per-agent role config, call logs. | P0 | Adapter contract tests; widget tests for provider setup; live opt-in test harness. |
| Backup/restore | Not implemented. | Full local backup/restore and one-click export to Markdown-like durable files. | P0 | Round-trip backup tests, corrupt/old-version restore tests, emulator import/export path. |
| Data freedom | Not implemented. | Human-readable exports with source records, cards, memory, chat, and attachments. | P0 | Export fixture diff tests and user-visible restore/export status. |
| App lock | Not implemented. | Biometric/PIN lock and secure settings. | P0 for privacy parity. | Widget/platform-abstraction tests; emulator lock/unlock where feasible. |
| Location context | Not implemented. | Explicit opt-in location context, provider config, freshness/granularity controls. | P1 unless place/map cards are P0. | Permission tests and settings widget tests. |
| Settings/debug | Plugin page has placeholders. | Real settings for provider, backup, model roles, packs, permissions, logs, traces, storage. | P0 | Widget tests for every settings panel and persistence unit tests. |

## Code-View Gap Matrix

| Code area | Current WideNote | Gap for MemeX parity | Proposed owner |
| --- | --- | --- | --- |
| `apps/mobile/lib/app/app_router.dart` | Four-tab shell only. | Need route graph for onboarding, settings, timeline, card detail, search, memory review, chat sessions, companion, backup/export, provider setup, custom agents. | `apps/mobile/navigation` |
| `apps/mobile/lib/app/*` | Bootstrap, current simple feature wiring, QA model client. | App directory will become too broad without feature modules. | Split into `features/*`, `platform/*`, `bootstrap/*`. |
| `apps/mobile/lib/features` | Mostly not present as durable feature modules. | Need feature folders with README, presenters, widgets, widget tests. | Mobile feature subagents |
| `packages/schemas` | Event, memory, permission, trace, agent pack. | Missing capture attachment, card, fact, link, insight, conversation, companion, backup, task queue, model provider config, search contracts. | Schema/contracts subagent |
| `packages/dart/local_db` | Events, captures, memory, candidates, todos, traces. | Missing attachment/card/fact/entity/link/insight/chat/character/provider/backup/permission/task queue/search tables and migrations. | Persistence subagent |
| `packages/dart/agent_runtime` | Synchronous dispatch and pack registry. | Needs task queue, dependency chains, async/retry, cancellation, background execution, tool registry, skill host, approval state, runtime recovery. | Runtime subagent |
| `packages/dart/model_providers` | Interface and fake adapter; app QA MIMO client outside package. | Needs OpenAI-compatible, Anthropic-compatible, MIMO/Kimi config, model testing, streaming/error taxonomy, per-agent role selection. | Provider subagent |
| `packages/dart/memory` | Early memory lifecycle. | Needs conflict handling, revision/tombstone APIs, source backlink graph, sensitive policy, review queries. | Memory subagent |
| `packages/dart/ui_blocks` | Structured UI rendering foundation. | Needs first-party card and insight renderers with stable UI contracts. | UI blocks/cards subagent |
| `packs/official/default` | Draft manifest. | Needs full default capture->knowledge->card->insight behavior spec and prompts authored for WideNote. | Pack/prompt subagent |
| `packs/official/todo` | Draft todo loop. | Needs schedule/routine state and card integration. | Todo/schedule subagent |
| `apps/api`, `apps/runner-ts`, `packages/ts/*` | Mostly boundary scaffolding. | Not required for local phase-one parity unless extension market/self-host runner is included. | Defer unless product scope requires. |
| Tests | Good for current skeleton. | Need many more unit/widget/orchestration/emulator tests, especially for full agent chain and UI states. | QA coordinator |
| Docs | Architecture and rules exist. | Need parity specs per module, i18n ADR/RFC, model-provider RFC, backup format RFC, custom-agent runtime RFC. | Docs/coordinator |

## i18n Finding

The user's suspicion is correct: WideNote does not currently have real i18n.

Evidence in WideNote:

- No `l10n.yaml` was found at repo/app level.
- `apps/mobile/pubspec.yaml` does not include `flutter_localizations` or `intl`.
- `WideNoteApp` uses `MaterialApp.router` without `locale`, `supportedLocales`, or localization delegates.
- User-visible strings are embedded directly in widgets, including tab labels and page content.
- Existing docs mention future `l10n/`, but code has not implemented it.

MemeX comparison:

- MemeX has `lib/l10n`, ARB files, generated localization files, `l10n.yaml`, supported language definitions, locale persistence, and localization delegates wired into `MaterialApp`.

Phase-one parity requirement:

- Add Flutter generated localization pipeline under `apps/mobile/lib/l10n`.
- Add `flutter_localizations` and `intl`.
- Support at least `en` and `zh` from the start. Add other languages only after string ownership is stable.
- Introduce a `LocaleController` or settings-backed locale provider.
- Replace hardcoded strings in all user-visible mobile screens touched by phase-one parity work.
- Require widget tests for zh/en render paths, navigation labels, empty states, dialogs, errors, and settings panels.

Recommended i18n acceptance test:

```text
launch app in zh
  -> bottom tabs render Chinese
  -> capture text flow succeeds
  -> memory review labels render Chinese
switch to en
  -> same route tree renders English
  -> no stale Chinese text remains in core controls
```

## Backup Shape Gap

The inspected `.memex` backup shows that MemeX has a mature exportable workspace shape:

```text
workspace/
  Cards/
  Facts/
  KnowledgeInsights/
  PKM/
  ChatSessions/
  ScheduleAggregations/
  Characters/
  Schedule/
  _System/
    EventLogs/
    llm_calls/
    state_dir/
    character_memory/
    memory/
db/
settings.json
manifest.json
```

Aggregated counts from the provided backup:

| Area | Count |
| --- | ---: |
| Total files | 3955 |
| Uncompressed bytes | 263,953,914 |
| `workspace/_System` | 3139 |
| `workspace/Cards` | 592 |
| `workspace/Facts` | 101 |
| `workspace/KnowledgeInsights` | 43 |
| `workspace/PKM` | 35 |
| `workspace/ChatSessions` | 22 |
| `workspace/ScheduleAggregations` | 11 |
| `workspace/Characters` | 6 |
| `workspace/Schedule` | 1 |

WideNote has no equivalent backup/export contract yet. If phase one is MemeX parity, the backup format cannot be an afterthought. It should become a public-ish local contract with a round-trip test suite.

Minimum WideNote backup contract:

- `manifest.json` with app/schema/version/platform/export timestamp.
- Raw captures and attachments preserved.
- Cards, memory, facts, conversations, todos/schedule, insight outputs, model/provider non-secret settings, pack installation metadata, and trace summaries.
- Secrets excluded by default; import should ask for provider keys again.
- One-click full backup/restore.
- Markdown or human-readable export for records/cards/memory where possible.
- Corrupt, partial, old-version, and missing-attachment restore tests.

## Phase-One Parity Module Plan

This is the heavier module split I would use for subagents. It keeps Android emulator access serialized while allowing code work in parallel.

### Track 0: Product Parity Spec and Architecture Gates

Write scopes:

- `docs/research/`
- `docs/rfcs/`
- `docs/decisions/`
- `docs/architecture/`

Deliverables:

- Clean-room user-flow specs for capture, cards, memory, chat, companion, providers, backup, and custom agents.
- ADR/RFC updates for i18n, backup format, model provider settings, card/fact/insight contracts, custom agent runtime.
- Updated phase-one module plan that says explicitly whether companion/custom agents/maps are in phase one or staged.

Tests:

- Docs link checks and schema reference checks where tooling exists.

### Track 1: i18n and Navigation Foundation

Write scopes:

- `apps/mobile/lib/l10n/`
- `apps/mobile/lib/navigation/`
- `apps/mobile/lib/app/`
- `apps/mobile/test/`

Deliverables:

- Flutter localization pipeline.
- Locale settings and persistence.
- Route graph for parity screens, even if some screens start with intentional empty states.
- Feature module route registration convention.

Tests:

- Widget tests for zh/en app shell, route labels, empty states, and locale switch.

### Track 2: Capture, Media, and Raw Record Preservation

Write scopes:

- `apps/mobile/lib/features/capture/`
- `apps/mobile/lib/platform/{camera,audio,files,share}/`
- `packages/schemas/src/capture*`
- `packages/dart/local_db`

Deliverables:

- Text/photo/voice/file capture contracts.
- Raw capture and attachment tables.
- Media metadata and safety result model.
- Share/import entrypoints.

Tests:

- Unit tests for persistence, MIME/metadata handling, safety decisions.
- Widget tests for attach/remove/preview/recording states.
- Emulator tests for repeated capture and media edge cases.

### Track 3: Cards, Timeline, and UI Blocks

Write scopes:

- `packages/schemas/src/card*`
- `packages/dart/local_db`
- `packages/dart/ui_blocks`
- `apps/mobile/lib/features/{timeline,cards}/`

Deliverables:

- Clean-room card schema and renderer contract.
- Timeline read model.
- Card detail pages.
- First-party card family renderers.

Tests:

- Unit tests for card persistence and migrations.
- Widget tests for every first-party renderer, card detail, timeline filters, and empty/error states.

### Track 4: Knowledge, Memory, Search, and Insights

Write scopes:

- `packages/schemas/src/{fact,link,insight,search}*`
- `packages/dart/{memory,local_db}`
- `apps/mobile/lib/features/{memory,knowledge,insights,search}/`
- `packs/official/default`

Deliverables:

- Fact/entity/link model.
- Source-linked memory revision and tombstone APIs.
- FTS/search service.
- Typed insight cards and summary/chart renderers.

Tests:

- Full chain deterministic orchestration test:

```text
capture created
  -> event appended
  -> pack subscription matched
  -> model/tool fake returns facts
  -> Memory auto-accepted or queued for review
  -> card created
  -> insight output emitted
  -> trace contains the run
```

- Widget tests for memory edit/delete/review, search results, insight renderers.

### Track 5: Chat, Companion, and Character Memory

Write scopes:

- `packages/schemas/src/{conversation,companion,character}*`
- `packages/dart/local_db`
- `apps/mobile/lib/features/{chat,companions}/`
- `packs/official/companion` if added

Deliverables:

- Persistent chat sessions.
- Memory-grounded assistant context.
- Character profile/persona model.
- Auto-commentary event hooks.
- Optional Tavern import format support if parity is strict.

Tests:

- Unit tests for conversation persistence and context assembly.
- Widget tests for chat send/retry/history, character create/edit/import.
- Orchestration tests for card-created -> character comment.

### Track 6: Model Providers and Per-Agent Model Roles

Write scopes:

- `packages/dart/model_providers`
- `packages/schemas/src/model_provider*`
- `apps/mobile/lib/features/model_providers/`
- `apps/mobile/lib/features/settings/`

Deliverables:

- Provider config model.
- OpenAI-compatible and Anthropic-compatible adapters.
- MIMO and Kimi routing through provider abstraction.
- Model test service.
- Per-agent model role configuration.
- LLM call log metadata without secrets.

Tests:

- Adapter contract tests with fake HTTP.
- Error taxonomy tests.
- Widget tests for provider setup/test/edit/delete.
- Live opt-in tests using environment-provided keys only.

### Track 7: Custom Agent Runtime and Skills

Write scopes:

- `packages/dart/agent_runtime`
- `packages/schemas/src/{task,tool,skill,agent_config}*`
- `apps/mobile/lib/features/{packs,custom_agents,permissions,traces}/`
- `tools/pack_validator`

Deliverables:

- Task queue and background runner.
- Dependency chains.
- Async/retry/cancellation.
- Scoped tool permissions and approval UI.
- Skill folder discovery for `SKILL.md`.
- Scoped working directories.
- JS execution only if approved for parity release.

Tests:

- Unit tests for task queue, retry, dependency order, cancellation, permission denial.
- Widget tests for approval prompts, custom agent editor, trace console.
- Orchestration tests for multi-agent chains with deterministic fake tools.

### Track 8: Backup, Export, Privacy, and Settings

Write scopes:

- `packages/schemas/src/backup*`
- `packages/dart/local_db`
- `apps/mobile/lib/features/{backup_export,privacy_lock,settings,location}/`
- `apps/mobile/lib/platform/{secure_storage,biometrics,location}/`

Deliverables:

- Backup/restore service.
- Markdown/human-readable export.
- App lock abstraction and UI.
- Location context settings if place/map cards are included.
- Real settings home replacing plugin placeholders.

Tests:

- Backup round-trip tests.
- Old/corrupt/missing file restore tests.
- Widget tests for settings panels.
- Platform abstraction tests for lock/location behavior.

### Track 9: Android Emulator QA Lane

Only one owner at a time.

Deliverables:

- Serialized emulator run plan.
- Real tap tests, not only widget tests.
- Repeated cases per scenario. The user requested at least 10 rounds for each important scene.
- Live model-key tests for LLM flows when credentials are available, with secrets kept out of files/logs.
- Final QA report under `docs/research/`.

Required scenario families:

- First launch and locale switch.
- Provider setup and model test.
- Text capture 10x.
- Photo capture 10x.
- Voice/transcription 10x where platform setup permits.
- Blank/invalid/long/multilingual capture 10x.
- Timeline/card detail/card edit/delete.
- Memory review/edit/delete/revert.
- Chat asks about stored records.
- Todo/schedule update.
- Companion comment/chat if in phase one.
- Backup/export/restore dry run.
- Permission denial and retry paths.

## Testing Bar

For parity work, the test bar must be stricter than the current skeleton.

Unit tests:

- Schema validators and migrations.
- DAO round-trips and transaction boundaries.
- Runtime event dispatch, queue, retry, dependency ordering, cancellation.
- Permission checks and denial paths.
- Model provider adapter success, timeout, rate limit, malformed response, auth failure.
- Memory confidence, conflict, sensitivity, tombstone, revision.
- Backup export/import, version migration, corrupt archive handling.
- Search indexing and ranking.

Widget tests:

- Every UI-visible change.
- Navigation, dialogs/sheets, buttons, gestures, empty/loading/error states.
- i18n zh/en.
- Capture media states.
- Timeline/card renderer states.
- Memory review.
- Chat/companion.
- Settings/provider/backup/privacy panels.

Orchestration tests:

- Capture -> event -> agent chain -> memory -> card -> insight/todo -> trace.
- Model failure -> raw record remains -> retry available.
- Permission required -> approval UI -> resumed task.
- Backup restore -> app read models hydrate.

Android emulator tests:

- Real taps and text entry.
- Serialized emulator ownership.
- Repeated scenarios, at least 10 rounds for major flows.
- Live model-key scenarios outside CI.
- Screenshots, logcat snippets, and final report.

## Complexity and File-Size Rules to Preserve

The existing engineering rules remain appropriate and should be enforced harder as parity work grows:

- Production source file: `<= 800` lines, excluding generated files.
- Function/method: `<= 40` lines by default, `<= 60` only with clear extraction cost.
- Widget build method: `<= 80` lines.
- One primary responsibility per class.
- `<= 3` control-flow nesting levels.
- Every durable module/package needs a `README.md`.
- Generated files must document source of truth and generation command.
- Public runtime contracts belong in `packages/schemas`, not app-private tables.

Additional parity-specific rules:

- No feature subagent may add a new user-visible route without widget tests.
- No new runtime event type may be app-private if an Agent Pack can observe it.
- No model/provider code may log API keys, prompts containing private records, or raw backup data.
- No custom agent feature may ship without a permission-denial test.
- No backup format may ship without restore tests.
- No media feature may ship without raw-file preservation tests.

## Product Scope Decision Needed

There is one major product decision to make before implementation fan-out:

```text
Does "phase one" mean:
  A. WideNote architecture-complete MVP with selected MemeX-like flows,
  or
  B. user-visible MemeX parity release?
```

The user's latest direction points to B. Under B, phase one must include at least:

- i18n.
- Text/photo/voice capture.
- Timeline cards and detail views.
- Memory review/edit/delete with source links.
- Facts/entities/tags/search/cross-links.
- Insight cards.
- Persistent chat grounded in records.
- Todos/schedule/routine flow.
- Model provider settings with MIMO/Kimi-capable routing and per-agent roles.
- Backup/restore/export.
- App lock/privacy settings.
- Custom agent system with user-created agents, triggers, prompts, per-agent model config, permissions, and trace visibility.
- Companion/character features unless explicitly deferred with a product note.

If companion/custom-agent JS execution/maps are too large for the first public build, they should be formally staged in an RFC instead of silently omitted.

## Recommended Immediate Next Steps

1. Update phase-one docs from "narrow MVP" to "parity release" or explicitly define a smaller milestone.
2. Create RFCs for i18n, cards/facts/insights, provider settings, backup format, custom agent runtime, and companion scope.
3. Split implementation into the tracks above with disjoint write scopes.
4. Start with Track 1 and Track 2, because every other user-facing parity feature depends on localization, navigation, capture, and durable attachments.
5. Keep Track 9 as a coordinator-owned serialized lane; no other subagent should touch the emulator while a scenario run is active.

## Gap Summary

WideNote's current architecture direction is compatible with MemeX parity, but the implemented product surface is much smaller. The biggest risk is not a single missing feature. It is allowing the phase-one plan to keep MVP language while the acceptance target is MemeX parity. The plan should be renamed or expanded now, before parallel subagents begin implementation.
