# WideNote Mobile UI and Runtime Discussion Notes

Status: discussion notes
Date: 2026-06-26
Scope: product UI, interaction principles, and implementation-facing semantics without concrete code

## Context

This note records the current mobile UI direction after reviewing WideNote's
existing docs, current mobile implementation, and public interaction patterns
from Omi and Memex under ADR-0006 clean-room constraints.

Related local sources:

- `docs/product/positioning.md`
- `docs/rfcs/mobile-visual-style.md`
- `docs/rfcs/mobile-entry-closure.md`
- `docs/rfcs/memory-model.md`
- `docs/rfcs/phase-one-product-scope.md`
- `docs/architecture/runtime.md`
- `docs/architecture/engineering-rules.md`
- `docs/decisions/0005-use-memory-first-instead-of-pkm-core.md`
- `docs/decisions/0006-use-clean-room-parity-specs.md`

Current prototype artifacts:

- `docs/research/2026-06-25-home-ui-prototype.html`
- `docs/research/2026-06-25-mobile-interaction-options.html`
- `docs/research/2026-06-26-home-v2-decision-board.html`

## Current Product Hypothesis

WideNote's default mobile loop remains:

```text
quick capture -> timeline / cards -> memory -> insight
```

The current product hypothesis refines the role of the home page:

```text
Home is not a full infinite card feed.
Home is the daily return surface: capture, daily recap, recent records, and entry points.
```

Cards remain a core content shape, but the full card stream does not need to
occupy the default home surface. The home page should show card-like previews
and recent records, while the complete record/card flow can live in a secondary
home page or timeline surface.

## Locked Interaction Preferences

These are current working decisions, not final ADRs:

| Area | Direction |
| --- | --- |
| Memory confirmation | Do not show a normal home module for Memory confirmation. Low-risk Memory is auto-accepted. Conflicts, sensitive content, low confidence, or unclear policy go to a background review surface. |
| Capture | Use a bottom Compose Sheet as the primary record entry. It should support long text, voice, image, and file entry. |
| Todos | Keep Todos as a first-level tab. Generated todos do not need routine confirmation, but every generated todo must keep a source link. |
| Plugins | The Plugins tab should be a plugin / Agent Pack market plus installed-pack management. Settings move to the top-right. |
| Card detail | Prefer source-first details: summary or card conclusion first, then raw source, generated outputs, actions, and trace/provenance. |
| Schedule on home | Do not put schedule or todo widgets on home by default because they conflict with the Todos tab. |
| Source-first semantics | Raw records are preserved. AI output is always derived and must not overwrite source input. |
| Agent timing | Use a hybrid model: lightweight processing runs soon after capture; deeper recap and insight jobs run continuously or periodically. |
| Daily recap lifecycle | Use a rolling daytime draft plus a more stable evening/final recap. Manual refresh can be added later. |
| Phase-one file scope | Support immediate multimodal capture for text, voice/audio, image, and file-like source material. Defer broad external import flows. |
| Conversation shape | Start with a unified conversation list. Do not force users to choose context categories before asking. |
| Completed todos | Hide completed todos by default, with an explicit completed filter/history and short undo affordance after completion. |
| Default Agent Pack | Include summary/card generation, Memory proposal/evaluation, lightweight insight, and daily recap. Exclude Todo; Todo is a separate extension pack. |
| Phase-one capture inputs | Support typed text, audio recording, camera capture, and photo library selection first. Defer file picker, share sheet, bulk import, vault import, and external source ingestion. |
| Conversation retrieval | Use progressive context disclosure: Memory first, then derived summaries/cards/recaps, then targeted raw records and attachments when needed. |

## Open UI Decisions

### 1. Should Cards Occupy the Home Body?

Current objective evaluation:

- Cards are still important because they make "the app organized something for me" visible.
- A full card feed is useful for browsing recent history and explaining the product value to new users.
- But frequent users may only care about the latest two or three records, daily recap, and fast capture.
- Older records should be reachable through timeline search and agent conversation instead of requiring manual scrolling.

Recommended current direction:

```text
Home shows daily recap + recent 2-3 records + compose entry.
Full card stream remains available as a secondary "Records" or "Timeline" page.
```

Alternatives still worth comparing:

| Option | Shape | Tradeoff |
| --- | --- | --- |
| A | Home shows recent 2-3 records only | Best balance for fast capture and lightweight review |
| B | Home is full card stream | Stronger Memex-like browsing, weaker capture focus |
| C | Home has no card stream | Fastest tool feel, but weaker memory/product feedback |

### 2. Daily Recap Weight

The Omi-style daily recap is a strong fit for WideNote because it gives a
coarse view of what the user recorded or did today.

Recommended current direction:

```text
Daily recap is the first substantial home card once there is enough activity.
It is a rolling draft during the day and becomes more stable in the evening.
```

It should be coarse and calm. It should not become a task dashboard, and it
should not show every generated object.

### 3. Insight Placement

The current preference is to keep Insight as a home-level secondary page rather
than mixing it into the default home body.

Recommended current direction:

```text
Home secondary pages: Today / Insights / Records
```

