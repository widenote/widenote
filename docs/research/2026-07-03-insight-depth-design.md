# Insight Depth Design From Memex Backup

Status: draft design under review

Date: 2026-07-03

Scope: make WideNote insights deeper, more source-grounded, and more useful
without copying Memex implementation or exposing private backup content.

## Inputs

- WideNote contracts:
  - `docs/architecture/operational-principles.md`
  - `docs/architecture/current-contracts.md`
  - `packages/dart/cards/README.md`
  - `packages/dart/memory/README.md`
  - `packages/dart/agent_runtime/README.md`
  - `packs/official/default/README.md`
  - `packs/official/pkm_library/README.md`
- Local Memex reference:
  - local Memex source checkout
  - local Memex backup archive from 2026-06-16

This note is clean-room and privacy-preserving. The backup was read locally to
understand structure, output quality, and evidence patterns. Raw diary records,
full Memory text, local database rows, and secret-bearing artifacts must not be
copied into WideNote docs, tests, fixtures, PR text, or external review prompts.
Local private file paths should also stay out of durable docs and external
review prompts.

## Current WideNote Gap

WideNote already has the right structural primitives:

- `InsightRecord` in local SQLite with `source_refs`, `payload`, kind, metric,
  title, summary, created/updated timestamps, and backup support.
- `MemoryFirstInsightPayload` with claims, metrics, source refs, UI block
  declarations, and a note.
- Timeline, Home, and Daily Recap surfaces that can display source-linked
  insights.
- Runtime permissions, trace sinks, Context Packets, and official Pack
  manifests for source-linked derived output.

The missing product layer is depth. Early generated insights were mostly
lightweight deterministic projections such as latest source summary, count,
most active day, and source mix. Product review rejected that as the primary
direction: those projections prove provenance, but they do not create the
user-facing "aha" moments that connect repeated records, Memory, context
shifts, and behavior changes.

## Memex Backup Findings

The inspected backup is a zip-backed `.memex` archive. Relevant structure:

| Area | Count / shape | Design signal |
| --- | --- | --- |
| `workspace/KnowledgeInsights/Cards` | 43 insight cards | User-visible insight objects are durable cards, not transient chat text. |
| `workspace/Cards` | 592 timeline cards | Insight grounding comes from many small source cards. |
| `workspace/Facts` | 101 files including text, images, OCR, and analysis | Raw source material and media-derived analysis feed later reasoning. |
| `workspace/PKM` | 35 Markdown files | PKM acts as an intermediate organization layer, but should remain a projection in WideNote. |
| `db/memex_local_*.sqlite` | 34 tables, mostly task/cache/FTS/activity | Memex insight truth is file-workspace based, while SQLite supports cache, tasks, FTS, and activity. |
| `_System/state_dir/knowledge_insight_*.json` | long-running agent state | Insight generation keeps state, tool history, model usage, and failures. |
| `_System/llm_calls/insight_*.json` | insight model-call logs | Quality review depends on inspectable generation evidence. |

The 43 cards were all backed by `related_facts`; no card had zero supporting
facts. The median related-fact count was 5, with a range of 1 to 10. This is the
clearest reason they feel grounded: every claim is tied back to multiple
timeline facts, even when the visible text is concise.

Template distribution was highly skewed:

| Template | Count | Meaning |
| --- | ---: | --- |
| `contrast_card_v1` | 25 | Most useful insight shape was tension, before/after, expectation/reality, cause/effect, or question. |
| `highlight_card_v1` | 11 | Strong quotes, named patterns, turning points, and milestones worked better than charts for qualitative life data. |
| `timeline_card_v1` | 2 | Useful for staged pattern evolution. |
| `composition_card_v1` | 2 | Useful for portfolio or attention mix. |
| `bubble_chart_card_v1` | 1 | Useful for topic distribution. |
| `radar_chart_card_v1` | 1 | Useful for multidimensional profile snapshots. |
| `trend_chart_card_v1` | 1 | Useful when values form a visible curve. |

Top tag themes were self-knowledge, behavior patterns, emotional regulation,
coping mechanisms, project management, energy rhythm, sleep, health, job
search, AI cognition, communication pattern, procrastination root, strength
training, and relationship/family context. The important design point is that
the cards named personal patterns, not generic categories.

