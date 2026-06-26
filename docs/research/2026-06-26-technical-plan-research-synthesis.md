# WideNote Technical Plan Research Synthesis

Status: confirmed framework synthesis
Date: 2026-06-26
Scope: research synthesis before detailed technical planning; no implementation

## Purpose

This document prepares the coarse technical-plan decisions for WideNote's new
mobile product shape. It is intentionally coarse-to-fine:

1. Long-lived product/runtime framework decisions for the user to confirm.
2. Research-backed architecture principles from reference implementations and
   industry sources.
3. Implementation details that can be decided by the engineering agent after
   the coarse framework is accepted.

This is not yet an implementation plan and does not define final schemas,
database tables, APIs, package boundaries, or Flutter widgets.

## Confirmation Status

The coarse framework in this note was reviewed with the product owner on
2026-06-26 and accepted as the basis for the next detailed technical-plan
draft. Kimi CLI then performed an external read-only review and returned a
"Go, with conditions" result. The conditions were resolved into ADR-0009 and the
Kimi review note. The remaining work is to turn this framework into concrete
object boundaries, lifecycle diagrams, schema/storage proposals, Agent Pack
boundaries, UI read models, and validation gates.

## Current Accepted Product Direction

- Home is a daily return surface, not a full infinite card feed.
- Home shows daily recap, recent 2-3 records, and a bottom Compose Sheet.
- Full records/card stream remains available as a secondary page.
- Insight is a home-level secondary page, not a fifth bottom tab.
- Capture starts from a bottom Compose Sheet.
- Phase-one capture inputs are typed text, audio recording, camera capture, and
  photo library selection.
- File picker, share sheet, bulk import, external vault import, and broad
  cross-app ingestion are deferred.
- Raw captures use SQLite/Drift object truth plus source files for attachments;
  Markdown is export/developer/debug projection, not phase-one canonical
  storage.
- AI progressive disclosure uses generated context packets/read models:
  summary first, then source refs, then raw excerpts, then attachments only when
  allowed.
- Context packets are generated read models. Important packets may be cached as
  rebuildable SQLite state and invalidated by source/version/policy/generator
  inputs.
- Backup and Owner Export are separate: full restorable Backup includes
  provider/model configs, selected defaults, pack state, settings, and
  credentials/secrets; Owner Export is portable and excludes secrets by default.
- SQLite object tables are canonical current state. Append-only events are
  audit/routing/idempotency evidence, not full event-sourced truth.
- Default deletion is soft delete with a 30-day recoverable window, followed by
  purge that removes content and leaves minimal tombstone metadata.
- Memory is silent by default. Low-risk Memory auto-accepts; review is for
  conflict, sensitivity, low confidence, or unclear policy.
- Default Agent Pack excludes Todo.
- Todo is a separate extension pack and first-level app tab.
- Conversation starts as a unified list and uses progressive context retrieval.
- Plugins tab is marketplace / installed Agent Packs. Settings move to the
  top-right.

## User-Level Coarse Decisions To Confirm

These decisions have long-term product/runtime impact and should be confirmed
before detailed technical planning.

| ID | Decision | Recommended Direction | Why It Matters |
| --- | --- | --- | --- |
| D1 | Source of truth | Raw captures and source files are canonical; cards, insights, Memory proposals, todos, summaries, embeddings, and indexes are derived | Protects local-first ownership, backup, and regeneration |
| D2 | Default pack scope | `official/default` handles summary/card, Memory policy, lightweight insight, rolling/final daily recap; Todo is `official/todo` | Keeps core product record-memory-insight, not a task app |
| D3 | Agent timing | Hybrid: immediate lightweight processing, rolling daytime recap, evening/deeper jobs, on-demand conversation | Balances feedback, cost, latency, and depth |
| D4 | Conversation retrieval | Progressive disclosure through generated context packets: current context -> accepted Memory -> derived summaries/cards/recaps -> targeted raw records -> attachments | Keeps answers fast and grounded without flooding context |
| D5 | Runtime model | Event-driven local runtime with append-only events, durable tasks, idempotent handlers, permission-gated tools, and traces | Avoids fragile one-shot model calls and duplicated side effects |
| D6 | File model | Immediate media inputs are first-class source material; broad import workflows are deferred | Keeps phase one focused while preserving future portability |
| D7 | Plugin model | Agent Packs declare capabilities, permissions, outputs, and source access up front; high-risk capabilities require explicit review | Makes ecosystem extensible without hidden data access |
| D8 | Trace visibility | User-facing status is simple; detailed traces live in advanced settings | Builds trust without making the app feel like a debugger |

## Proposed Runtime Flow