This avoids a fifth bottom tab while still making insight discoverable.

### 4. Conversation Shape

"Source-first Q&A" as a mandatory starting flow is currently rejected because it
adds too much friction.

Recommended current direction:

```text
Conversation tab starts with a unified conversation list.
```

The assistant should still answer from local context first and show sources,
but users should not need to manually preselect sources or pick a context type
for normal use. The system may infer lightweight internal tags such as today,
project, person, or theme, and later expose them if the conversation surface
becomes crowded.

## Cross-Platform UI Principles

WideNote is a dual-platform mobile app, not an iOS-only design or an
Android-only design.

Principles:

- Keep core navigation identical on iOS and Android: Home, Chat, Todos,
  Plugins, plus a primary Compose action.
- Use bottom navigation on phones.
- Allow Navigation Rail or two-pane layouts on tablets, foldables, and wide
  screens later without changing the product model.
- Use platform-appropriate presentation for sheets, permissions, menus, and
  system pickers.
- Avoid a custom visual system that fights both platforms.
- Content surfaces should be opaque, readable, and calm.
- Controls, status, capture, provenance, and active navigation may be more
  expressive.
- Cards should stay compact and source-first; avoid oversized hero surfaces,
  decorative blobs, and one-note palettes.
- Visual hierarchy should communicate object type: raw record, derived card,
  accepted Memory, insight, todo, source, warning, permission, trace.

## Implementation Discussion Principles

The next discussion can be implementation-facing, but should stay above
concrete code.

Recommended discussion order:

1. User-visible object model.
2. Source-of-truth boundaries.
3. Event and agent chain.
4. File and attachment lifecycle.
5. Memory lifecycle.
6. Derived outputs: cards, insights, todos, conversation context.
7. Read models for UI surfaces.
8. Permissions, privacy, backup, trace, and deletion.

Avoid starting with:

- Database tables.
- Flutter widget class names.
- Package names.
- API payload fields.
- Model prompts.

Those details should come after product semantics and chain ownership are clear.

## Working Runtime Chain

The implementation-facing model should explain this chain:

```text
User capture
  -> raw capture record preserved
  -> optional file / attachment references preserved
  -> capture.created event appended
  -> Agent Pack or local service matches event
  -> agent run starts with permissions and trace
  -> derived outputs emitted
  -> Memory candidates evaluated by policy
  -> safe Memory auto-accepted
  -> cards / insights / todos / conversation context created
  -> UI read models display source-linked objects
```

Important constraints:

- Events are append-only.
- Raw captures are never overwritten by AI output.
- Agent outputs are new derived objects or events.
- Handlers must be idempotent because delivery can be at least once.
- External side effects require explicit permissions.
- Trace and audit evidence should exist for agent and plugin behavior.

Hybrid timing boundary:

- Soon after capture: create lightweight summary cards, simple source-linked
  Memory candidates, and basic conversation context.
- Rolling during the day: update today's recap draft and lightweight topic
  groups from recent captures.
- Periodically or in the evening: produce more stable daily recap, deeper
  insights, trend summaries, Memory cleanup, and cross-record synthesis.
- On demand: answer conversation requests using local context and explicit
  sources.

Default pack boundary:

```text
official/default
  -> summary/card
  -> Memory candidate and policy evaluation
  -> lightweight insight/topic grouping
  -> rolling and final daily recap

official/todo
  -> source-linked todos
  -> todo completion/reopen behavior
  -> optional future schedule/date grouping
```

Todo is intentionally outside the default pack so the core product remains a
record-memory-insight system rather than a task manager by default.

## File and Attachment Semantics

Files should be discussed as first-class source material, not as incidental
attachments.

Current phase-one preference:

```text
Support immediate multimodal capture: typed text, audio recording, camera
capture, and photo library selection from the compose flow.
Defer broad import workflows such as bulk folders, external vault import,
large document libraries, file picker, share sheet, and full cross-app
ingestion.
```

Questions to resolve:

- What is the source of truth for file bytes?
- What metadata belongs to the capture versus the file object?
- When voice is recorded, which objects represent audio, transcript, summary,
  and card?
- When an image or file-like source is captured, which derived outputs are
  allowed by default?
- How does deletion work when a card, Memory item, todo, or conversation answer
  references a file?
- Which file types require explicit permission or user review?
- Which file data belongs in backup, and how are secret-bearing backups labeled?

Suggested boundary:

```text
File bytes are source material.
Transcripts, OCR, summaries, embeddings, cards, and insights are derived.
Derived objects keep source refs back to files and captures.
```

## Agent Behavior Semantics

Agent behavior should be described as event-driven and permissioned.

Agent Packs may:

- Subscribe to allowed event types.
- Read allowed source objects.
- Produce derived outputs.
- Propose Memory.
- Create todos.
- Emit cards, insights, UI blocks, or trace entries.

Agent Packs should not:

- Mutate raw captures.
- Depend on private app tables.
- Bypass permission checks.
- Hide external side effects.
- Write durable Memory without policy evaluation.
- Require network or live model calls for deterministic tests.