One card required tolerant parsing because the YAML contained unescaped quote
content. WideNote should avoid this class of failure by storing insight payloads
as schema-validated JSON in SQLite and by validating Pack output before commit.

## Memex Insight Product Pattern

Memex's insight page is a two-part surface:

- Knowledge Insight list: visual cards with pin, long-press actions, delete,
  manual sort, pull-to-refresh, and detail navigation.
- Activity Stats page: recent activity metrics with date-range and metric
  controls.

Each insight card includes:

- `id`
- `title`
- `insight`
- `template_id`
- structured `data`
- `related_facts`
- `tags`
- `pinned`
- `sort_order`

The detail page reconstructs the card and its supporting timeline cards. It can
open an Agent chat with the insight as context. This is important: the insight
is not the end of the loop. It becomes a conversational object that can be
questioned, corrected, refined, or expanded.

The Knowledge Insight agent has a focused tool surface:

- read existing insight cards
- list available native templates and their required data structures
- save insight cards after schema validation
- delete insight cards
- delete unused tags
- read deterministic user activity stats

The prompt quality bar is also instructive:

- Ask whether the output is a summary or an insight.
- Prefer correlations, anomalies, contrasts, behavior loops, turning points,
  unresolved questions, and small continuities.
- Use one card for one point.
- Use visual templates strictly; do not let the model invent arbitrary UI.
- Preserve user-pinned cards.
- Use maps only with explicit coordinates.
- If data is weak, do recall or a question card instead of inventing a causal
  claim.

## WideNote Design Principles

1. Insight is a source-linked derived object, not a replacement for raw capture
   or Memory.
2. Deep semantic selection and pattern naming must be model/context governed,
   not local keyword heuristics.
3. A strong insight must expose evidence density: source count, span, confidence,
   and the main source refs.
4. The UI should make insight cards feel like living objects: pin, ask,
   correct, inspect sources, regenerate, dismiss, or supersede.
5. PKM-style organization can help, but only as derived artifacts or Pack
   outputs. Memory remains the canonical long-term context layer.
6. External review prompts may receive this design and code context, but never
   raw backup content, private records, local database contents, credentials,
   or trace payloads with user content.

## Proposed Insight Model

Extend `InsightRecord.payload` before adding new tables. The first deeper
schema can remain JSON payload inside the existing table:

```json
{
  "insight_payload_version": 2,
  "lens": "contrast|turning_point|rhythm|loop|question|milestone|portfolio|risk",
  "visual_template": "contrast|highlight|timeline|composition|trend|radar|bubble|evidence",
  "time_window": {"start": "ISO-8601", "end": "ISO-8601", "label": "last_30_days"},
  "claims": [
    {
      "id": "claim.primary",
      "text": "...",
      "confidence": 0.74,
      "claim_kind": "correlation|contrast|change|pattern|question",
      "source_refs": []
    }
  ],
  "metrics": [],
  "evidence": {
    "source_count": 5,
    "source_span_days": 17,
    "source_kinds": {"capture": 5, "memory": 2},
    "counter_evidence_refs": []
  },
  "display": {
    "hero": "...",
    "support": "...",
    "tone": "grounded_warm",
    "chips": ["behavior pattern", "energy rhythm"]
  },
  "review": {
    "needs_review": false,
    "risk_reasons": [],
    "regeneration_source": "agent.insight_synthesizer.v1"
  }
}
```

The existing `source_refs`, `metric_label`, `metric_value`, `title`, and
`summary` fields remain the list/search contract. The payload adds depth and
rendering options. Because Phase 2 would emit this payload from an official Pack
through `wn.insight.created`, the payload and visual-template shapes should land
in `packages/schemas` before model-generated deep insights are written. App and
Dart package code should parse and validate schema-owned fixtures or generated
bindings, not keep a private copy of the contract.

## Agent Orchestration

Use a staged pipeline instead of one giant prompt:

1. `agent.capture_loop` keeps doing immediate capture, Memory proposals, and
   cards. It does not emit lightweight insight fallbacks.
2. `agent.pattern_indexer` runs on capture completion and accepted Memory. It
   writes compact, source-linked pattern candidates into derived artifacts or
   low-risk insight drafts. It does not create grand claims.
