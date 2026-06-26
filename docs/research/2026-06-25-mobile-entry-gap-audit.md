# Mobile Entry Gap Audit Against Memex

Status: superseded by the W7 phase-one integration cleanup.

Current implementation notes live in:

- `docs/research/2026-06-26-w7-current-integration-state.md`
- `docs/research/2026-06-26-w7-integration-qa.md`
- `docs/research/2026-06-26-phase-one-acceptance-matrix.md`

This file is retained as historical gap evidence only. Do not use it as the
current route or implementation inventory.

Date: 2026-06-25

Scope: user-visible mobile app entries in `apps/mobile`, checked against the
current public `memex-lab/memex` repository through a clean-room capability
comparison.

## Evidence Used

- WideNote workspace: `/Users/guangmo/.codex/worktrees/73a0/widenote`.
- Memex public repository: <https://github.com/memex-lab/memex>.
- Local Memex reference clone: `/tmp/memex-reference`, `HEAD=9950534`.
- WideNote context docs: `docs/agent-context/START_HERE.md`,
  `docs/decisions/index.md`, `docs/rfcs/phase-one-product-scope.md`,
  `docs/decisions/0006-use-clean-room-parity-specs.md`.
- Prior WideNote parity docs:
  `docs/research/2026-06-24-memex-phase-one-gap-audit.md`,
  `docs/research/2026-06-24-external-review-round-gap-closeout.md`, and
  `docs/research/2026-06-24-android-followup-qa.md`.

Clean-room rule: this report compares public capability shape and user flows.
It is not an instruction to copy Memex code, schemas, prompts, migrations,
private APIs, UI assets, or tests.

## Current WideNote Route Graph

WideNote currently exposes these app routes:

- Bottom tabs: `/`, `/chat`, `/todos`, `/plugins`.
- Home secondary routes: `/recap`, `/timeline`, `/timeline/search`,
  `/timeline/cards/:cardId`, `/timeline/items/:itemId`, `/memory`,
  `/settings`, `/settings/permissions`, `/settings/model-providers`,
  `/settings/backup`, `/settings/traces`.
- Plugin routes: `/plugins/packs`, `/plugins/permissions`,
  `/plugins/model-providers`, `/plugins/backup`, `/plugins/traces`.

The route graph does not yet include onboarding, locale switch, privacy lock,
knowledge/files, companion characters, custom agent authoring,
schedule/calendar, app-action quick note, system share import, clipboard import,
or broad file import. Camera, gallery, and microphone capture use platform
adapters; deterministic fake adapters remain test-only.

## Entry Inventory

| Entry | Current state | Evidence | Main gap | Priority |
| --- | --- | --- | --- | --- |
| Home capture console | Real phase-one feature | `HomePage` wires text submit, camera, gallery, microphone recording, attachment safety review, and local persistence through platform adapters. | System share, clipboard import, broad file import, transcription provider routing, and persisted draft are still future slices. | P1 |
| Capture processing pipeline | Real narrow loop | `CaptureOrchestrator` publishes `wn.capture.created`, runs default and todo packs, writes Memory proposal, todo, cards, insights, and traces. | The loop is synchronous and local. It has no durable background queue, dependency graph, cancellation, retry UI, or approval resume. | P0 for reliability, P1 for full custom-agent parity |
| Memory review on Home | Real phase-one feature | Home shows review candidates and supports accept, edit, reject; `/memory` supports list/search/edit/tombstone/restore. | Sensitivity controls, richer revision history, and advanced source management remain future slices. | P1 |
| Home cards and insights sections | Real lightweight feature | Home renders source-linked card and insight rows backed by local read models. | Card/insight families are lightweight summaries, not rich Memex-like renderers or typed visual insight views. | P1 |
| Timeline | Real phase-one feature | `/timeline` loads local captures, cards, insights, Memory, and todos, with search and item/card detail pages. | Date/tag filters, edit/delete actions, and richer media/gallery details remain future slices. | P1 |
| Timeline search | Partial real feature | `/timeline/search` filters local timeline items. | It is a client-side browse-index search, not full FTS across raw records, cards, Memory, chat, facts, and attachments. Insight is not exposed in the visible filter list. | P0 |
| Card detail | Real phase-one feature | `/timeline/cards/:cardId` shows card body, source refs, related records, Memory, and todos, and source rows navigate to detail pages. | No edit/delete/share/comment/media-gallery actions. | P1 |
| Chat tab | Real baseline | Chat has persistent local sessions/messages, source selection, retry states, deterministic offline assistant, optional model-backed answers, and clickable source drill-down. | It is source-grounded Q&A, not companion chat. No character persona, auto-commentary, character memory, or chat management. | P1 |
| Todos tab | Real baseline | Todo rows can be completed, completed rows hide from the main tab, and source tags open source detail. | No edit/delete/restore/schedule or completed archive UI. | P1 |
| Plugins tab | Real phase-one controls | Pack Library, Permission Gate, Model Provider, Backup, and Trace Console rows all navigate to real local control pages. | No custom agent editor, remote marketplace install flow, or community pack execution. | P1 |
| Model providers | Real baseline | Users can add, edit, delete, set default, test providers, and refresh runtime clients without app restart. Supported kinds include OpenAI-compatible, Anthropic-compatible, MIMO, and Kimi. | No per-agent model roles, OAuth flows, provider call logs, or large provider matrix. Live connection tests are gated behind `WIDENOTE_LIVE_PROVIDER_TESTS`. | P1 |
| Backup | Real baseline, developer-shaped UX | Backup can export JSON, export readable Markdown, copy both, and import pasted JSON. | No system file picker/save/share, external backup intent, storage location selection, auto-backup, conflict resolution UI, or attachment file restore UX. | P0 |
| Trace console | Real read-only baseline | `/plugins/traces` reads `trace_events`, shows counts, warnings, and rows. | No run detail, filtering, search, retry/cancel controls, LLM call redaction view, or task queue status. | P1 |
| App shell and settings | Real baseline | The app has generated zh/en localization, localized bottom nav, top-right Settings, and settings child routes for permissions/providers/backup/traces. | No in-app locale switch, onboarding, user/profile center, storage controls, or app lock. | P1 |
| External mobile entrypoints | Missing | No quick action, deep link quick note, share intent handler, clipboard preview, or file import intent appears in WideNote mobile. | High-frequency mobile capture still depends on opening the app manually and typing/picking fake attachments. | P0 |
| Knowledge and facts | Missing as product surface | Memory-first cards exist, but no knowledge/files/facts/entities/tags UI. | No fact graph, entity/tag browsing, source-linked knowledge pages, or FTS-backed knowledge search. | P0/P1 depending phase-one strictness |
| Rich insights | Missing as product surface | Insights exist as lightweight generated records. | No dedicated insight tab/page, charts, maps/routes, gallery, periodic reviews, pin/delete/sort, or detail pages. | P1 unless strict parity |
| Companion characters | Missing | No routes or features for characters, persona chat, auto-comments, character memory, or Tavern import. | Memex treats companion as a major product pillar; WideNote needs either a scoped module or an explicit phase cut. | P1 unless strict parity |
| Custom agents and skills | Mostly contract scaffolding | Pack manifests and runtime kernel exist. | No user-created agents, trigger editor, prompt editor, `SKILL.md` runtime, scoped working directory, JS tool execution, dependency chains, or async retry controls. | P1, with sandbox/permission ADR first |
| Privacy lock and sensitive context | Missing | No app lock, biometric/PIN abstraction, location context settings, or sensitive-source permission panel. | Memex has app lock and explicit settings around sensitive integrations. WideNote needs these before high-risk sources. | P0 for app lock, P1 for location |