Recommended behavior classes:

| Behavior | Meaning |
| --- | --- |
| Always-on local handler | Safe, deterministic, local transformations such as basic cards or fake/test paths |
| Model-backed handler | Uses configured provider, must have fallback and trace |
| Permissioned tool action | Requires explicit capability grant |
| High-risk plugin action | Requires separate permission and likely user confirmation |

Default-pack handlers should be separable by responsibility:

- Capture summarizer: turns one capture into a source-linked card/summary.
- Memory curator: proposes Memory, evaluates policy, auto-accepts safe Memory,
  and routes the rest to quiet review.
- Insight builder: groups recent captures and Memory into lightweight insights.
- Recap builder: maintains the rolling daily recap and finalizes the daily
  recap later.

These are product roles, not concrete class names.

## Memory Lifecycle

Memory is the durable personal context layer, not a normal note, not a card,
and not a PKM page.

Default policy:

```text
Auto-accept durable, low-risk, evidenced, non-conflicting Memory.
Route low-confidence, conflicting, sensitive, credential-like, or unclear Memory to review.
```

UI implication:

- Do not ask the user to confirm every Memory during capture.
- Do not make Memory review a prominent default home module.
- Accepted Memory should still be visible, editable, reversible, and source-linked.
- Memory deletion or correction should write a tombstone or revision.
- No Memory should be created from model inference without evidence.

## Cards, Insights, Todos, and Conversation Context

These are derived surfaces with different jobs:

| Object | Job | Source of truth |
| --- | --- | --- |
| Card | Scannable representation of one or more captures / Memory items | Derived from raw captures and Memory |
| Insight | Pattern, trend, or reflection across multiple sources | Derived from captures, Memory, todos, and events |
| Todo | Action item that can be completed, reopened, and traced to source | Derived or manual, but generated todos keep source refs |
| Conversation context | Retrieval scope and cited material for assistant answers | Local records, Memory, todos, and derived summaries |

Implementation-facing rule:

```text
Derived objects can be deleted, regenerated, hidden, or edited without
destroying the raw capture that produced them.
```

Todo visibility rule:

```text
Open todos are the default list.
Completed todos are hidden by default but remain durable, searchable, and
available through a completed filter/history.
```

This follows common task-product expectations while keeping the default Todo
tab focused on what remains actionable.

## Conversation Retrieval Layers

Conversation should not require the user to choose sources up front. Internally,
it should use progressive context disclosure:

```text
1. Current conversation turn and visible app context
2. Accepted Memory: durable user, project, preference, and relationship context
3. Derived summaries: recent cards, daily recaps, lightweight insights
4. Targeted raw records: captures, transcripts, OCR text, and source excerpts
5. Attachment expansion: audio/image/file source material only when needed and allowed
```

Rationale:

- Memory is compact, durable, and already policy-filtered, so it should be the
  first retrieval layer.
- Derived summaries and cards give efficient grounding before reading raw
  material.
- Raw captures and attachments are the audit/evidence layer, not the default
  first context for every answer.
- This mirrors the useful direction from Memex's memory-primary and split-agent
  work while keeping WideNote's own Memory-first model.
- Omi's conversation detail also supports this separation at the product level:
  summary, transcript, and action items are different views over the same
  source conversation.

Conversation answers should cite or expose the sources they relied on. If the
assistant answers only from Memory, it should still make that visible when the
answer affects user trust.

## UI Read Models

The UI should not need to reconstruct the whole runtime chain on every render.
It should read stable view-oriented models while preserving source navigation.

Candidate read surfaces:

- Home Today: daily recap, recent records, capture entry, status.
- Home Insights: insight cards, trends, source groups.
- Home Records: complete record/card stream.
- Chat: unified conversation list and sourced answers, with internal tags
  available for later filtering.
- Todos: open source-linked action list, completed filter/history, undo after
  completion.
- Plugins: marketplace, installed packs, permission previews.
- Settings: model providers, backup/import, privacy, permissions, trace.
- Detail: source-first card/record/todo/Memory detail.

## Questions for Next Discussion

Recommended next questions:

1. What exactly is a "record" in the product language: raw capture only, or raw
   capture plus generated card bundle? This can be deferred until technical
   modeling because source-first semantics are already clear.
2. Which outputs should be visible immediately, and which should only appear in
   detail pages or secondary pages?
3. How much trace should be user-facing versus advanced settings-only?
4. What is the difference between "recent records" on Home and "Records" as a
   secondary page?
5. Should the default pack be able to run without a live model by producing a
   deterministic fallback card/recap, or should model failure only show
   processing/error state?

## Promotion Path

This note is not yet an ADR or final RFC.

Promote stable parts into an RFC when these are decided:

- Home information architecture.
- Compose Sheet behavior.
- Daily recap lifecycle.
- Insight secondary page scope.
- Conversation session model.
- File and attachment lifecycle.
- Agent Pack default output policy.
- Conversation retrieval layer policy.

Any later change that affects schemas, runtime, Memory policy, plugin
permissions, backup semantics, or default UX should be recorded in RFC/ADR form
before implementation.