3. `agent.insight_scout` runs on schedule, on demand, and after clusters become
   dense enough. It selects candidate windows through model/context boundaries:
   "what changed?", "what repeated?", "what contradicted itself?", "what needs
   a question rather than a conclusion?"
4. `agent.insight_synthesizer` turns one selected candidate into a structured
   `InsightRecord` with claims, evidence, confidence, template, and source refs.
5. `agent.insight_reviewer` performs a local source-ref audit before write:
   every claim has refs, source span is sufficient, maps require explicit
   coordinates, sensitive/high-risk topics route to review or soften to a
   question.
6. `agent.insight_maintainer` deduplicates, updates, dismisses, or supersedes
   old insights without deleting pinned or user-edited insights.
7. Chat can open an insight-scoped session that receives the insight, claims,
   allowed source excerpts, and source refs through Context Packet, then can
   request correction/regeneration through normal Pack/runtime gates.

This should fit a dedicated official Pack rather than the conservative default
Pack. `pack.default` remains responsible for capture -> card -> Memory only.
Deep insight has different triggers, higher evidence requirements, maintenance
behavior, and review gates, so `pack.insight_depth` should own it.

This can fit official Packs:

| Pack / agent | Trigger | Output | Permission |
| --- | --- | --- | --- |
| `pack.default::agent.capture_loop` | `wn.capture.created` | card, Memory proposal | existing |
| `pack.insight_depth::agent.pattern_indexer` | capture/card/memory created | source-linked pattern artifact | `artifact.write` |
| `pack.insight_depth::agent.insight_scout` | scheduled/on-demand/density threshold | insight candidate event | `knowledge.read`, `context_packet.build` |
| `pack.insight_depth::agent.insight_synthesizer` | candidate selected | `wn.insight.created` | `insight.write`, `model.complete` |
| `pack.insight_depth::agent.insight_maintainer` | new insight/user feedback | update/dismiss/supersede insight | `insight.write` |

Persisted child-agent execution is still roadmap, so the first implementation
can be native mobile handlers with the same conceptual boundaries and trace
names.

### Independent Insight Agent Contract

Deep insight is an independent official Agent path, not a sub-step of the
default capture loop. `pack.default` can prepare cards and Memory candidates,
but it must not create fallback insight objects when the deep path is
unavailable. `pack.insight_depth` owns the model call, evidence selection,
review gate, and `wn.insight.created` write.

Dependency order:

1. Raw capture, attachment metadata, transcript, OCR, and vision-summary
   artifacts are persisted without being overwritten.
2. `pack.default` turns the capture into source-linked cards and Memory
   proposals, then Memory policy accepts or routes risky candidates to review.
3. Retrieval projections and activity/statistical projections are refreshed as
   rebuildable derived state.
4. `agent.pattern_indexer` creates compact candidate windows from source-linked
   cards, accepted Memory, recent captures, todos, and prior insights.
5. `agent.insight_scout` uses model/context boundaries to select a window worth
   reflection rather than a count, keyword match, or novelty notification.
6. `agent.insight_synthesizer` uses a model to produce claims, evidence,
   counter-evidence, confidence, template choice, and source refs.
7. `agent.insight_reviewer` audits source refs, sensitivity, contradictions,
   evidence count, and confidence before write.
8. `agent.claim_verifier` or the reviewer conflict phase checks candidate
   claims against accepted Memory, active insights, counter-evidence, and user
   feedback before any auto-write.
9. High-risk, low-confidence, conflicting, or sensitive drafts route through a
   human-in-the-loop review action before they become active insights.
10. `agent.insight_maintainer` later supersedes, updates, dismisses, or
   regenerates insights based on new evidence and user feedback.

Callable tools should stay permissioned and reviewable:

- `model.complete`: generate the actual reflective judgment.
- `knowledge.read`, `timeline.read`, `memory.read`, `card.read`: read bounded
  source-linked objects through local object truth.
- `context_packet.build`: assemble bounded, cited model context.
- `semantic_search.query`: retrieve candidate evidence clusters through the
  governed retrieval path.
- `activity.stats.read`: provide deterministic counts and time-series summaries
  as evidence, not as the insight itself.