## Memex Reference Shape

Memex is useful as a public capability reference because its user flow connects
mobile entrypoints to durable outputs:

```text
text / photo / voice / share / clipboard / quick action
  -> raw record and media preservation
  -> local event and task execution
  -> structured timeline card
  -> card detail, comments, attachments, Memory, knowledge, insight, schedule,
     chat, companion, settings, backup, and agent activity surfaces
```

The most important lesson for WideNote is not to add every Memex screen at once.
It is to avoid visible entries that do not complete a user outcome. Each entry
should have an owner, a local data contract, visible empty/loading/error states,
source links back to raw capture, and a test that proves the route works from a
real app gesture.

## Recommended Implementation Order

1. Capture entrypoints: platform camera, gallery, and microphone adapters now
   exist; future work is share/clipboard/file import and transcription routing.
2. Timeline completeness: add detail routes for capture, Memory, todo, and
   insight items, and make source refs clickable from timeline, chat, and card
   detail.
3. Todos and Memory actions: make todo rows actionable, add Memory list/edit/
   delete/revision behavior, and preserve source links for every state change.
4. Settings center: replace the plugin-style control list with a real settings
   home that owns provider setup, backup, traces, locale, permissions, privacy,
   and storage.
5. Backup UX: keep the current JSON/Markdown services, then add file save/open,
   external restore confirmation, import conflict handling, and emulator tests.
6. Agent runtime hardening: add task queue, retry/cancel, run detail, and
   approval resume before opening custom agent authoring or script execution.
7. Product-scope decision: decide whether companion characters, rich insights,
   knowledge graph, location context, and custom Agent Packs are phase-one
   parity or explicit phase-two modules.

## Immediate Cleanup Candidates

- Do not present Pack Library and Permission Gate as control rows until they
  navigate to real views or are clearly scoped as status-only internals.
- Either make the Todos checkbox functional or render suggested todos without a
  disabled completion affordance.
- In card detail related sections, remove the no-op row opener or wire it to
  real detail routes.
- Reword model provider testing so offline validation is not mistaken for a
  live provider call when `WIDENOTE_LIVE_PROVIDER_TESTS` is off.
- Move Timeline hardcoded strings into localization before expanding the route.

## Test Bar For Each Entry

Every user-visible entry should have:

- Unit tests for persistence, migration, and failure paths.
- Widget tests for empty, loading, error, permission denied, retry, and success
  states.
- At least one orchestration test that proves source links survive:

```text
user gesture
  -> raw capture or user action persisted
  -> event appended
  -> pack/service matched
  -> derived output created
  -> UI route displays output
  -> source link opens or identifies the original record
  -> trace/audit evidence exists
```

- Android emulator validation for platform entrypoints such as share intents,
  quick actions, file picker/import, camera/gallery, microphone, app lock, and
  backup restore.