```text
Compose input
  -> raw capture saved locally
  -> source files stored as source material
  -> capture.created event appended
  -> default pack subscriptions matched
  -> immediate lightweight run
      -> summary/card
      -> Memory candidate + policy evaluation
      -> basic conversation context
  -> rolling daytime jobs
      -> daily recap draft
      -> lightweight topic groups / insights
  -> evening or periodic jobs
      -> stable daily recap
      -> deeper insights
      -> Memory cleanup / conflict checks
  -> on-demand conversation
      -> progressive retrieval
      -> sourced answer
  -> trace/audit available
```

## Reference Implementation Findings

### Memex

Memex is most useful as a source-material, event-chain, and split-agent
reference.

Useful patterns:

- Source material is layered: original text, image, audio, generated analysis,
  card fact, insight, and Memory-like outputs are not treated as the same thing.
- Capture work flows into background processing and later consumers instead of
  making the UI own all processing state.
- Recent split / memory-primary direction supports demoting PKM/PARA to a
  projection and making Memory/source-linked records the main context layer.
- Retrieval should be source-grounded and explainable. Lexical/FTS + recency /
  entity signals are a better phase-one default than promising vector search as
  the main path.
- Agent responsibilities should be split into bounded roles with explicit
  read/write capabilities.

Avoid copying:

- A single large SuperAgent prompt that implicitly owns every workflow.
- PKM/PARA/Markdown as the core data model.
- Raw file tools directly mutating canonical product data.
- Treating AI comments, insights, recaps, or cards as original user facts.
- Making vector/hybrid retrieval the phase-one correctness claim before a
  controlled evaluation exists.

WideNote adaptation:

```text
capture.created
  -> pack subscriptions
  -> durable local task queue
  -> bounded handler / agent role
  -> output events
  -> trace
```

### Omi

Omi is most useful as an object-layering and detail-experience reference.

Useful patterns:

- Conversation is the source object; summary, transcript, action items, app
  results, and memories/facts are views or derived outputs.
- Conversation detail separates Summary, Transcript, and Action Items instead
  of flattening them into one screen.
- Daily Summary is a durable daily object, not just a home rendering trick.
- Apps are capability-based extensions with triggers, webhooks, chat tools, and
  memory/conversation/task access.

Avoid copying:

- Cloud/backend as the required brain for core use.
- Always-on or wearable-first audio capture as the default.
- Todo as a default home concern.
- Broad plugin permissions such as reading all conversations, memories, tasks,
  transcripts, or raw audio.
- A public marketplace/payments/reviews surface before local official packs are
  stable.

WideNote adaptation:

```text
Record detail:
  Summary/Card first
  -> Source/transcript/OCR evidence
  -> Optional actions from enabled packs

Daily Recap:
  versioned derived object
  -> overview / highlights / decisions / open questions / knowledge nuggets
  -> source_refs
```

## Industry Best-Practice Findings

### Local-first

WideNote should treat local data as the canonical user-owned copy. Cloud,
runner, and sync are enhancement layers, not requirements for core use.

Recommended layers:

```text
Canonical:
  raw captures
  source materials / attachments
  append-only events
  accepted Memory

Derived:
  cards
  summaries
  insights
  daily recaps
  todos
  conversation answers

Rebuildable:
  FTS
  vector indexes
  thumbnails
  cache
  projections / exports
```

### Runtime

Use an event-driven local runtime:

- Capture write, event append, and local task enqueue should be transactionally
  tied together.
- Delivery should be at-least-once.
- Handlers must be idempotent.
- Task identity should include event id, subscription id, pack id/version, and
  handler role.
- Output should be written as new events or derived objects, never by mutating
  raw capture content.
- Trace should cover agent run, model call, tool call, permission decision,
  output event, and review action.

### Memory and Retrieval

Conversation should use progressive context disclosure:

```text
current turn/app context
  -> accepted Memory
  -> derived summaries/cards/recaps/insights
  -> targeted raw captures/transcripts/OCR/source excerpts
  -> attachments only when needed and allowed
```

Memory is the durable semantic layer. Summaries/cards/recaps are routing and
explanation layers. Raw captures and attachments are the evidence layer.

### Mobile Privacy

Phase-one capture should request permissions at the moment of action:

- Ask microphone permission when the user starts recording.
- Ask camera permission when the user opens camera capture.
- Use system photo picker / limited photo access for photo library selection.
- Do not request broad file, media library, background audio, notification,
  screen, health, SMS, location, or calendar access in the default flow.

### Agent Pack Permissions

Packs should declare capabilities before installation or first use:

- events they subscribe to
- data layers they read
- objects they write
- model/network use
- background behavior
- high-risk source access
- revocation behavior

Default official packs should use narrow permissions. Community/script/remote
packs require a later sandbox and permission RFC.

## Progressive Retrieval Policy

Conversation and agent context should expand only as needed:

```text
1. Current user turn and visible app context
2. Accepted Memory
3. Derived summaries: recent cards, daily recaps, lightweight insights
4. Targeted raw records: captures, transcripts, OCR text, source excerpts
5. Attachment expansion: audio/image/source files only when needed and allowed
```

This policy keeps Memory as the compact durable context layer while preserving
raw source material for audit and deeper answers.

## Details The Agent Can Decide Later

These should not block the user-level framework decision:

- Exact internal naming: `record`, `capture`, `entry`, or `record bundle`.
- Concrete schema fields and migration steps.
- SQLite table shape and indexes.
- Package/file layout.
- Flutter widget decomposition.
- Whether the first card renderer is template-driven or generated from a small
  set of built-in card types.
- Exact retry intervals, queue lease durations, and backoff policy.
- Trace table field names and UI labels.
- Test fixture names and fake model implementation shape.

## Recommended Coarse Framework

The recommended framework for user confirmation is:

```text
Local-first source layer
  raw captures
  source materials / attachments
  append-only events

Runtime layer
  local task queue / outbox
  Agent Pack subscriptions
  permission broker
  model/tool adapters
  trace/audit

Semantic layer
  accepted Memory
  Memory candidates and policy

Derived object layer
  cards
  daily recaps
  insights
  todos from optional pack
  conversation answers

UI read-model layer
  Home Today
  Home Insights
  Home Records
  Chat
  Todos
  Plugins
  Settings
```

## Confirmed Framework Answers

The research suggested these coarse framework questions. The current answers
are accepted for the next technical-plan draft:

1. Should Compose submit directly create `capture.created`, with no
   SuperAgent-like coordinator in the Home capture path?
   - Confirmed: yes. Keep coordination in Conversation, not Home capture.
2. Should Daily Recap be one recap agent with rolling/final trigger modes, or
   two separate handlers?
   - Confirmed: one recap role with two trigger modes for phase one.
3. Should Todo be default-installed but disabled, or installed only when the
   user enables Todos?
   - Confirmed: official Todo pack exists, but default pack does not emit
   todos. The Todos tab can invite enabling it.
4. Should plugin naming be Apps, Extensions, Agent Packs, or Plugins?
   - Confirmed: user-facing tab can stay Plugins; technical and
   marketplace object should be Agent Pack.
5. Should record/detail source references show only record/card first, or allow
   expansion to transcript/OCR/source excerpts?
   - Confirmed: show record/card first, expandable to transcript/OCR/source
   excerpts, and only then attachments.
6. Should Chat be allowed to propose Memory?
   - Confirmed: yes, but only through the same Memory policy path as the
   default pack.

## Next Technical Plan Sections

Once the framework above is confirmed, the detailed technical plan can be
written in this order:

1. Object model and source-of-truth boundaries.
2. Event/task/trace lifecycle.
3. Default Agent Pack and official Todo pack.
4. Capture and source-material lifecycle.
5. Memory policy and lifecycle.
6. Progressive retrieval and conversation flow.
7. UI read models.
8. Permissions and Agent Pack manifest vocabulary.
9. Backup/export shape.
10. Test and validation strategy.

## Research Sources

Reference implementations:

- Memex local snapshot: `/tmp/memex-main.xJjtdp`
- Omi local snapshot: `/tmp/omi-main.NnJkl3`

External sources:

- Local-first software: https://www.inkandswitch.com/essay/local-first/
- Automerge: https://automerge.org/
- ElectricSQL shapes: https://electric.ax/docs/sync/guides/shapes
- CloudEvents: https://cloudevents.io/
- Transactional outbox: https://microservices.io/patterns/data/transactional-outbox.html
- Temporal idempotent activities: https://docs.temporal.io/activity-definition
- OpenTelemetry traces: https://opentelemetry.io/docs/concepts/signals/traces/
- MemGPT: https://arxiv.org/abs/2310.08560
- Letta archival memory: https://docs.letta.com/guides/core-concepts/memory/archival-memory/
- GraphRAG: https://arxiv.org/abs/2404.16130
- RAPTOR: https://arxiv.org/html/2401.18059v1
- Android permissions: https://developer.android.com/training/permissions/requesting
- Android photo picker: https://developer.android.com/training/data-storage/shared/photo-picker
- Apple privacy HIG: https://developer.apple.com/design/human-interface-guidelines/privacy
- Apple media capture authorization: https://developer.apple.com/documentation/avfoundation/requesting-authorization-to-capture-and-save-media
- Chrome extension permissions: https://developer.chrome.com/docs/extensions/develop/concepts/declare-permissions
- Deno permissions: https://docs.deno.com/runtime/reference/permissions/
- VS Code Workspace Trust: https://code.visualstudio.com/docs/editing/workspaces/workspace-trust