- `insight.read`: compare active, pinned, dismissed, superseded, and recent
  insights.
- `insight.write`: create, update, dismiss, or supersede schema-validated
  insights.
- `insight.template.list`: expose allowed visual templates and required payload
  shapes.
- `insight.review.submit` or `user.feedback.capture`: record explicit user
  confirmation, rejection, edit, or feedback for insight drafts.
- `claim.verifier`: check candidate claims against accepted Memory, active
  insights, counter-evidence, sensitivity flags, and user feedback.
- `source.audit`: validate source refs, evidence count, source versions, and
  high-risk flags.
- `trace.write`: persist reviewable task/run evidence without leaking secrets
  into safe exports.

Allowed data scope is local object truth and derived projections with source
refs: recent captures, transcripts, OCR/vision summaries, accepted Memory,
source-linked cards, todos, previous insights, user feedback, and bounded
aggregate activity stats. Aggregate stats must be defined as evidence features,
not as a privacy side channel or a replacement for model judgment. The Agent
must not read provider credentials, backup secrets, arbitrary filesystem
content, raw private databases, or raw media bytes unless a future
permission/ADR explicitly grants that capability. If model access, retrieval,
source refs, or required permission is missing, the Agent fails closed and
writes no insight.

The first viable implementation should prefer read-only drafts over auto-write:
generate one narrow, source-linked insight candidate for a recent bounded window
and require user confirmation before persisting it as active. Auto-write should
wait until conflict checks, review feedback, trace evidence, and low-risk
confidence thresholds are proven by tests.

Phase 1 native handlers, if used before full persisted child-agent execution,
must still be registered as official Pack behavior. They must pass through
runtime tasks/runs, permission gates, output-event declarations, source-ref
validation, and trace emission. They must not become private
`CaptureOrchestrator` logic.

## Tooling

Minimum tool set for deep insight:

- `model.complete`: generate reflective, evidence-grounded claims.
- `knowledge.read`: read source-linked cards, accepted Memory, previous
  insights, todos, and artifacts through local object truth.
- `context_packet.build`: assemble bounded source context with citations and
  source versions.
- `semantic_search.query`: retrieve candidate source clusters using model-backed
  retrieval, never local text heuristics.
- `insight.read`: list existing active, pinned, dismissed, superseded, and
  recent insights.
- `insight.write`: create/update/dismiss/supersede schema-validated insights.
- `insight.template.list`: expose the allowed visual templates and required
  payload shapes to the model.
- `insight.review.submit` or `user.feedback.capture`: record explicit user
  confirmation, rejection, edits, and feedback for drafts.
- `claim.verifier`: check candidate claims against accepted Memory, active
  insights, counter-evidence, and feedback before auto-write.
- `activity.stats.read`: deterministic counts and time-series summaries for
  recent captures, Memory, cards, insights, todos, source types, and media
  types. These stats are evidence features, not standalone insight generation.
- `source.audit`: validate source refs, source versions, evidence count, and
  high-risk flags before write.

High-risk future tools such as health import, calendar read, location analysis,
or file imports should be separate opt-in capabilities. They should enrich
insight evidence only after explicit permissions and current-contract coverage.

If a model-backed retriever or semantic search capability is unavailable, deep
insight candidate selection must fail closed for that run. It must not fall back
to local keyword, regex, stop-word, or substring heuristics over user natural
language.

## Insight Lenses

Start with eight lenses. Each lens maps to allowed templates and validation
rules:

| Lens | What it finds | Default template | Review rule |
| --- | --- | --- | --- |
| Contrast | expectation vs reality, before vs after, stated desire vs behavior | contrast | Needs at least two source groups. |
| Rhythm | time-of-day, week cadence, energy tide, sleep/recording rhythm | timeline/trend | Needs repeated sources across time. |
| Loop | recurring trigger -> response -> consequence | contrast/timeline | Must include source refs for each stage. |
| Turning point | new behavior, milestone, decision, identity shift | highlight | Needs a prior baseline or explicit self-report. |
| Portfolio | attention, projects, life domains, tool usage mix | composition/bubble | Metrics must be deterministic or model-labeled with confidence. |
| Risk signal | health, burnout, finance, conflict, safety concern | contrast/evidence | Prefer cautious wording and review when sensitive. |
| Micro-consistency | small repeated wins or quiet continuity | highlight/timeline | Avoid generic praise; cite specific repetition. |
| Open question | anomaly without enough causal proof | contrast/question | Ask, do not conclude. |

Risk signal is a high-risk lens. It should not auto-write strong claims until an
ADR/RFC defines evidence density, review routing, trace marking, user appeal or
correction flow, and softening rules. Before that decision lands, risk-shaped
observations should degrade to an open question or `needs_review`.

## Product Surface

Add a real `Insights` child page under Home before making it a bottom tab.

List page:

- Header with "Pinned", "Recent", and "Needs review" filters.
- Segmented switch: Insights / Activity.
- Cards with visual template, title, short claim, source count, time window,
  confidence, and chips.
- Pin, ask, feedback, and regenerate actions via icon buttons and overflow
  menu. Do not expose archive as a primary insight lifecycle.
- Empty state that names what is needed: more records, model provider, or
  permission.

Detail page:

- Full card at top.
- "Why this matters" claim list.
- Evidence section grouped by source refs and time.
- Counter-evidence or uncertainty when present.
- Actions: ask about this, correct sources, regenerate, dismiss, pin.
- Trace link for debug builds or Agent Console.

Home:

- Keep the teaser, but show one high-quality pinned/recent insight instead of a
  deterministic count insight when available.
- Do not show sensitive or high-risk insights on the Home teaser unless they are
  explicitly pinned and safe for glanceable display. Otherwise show a redacted
  prompt to open the detail page.

Timeline:

- Insight rows remain source-linked. Compact card rendering should show one
  claim, one metric/source chip, and a child-page link.

Chat:

- Allow "ask about this insight" to create an insight-scoped chat session with
  Context Packet citations.

## Generation Policy

Insight write should fail or route to review when:

- Any claim lacks source refs.
- The primary claim depends on high-risk health, legal, financial, credential,
  or relationship interpretation and confidence is low.
- A map/location visual lacks explicit location facts.
- The insight duplicates an active pinned insight.
- The model produces a generic summary rather than a cross-source pattern.
- Evidence count is below the lens minimum and the output is not an open
  question or recall.

Insight write may auto-accept when:

- Claims are low-risk, source-linked, and non-conflicting.
- The lens has enough evidence density.
- Existing insight dedupe says it is distinct or a safe update.
- The title and summary do not expose raw sensitive details beyond source
  excerpts already allowed by the app.

Pattern candidates created before synthesis are derived artifacts only. They
are not Memory, raw source truth, or a second PKM authority. Disabling or
uninstalling the deep-insight Pack should stop future candidates and allow
cleanup of its derived artifacts without touching captures or accepted Memory.

## Phased Implementation

### Phase 0: Contract and evaluation

- Add this design to `docs/research`.
- Draft an ADR or RFC before implementation to cover the deep insight contract,
  dedicated Pack boundary, payload schema, review gates, and relation to
  `pack.default`.
- Update `docs/architecture/current-contracts.md` only after the target state is
  accepted.
- Define `wn.insight.payload.v2` and visual-template schema fixtures under
  `packages/schemas` before model-generated deep insights can be persisted.
- Add a source-ref quality rubric:
  - source count
  - source span
  - claim-to-source coverage
  - whether output is summary vs insight
  - uncertainty handling
  - sensitivity review
- Create synthetic, Memex-shaped fixtures. Do not copy backup text.

### Phase 1: Better payload and UI without new orchestration

- Extend `MemoryFirstInsightPayload` with optional `lens`, `display`, and
  `evidence` fields generated from schema-owned fixtures, or parse them from
  `payload` without changing the Dart model yet.
- Add an Insights child page under Home using current `InsightRecord` rows.
- Add detail source inspection and ask-about-this action.
- Add widget tests for list, detail, empty, source refs, actions, and
  localization.
- Keep generation disabled in this phase; regenerate actions may expose UI state
  or a disabled affordance until the Pack/tools land.

### Phase 2: Deep Insight official Pack

- Add `pack.insight_depth` as an official native Pack or extend the default Pack
  with a second subscribed agent.
- Implement `insight.template.list`, `activity.stats.read`, and `source.audit`
  as local tools.
- Generate one candidate per eligible window, not a flood of cards.
- Add unit tests for audit and schema validation.
- Add orchestration tests from capture -> Memory -> candidate -> insight.

### Phase 3: Dedupe, maintenance, and chat correction

- Add pin/dismiss/supersede status semantics.
- Add maintainer logic that preserves pinned and user-edited insights.
- Add insight-scoped chat that can propose corrections through normal review.
- Add long-journey QA with synthetic inputs and opt-in live provider runs.

### Phase 4: Optional richer signals

- Add opt-in health, calendar, location, and imported-file lenses only after
  permission, privacy, source-ref, and ADR/RFC coverage are explicit.

## Implemented Foundation Slice

This design is now anchored by [ADR-0020](../decisions/0020-accept-insight-depth-foundation.md).
The first implementation slice intentionally covers the low-risk foundation,
not full automatic deep insight generation:

- Public Insight Payload schema:
  `packages/schemas/src/insight/insight_payload.schema.json`.
- Synthetic schema fixture:
  `packages/schemas/fixtures/valid/insight_payload_v2.json`.
- Mobile Insights feature:
  `apps/mobile/lib/features/insights/README.md`.
- Home-owned routes:
  `/insights` and `/insights/:insightId`.
- Mobile behavior:
  list insights and inspect claims/metrics/evidence/source refs. ADR-0022
  removed archive/restore as a primary mobile insight lifecycle action.

Deferred work remains explicit: `pack.insight_depth`, model-backed pattern
indexing, synthesis/reviewer/maintainer agents, and high-risk review queues are
not part of this foundation slice.

## Validation Plan

- `dart test` in `packages/dart/cards` for payload parsing and source-ref
  validation.
- `dart test` in `packages/dart/local_db` for insight status, source refs,
  backup/restore, and Context Packet inclusion.
- `flutter analyze` and targeted widget tests in `apps/mobile` for the Insights
  page, detail page, source refs, ask/feedback/regenerate actions,
  empty/loading states, and localization.
- Capture orchestration tests covering `CaptureOrchestrator` as the cross-layer
  boundary.
- Pack validator tests when adding the official Pack.
- Live provider QA only with opt-in keys and redacted artifacts.

## Open Decisions

- Should deep insight be a new official Pack (`pack.insight_depth`) or a second
  agent inside `pack.default`? Kimi review recommends a dedicated official Pack.
- Should `InsightRecord.status` use `active/dismissed/superseded/needs_review`,
  or do review states live in payload until a public schema lands?
- Should visual templates be a schema family under `packages/schemas` now, or
  begin as app-local native renderers?
- What is the minimum evidence density for each lens?
- Should Activity Stats be part of the Insights page or Daily Recap until the
  page earns its own route?

## Kimi Review Notes

Kimi CLI review was run with thinking enabled against this research note and
the current WideNote architecture/runtime/card/Memory/Pack docs. The prompt
explicitly forbade reading the local Memex backup, local Memex checkout, raw
private records, local database contents, trace payloads, or credentials.

Verdict: Conditional Go. The direction is compatible with WideNote's
local-first, source-truth, Memory-first, Pack, permission, and trace boundaries,
but it must stay in research/design until contract, schema, and privacy issues
are resolved.

P0 feedback incorporated here:

- Removed durable local absolute paths from the research note.
- Clarified that deep insight payload and visual templates should be schema
  contracts in `packages/schemas` before model-generated Pack output persists.
- Clarified that a dedicated `pack.insight_depth` is preferred over expanding
  the conservative default Pack or hiding logic inside `CaptureOrchestrator`.
- Clarified that risk-shaped insight requires ADR/RFC coverage, review or
  softening, and trace marking before auto-write.
- Clarified that semantic-search/model unavailability must fail closed instead
  of using local text heuristics.

Follow-up recommendations:

- Create an ADR/RFC for the deep insight contract and review gates before
  implementation.
- Update `current-contracts.md` only after the target state is accepted.
- Start Phase 1 as read-only UI plus payload parsing; defer model generation and
  regenerate behavior until the official Pack and tools land.
- Treat counter-evidence as a later enhancement unless retrieval can reliably
  gather it; Phase 2 can start with uncertainty and confidence fields.
