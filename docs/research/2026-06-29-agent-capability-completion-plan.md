# Agent Capability Completion Plan

Status: Kimi-reviewed implementation plan
Date: 2026-06-29

Scope: turn the current WideNote Agent Runtime primitives into user-visible,
tested Agent capabilities after comparing current WideNote, Memex, and Omi.

This plan is the coordination document for the next implementation wave. It is
not a new product direction. It keeps the existing contracts in
`docs/architecture/current-contracts.md`, ADR-0011, the Agent Pack Schema RFC,
and the Agent Runtime Capability Boundaries RFC as the source of truth.

## Current Baseline

WideNote already has useful foundations:

- `RuntimeKernel` owns append-only events, pack subscriptions, tasks, runs,
  permissions, model calls, tool invocation, run modes, approval traces, and
  output event validation.
- `LocalDbCoreToolCatalog` already defines local tools for Context Packets,
  timeline, knowledge, semantic search, Memory read/propose, todo suggest, and
  trace read.
- `ToolLoopExecutor`, `DelegationPlanner`, runtime artifact metadata, runtime
  approval persistence, `derived_artifacts`, Context Packet cache, and Agent
  Console UI already exist as primitives.
- The default capture loop can create source-linked Memory proposals, cards,
  insights, todos, and traces.

The main gap is that these primitives are not yet wired into the default user
journey. Official packs still run mostly as narrow native handlers. The default
capture Agent sees only the current capture event, official pack manifests do
not declare useful local tools, and chat is not a true runtime tool-loop run.

## Non-Negotiable Boundaries

- Raw captures and original attachments remain source truth.
- ASR, OCR, vision, search, insights, todos, and Memory are derived outputs.
- No raw private records, API keys, local database contents, backups, or full
  traces are sent to external reviewers.
- Local-first behavior must work without an account or official backend.
- No remote ASR, remote vision, external HTTP, MCP, webhook, shell, arbitrary
  filesystem, or hosted runner becomes a default dependency in this wave.
- Memory writes must go through `MemoryService.submitProposal`.
- Sensitive, low-confidence, conflicting, credential-like, or policy-unclear
  Memory goes to review. Safe durable Memory may auto-accept.
- Every Agent-produced durable output must carry source refs.
- UI changes require widget tests and localization updates.
- Local retrieval may collect candidates by explicit filters, recency, object
  type, source refs, deletion state, and permission scope. It must not decide
  semantic meaning through keyword, regex, substring, stop-word, synonym, or
  query-content similarity heuristics.
- Tool loops must reject malformed, undeclared, or mode-incompatible tool names
  with model-visible errors and redacted traces.
- Runtime execution must re-check current pack status and permissions when a
  task runs, not only when it is enqueued.

## Capability A: Local Tool Runtime Wiring

### User Journey

1. User captures text, voice, or media.
2. The runtime creates a pack run from the capture event.
3. The default pack can call declared local read tools such as
   `context_packet.build`, `memory.read`, `timeline.read`, `knowledge.read`, and
   `semantic_search.query`.
4. The Agent output is still committed as events, not direct UI mutation.
5. Traces show each model/tool call, permission check, and source refs used.

### Implementation Shape

- Register `LocalDbCoreToolCatalog` into the mobile `CaptureOrchestrator`
  runtime instead of the current empty in-memory tool registry.
- Update official pack manifests and embedded mobile manifests so tools are
  declared explicitly.
- Every declared local tool must carry access, risk, locality, approval
  requirement, and run-mode compatibility metadata. Runtime must reject
  incompatible mode/tool combinations.
- Keep first capture path bounded: one Context Packet build plus optional
  Memory/timeline reads is enough for the first slice.
- Add a runtime helper that builds a tool registry from database + memory
  repository so tests can use the same wiring as production.
- Keep the native `_CaptureAgent` in charge of final event emission for this
  wave. Do not introduce arbitrary declarative execution yet.

### Tests

- Mobile orchestrator test proves a capture run can invoke
  `context_packet.build` and preserve tool traces.
- Runtime/local DB tests prove undeclared tools are denied.
- Runtime tests prove read-only runs cannot call write tools and confirm/auto
  mode behavior is enforced for read, write, external, and high-risk tools.
- Pack validator tests prove official tool declarations are aligned with
  permissions and run mode.
- Permission-revoked-between-enqueue-and-execution tests must leave a denied
  trace and no durable derived output.
- Regression test proves missing provider still returns model-required state
  without local fake summaries.

## Capability B: Model-Driven Read-Only Chat Tool Loop

### User Journey

1. User asks in Chat: "我上次提到 Alpha 项目的截止时间是什么？"
2. WideNote starts a local read-only Agent run.
3. The model receives a strict prompt plus available read tool schemas.
4. The model asks for local search/context tools.
5. Runtime validates read-only mode, executes tools, and returns results.
6. The final answer contains source citations.
7. Read-only chat does not mutate Memory, todos, cards, or raw captures.

### Implementation Shape

- Introduce a chat runtime service under `apps/mobile/lib/features/chat`.
- Reuse existing chat persistence, but store `run_id`, source refs, and tool
  summary on assistant messages when available.
- Start with a deterministic JSON tool-call protocol for providers without
  native tool calling:

```json
{"tool_calls":[{"name":"semantic_search.query","input":{"query":"..."}}]}
```

- Accept either final answer JSON or plain text. Malformed tool-call output
  should fail safely and produce a model-visible error message.
- Tool names returned by model JSON must be checked against the current run's
  declared tool allowlist before execution.
- Read-only mode may call only read tools.
- Save-as actions are out of read-only scope. Confirm-gated save-as will be a
  follow-up after the read loop is stable. The run mode is fixed at run
  creation and cannot be escalated by model output or later chat text in the
  same run.

### Tests

- Unit test: read-only loop can call `semantic_search.query` then answer with
  citations.
- Unit test: write tool in read-only mode is denied and no DB mutation occurs.
- Unit test: malformed or undeclared tool names produce a model-visible denial.
- Unit test: empty model response or provider failure becomes retryable model
  error, never a local template answer.
- Widget test: chat shows cited answer and a readable tool/source summary.
- Widget test: model/tool failure shows localized retryable error state.
- Orchestration test: seeded captures and Memory produce cited answer.

## Capability C: Bounded Subagents

### User Journey

1. A parent run determines it needs specialized local work.
2. It delegates a bounded child run such as `research-readonly`,
   `memory-review`, `todo-planner`, `recap-builder`, or
   `integration-diagnostics`.
3. The child receives only an attenuated budget: source refs, tools, run mode,
   max duration, and max tool calls.
4. The parent trace links to the child run.
5. Child output is accepted only if it satisfies schema and source refs.

### Implementation Shape

- Keep the first implementation native and fixed-preset.
- Add a `DelegationExecutor` in `packages/dart/agent_runtime` that:
  - validates the request with `DelegationPlanner`
  - creates child task/run records through runtime store
  - invokes a provided child handler
  - writes parent/child trace links
  - returns a structured result to the parent
- A child budget is the intersection of parent budget and child preset. It must
  never exceed the parent in allowed tools, context surface, source refs,
  run mode, duration, tool call count, token/cost budget, permission grants, or
  approval state.
- A parent in read-only mode cannot delegate to a write-capable child. A parent
  without a permission cannot down-scope or proxy that missing permission to a
  child.
- If a child output is missing source refs or violates schema, the child run is
  failed and the parent receives a structured child-failed result. Parent merge
  must not emit durable outputs from that failed child result.
- No nested delegation.
- No parallel writes in the first slice. Parallel read-only child runs can be
  added after serial child runs are stable.
- Mobile should expose child runs in the existing Agent Console instead of a new
  UI surface.

### Tests

- Runtime test: child cannot receive tools outside parent budget.
- Runtime test: child cannot receive broader run mode or source refs.
- Runtime test: child cannot receive broader context surface, permissions, or
  token/cost budget.
- Runtime test: read-only parent cannot delegate a write-capable child.
- Runtime test: accepted child output requires source refs.
- Runtime test: child failure does not mark parent output as successful.
- Widget test: Agent Console renders parent and child run linkage.

## Capability D: ASR/OCR/Vision Derived Artifacts

### User Journey

1. User records voice or attaches images.
2. Raw local attachment is saved immediately with hash, type, and source refs.
3. The UI shows a derived-artifact state: pending, ready, failed, blocked, or
   needs review.
4. Fake local ASR/OCR tools generate transcript or OCR artifacts in tests.
5. Context Packet and search expose derived artifact excerpts, not raw files.
6. Downstream packs can use those excerpts to create Memory/card/todo/insight
   outputs with artifact source refs.

### Implementation Shape

- Use the existing `derived_artifacts` table and DAO.
- Add local fake tools first:
  - `audio.transcribe.local_fake`
  - `image.ocr.local_fake`
  - `image.describe.local_fake`
- Tools accept attachment/capture/source refs, not arbitrary paths.
- Fake tools must write derived artifacts only. They must not return raw media
  bytes, absolute paths, or enough data to reconstruct the original audio/image.
- Blocked, review, or failed states must come from permission/user/platform/
  tool status, not local content keyword scanning.
- Provider-backed ASR/OCR/vision remains disabled unless a later provider
  permission slice explicitly enables it.
- Extend Context Packet builder to include ready derived artifact excerpts and
  source refs.
- Extend capture/timeline UI with artifact state labels using localization.

### Tests

- Unit test: fake ASR creates transcript artifact without mutating raw capture.
- Unit test: fake OCR creates source-linked text artifact.
- Unit test: blocked/review attachments do not trigger derived tools.
- Unit test: Context Packet excludes raw file path and includes artifact refs.
- Unit test: search results, chat citations, and trace tool results also exclude
  raw file paths and raw media contents.
- Widget test: capture/timeline surfaces pending/ready/failed artifact state.
- Backup/export test: safe backup includes artifact metadata/text but no
  provider secrets.

## Capability E: Local Candidate Retrieval

### User Journey

1. User asks a question or a pack requests context.
2. `semantic_search.query` returns a model-ready candidate packet.
3. Results include Memory, captures, cards, insights, todos, and derived
   artifacts with source refs and sensitivity metadata.
4. The model makes the semantic judgment; deterministic local retrieval only
   gathers eligible candidate context.

### Implementation Shape

- Do not add remote embeddings in this wave.
- Do not add local embedding or vector ranking in this wave. Future embeddings
  must remain rebuildable derived cache and must not become canonical truth.
- Implement a local candidate collector using only non-semantic technical
  dimensions: object kind, recency, time window, explicit source refs, explicit
  user filters, source-link adjacency, status, deletion/tombstone state, and
  permission/sensitivity scope.
- Do not rank or filter candidates by comparing the user's query text against
  stored content with keywords, regex, substring, stop words, synonyms,
  language-specific tokenization, or local similarity scoring.
- Store enough metadata for future vector cache: source version/hash,
  generator, invalidation reason, privacy profile.
- Make `semantic_search.query` return source summaries, redacted snippets, and
  provenance. It must not return final answers.
- Respect sensitivity and deletion/tombstone filters.

### Tests

- Unit test: deleted/tombstoned Memory is excluded.
- Unit test: credential/high-sensitivity rows are excluded unless permission
  mode explicitly allows trace/review context.
- Unit test: derived artifacts are returned by source ref and excerpt.
- Unit test: query returns citations and stable ordering for seeded fixtures by
  non-semantic dimensions.
- Unit test: synonym, cross-language, and case-only query changes do not change
  candidate collection unless explicit filters change.
- Chat orchestration test: cited answer uses retrieval results.

## Capability F: Complex Insight Pack

### User Journey

1. User accumulates captures, Memory, todos, and derived artifacts.
2. A local insight pack runs on capture or manual re-analysis.
3. Deterministic stats select candidate source windows.
4. The model names patterns and outputs structured claims.
5. Timeline and Recap show compact insight cards.
6. Insight detail shows claims, stats, source refs, trace, and feedback.

### Implementation Shape

- Add an official `pack.insight` or expand the default pack only if manifest
  alignment stays clean. Preference: separate official pack.
- Insight kinds for first slice:
  - `trend`
  - `action_pattern`
  - `attachment_evidence`
  - `conflict`
  - `daily_synthesis`
- Store claims and stats inside existing `InsightRecord.payload`.
- Whitelist UI block kinds in payload only; no dynamic UI or WebView.
- Reject or route to review any insight claim without source refs.
- Insight output that proposes durable user knowledge must create a Memory
  proposal through `MemoryService.submitProposal`; insight packs must not write
  Memory directly.
- Every insight claim source ref must be navigable back to the originating
  capture, Memory item, todo, card, or derived artifact in UI tests.

### Tests

- Cards package test: insight claims require refs.
- Local DB test: insight payload round-trips claims/stats/ui blocks.
- Runtime test: pack output event declaration is enforced.
- Pack validator test: unknown insight UI block kinds fail validation.
- Widget test: timeline/recap/detail render insight claims and source links.
- Orchestration test: capture sequence produces ranked, deduped insight.

## Capability G: Pack/Skill Runtime Completion

### User Journey

1. User sees official packs and their declared tools/permissions.
2. Disabling a pack or revoking permission changes future runtime behavior.
3. Pack validation catches undeclared tools, risky run modes, and output drift.
4. Local-dev custom skills remain disabled unless explicitly supported.

### Implementation Shape

- Make runtime registration/enqueue respect `PackInstallation.status`.
- If a pack is disabled after a task is already pending, execution must re-check
  current pack status. The task should move to a denied/blocked status with a
  trace that explains pack-disabled-at-execution.
- If a permission is revoked after enqueue but before execution, execution must
  re-check current permission state and deny the run.
- Align Dart manifest bridge with JSON schema tool metadata fields needed for
  local tools: access, locality, risk, approval requirement, and run mode.
- Keep script/remote/MCP as manifest-visible but execution-denied in this wave.
- Script, remote, MCP, and live HTTP tools are either rejected by validator for
  official L1-L3 packs or fail at runtime with explicit unsupported trace. They
  cannot be enabled by prompt text or hidden flags.
- Add a sample local official pack manifest for insight or file context.
- Update pack README and project map when adding durable packs.

### Tests

- Runtime/local DB test: disabled pack does not enqueue new tasks.
- Runtime/local DB test: already-pending task becomes denied/blocked when pack
  is disabled before execution.
- Pack validator tests: missing tool permission and unsafe approval metadata
  fail.
- Widget test: Pack Library status accurately reflects enabled/disabled and
  denied permission behavior.
- Integration test: revoking a pack permission blocks subsequent run and shows
  trace/console evidence.

## Capability H: Agent Console And Approval UX

### User Journey

1. User opens Agent Console.
2. They can see active, failed, denied, blocked, and child runs.
3. They can inspect what triggered a run, what tools ran, what source refs were
   used, what outputs were created, and what needs approval.
4. Retry/cancel controls remain disabled until runtime control provider exists.

### Implementation Shape

- Extend existing trace console models with:
  - parent/child run ids
  - tool call summaries
  - output event refs
  - approval request status
  - pack disabled/permission denied explanation
- Startup/reload must classify approval requests as pending, expired, canceled,
  or orphaned before rendering approve/deny affordances.
- Reuse `LocalDbCoreToolCatalog.trace.read` redaction behavior.
- Do not expose raw prompt text, complete raw capture body, API keys, OAuth
  tokens, original attachment paths, or raw private attachment contents.

### Tests

- Widget tests for all filters: all, active, failed, denied, blocked.
- Widget test for approval pending card.
- Widget test for expired/orphaned approval state.
- Widget test for parent/child run linkage.
- Unit test for redaction of provider keys, OAuth token fragments,
  secret-looking payloads, raw prompts, complete capture bodies, and attachment
  paths.
- Runtime test: denied action returns a model-visible result so an Agent can
  continue safely.

## Cross-Capability Implementation Order

1. Documentation and Kimi review for this plan.
2. Runtime/local DB wiring:
   - tool registry factory
   - manifest tool metadata alignment
   - disabled pack enforcement
3. Local candidate retrieval contract and ADR-0010 tests.
4. Chat read-only tool loop.
5. Derived artifact fake ASR/OCR tools and Context Packet exposure.
6. Subagent executor and Agent Console linkage.
7. Insight pack and insight UI payload rendering.
8. Pack Library and permission/approval polish.
9. Full simulator validation.

This order is intentional. Chat, artifacts, insights, and subagents should use
the same tool/permission/trace primitives instead of each inventing a private
path.

## Subagent Split Plan

After Kimi review, implementation should be split into disjoint write scopes:

| Worker | Scope | Primary paths |
| --- | --- | --- |
| Runtime/tools | local tool registration, manifest bridge, disabled pack enforcement, tests | `packages/dart/agent_runtime/**`, `packages/dart/local_db/**`, `packs/**`, `tools/pack_validator/**` |
| Chat/retrieval | read-only tool loop, chat citations/tool summaries, tests | `apps/mobile/lib/features/chat/**`, chat tests |
| Artifacts/media | fake ASR/OCR tools, derived artifact Context Packet, capture/timeline states | `packages/dart/local_db/**`, `apps/mobile/lib/features/capture/**`, media/timeline tests |
| Subagents/console | child run executor, trace models, Agent Console linkage | `packages/dart/agent_runtime/**`, `apps/mobile/lib/features/traces/**` |
| Insights | official insight pack, structured insight payloads, recap/timeline rendering | `packages/dart/cards/**`, `packs/official/**`, `apps/mobile/lib/features/recap/**`, timeline tests |
| QA coordinator | deterministic test matrix and serialized simulator lane | `apps/mobile/test/**`, `integration_test/**`, docs/research QA notes |

Workers must not edit the same generated localization files concurrently. The
coordinator owns final l10n merge/regeneration, project map updates, and final
simulator validation.

## Detailed Test Plan

### Package Tests

- `packages/dart/agent_runtime`: runtime enqueue, tool loop, run modes,
  delegation, child run trace links, output validation, disabled packs.
- `packages/dart/local_db`: core tools, Context Packet, derived artifacts,
  semantic retrieval, backup/export, approval persistence.
- `packages/dart/memory`: auto-accept/review/conflict/tombstone invariants.
- `packages/dart/cards`: insight ranking, source refs, UI block payload shape.
- `packages/dart/model_providers`: fake provider and live-provider skip logic.

### Mobile Widget Tests

- Capture console:
  - text capture success
  - model unavailable
  - memory auto-accepted
  - memory needs review
  - attachment pending/ready/failed/blocked
- Chat:
  - cited answer
  - tool-loop progress/summary
  - read-only denial for write tool
  - model/tool failure
- Timeline/Recap/Insight:
  - source links open details
  - insight claim list and metric blocks render
  - empty/loading/error states
- Agent Console:
  - filters
  - parent/child runs
  - approval pending
  - permission denied
  - redacted traces
- Pack Library:
  - enabled/disabled
  - permission revoked
  - deferred capabilities

### Integration Tests With Fakes

- Seeded local DB -> chat read-only query -> cited answer -> no mutation.
- Voice attachment -> fake ASR artifact -> Context Packet -> Memory/card/todo
  source refs include artifact.
- Image attachment -> fake OCR artifact -> search -> cited answer.
- Multiple captures -> insight pack -> timeline/recap/detail source refs.
- Parent run -> child run -> trace console linkage.
- Pack disabled -> no task enqueue; pack re-enabled -> run resumes on new event.

### Live Provider Tests

Live tests are opt-in and must keep secrets in environment or dart-defines only.
They should use sanitized synthetic data.

- DeepSeek Anthropic-compatible:
  - low-risk capture auto-accepts Memory
  - health/credential-like capture routes to review
  - trace payload does not leak provider key fragments
  - JSON candidate parsing handles complete and malformed responses
- Kimi review:
  - plan review before implementation
  - module risk review after implementation
  - final readiness review before PR

### Simulator Tests

Run on one serialized simulator lane.

Android:

- Launch dev flavor.
- Configure or inject test provider state.
- Text capture low-risk journey.
- Sensitive capture review journey.
- Chat read-only cited answer with seeded records.
- Attachment fake ASR/OCR journey using test adapters.
- Agent Console inspection of run/tool/child traces.
- Pack disable/re-enable journey.

iOS:

- Same coverage on one iPhone simulator.
- Extra focus on voice/media permissions and provider errors.

Corner cases:

- No provider configured.
- Provider 429/network error.
- Malformed model JSON.
- Malformed or undeclared tool name.
- Empty model response.
- Missing source refs.
- Duplicate capture submit.
- App restart after pending task.
- Permission revoked between enqueue and execution.
- Pack disabled between enqueue and execution.
- Blocked attachment.
- Dangerous preview redaction.
- Tombstoned Memory/search invalidation.
- Very long capture text.
- Mixed Chinese/English input.
- Timezone/day boundary for recap/insight.
- Child run timeout/failure.
- Child output missing source refs.
- Approval pending/expired/denied.
- Approval orphaned after restart.

### Simulator Acceptance Script

Run this after package and widget tests pass. Use synthetic records only. The
same journeys should run on Android first, then iOS unless the failure is
platform-specific and already explained.

1. Provider and permission bootstrap
   - Input: start with a clean local database and no account.
   - Authentication/authorization: no WideNote account; provider key is injected
     through local dev configuration only, never entered into capture text or
     committed fixtures.
   - Expected output: Settings shows provider configured when injected, Capture
     and Timeline remain usable without account, Agent Console has no leaked key
     fragments.
   - Corner cases: provider missing, malformed provider config, provider 429,
     airplane-mode/network error.
2. Text capture to Memory/card/insight
   - Input: "Alpha 项目周五前要确认 demo 讲稿，发给 Lin 复核。"
   - Authentication/authorization: local capture permission only; no remote
     account permission.
   - Expected output: capture row appears; runtime run emits source-linked
     Memory candidate/card/insight/todo events where supported; safe durable
     Memory may auto-accept; low-confidence/sensitive candidate goes to review.
   - UI evidence: Capture feedback, Timeline capture/card/insight rows, Memory
     list or review surface, Todo list, Agent Console run/tool traces.
   - Corner cases: duplicate submit, very long mixed Chinese/English body,
     empty body, app restart while task pending, permission revoked before
     execution.
3. Sensitive capture review
   - Input: "我的医保检查结果是血压偏高，账号密码 abc123 需要换。"
   - Authentication/authorization: local capture; Memory review permission
     remains explicit.
   - Expected output: raw capture is stored; health/credential-like Memory
     candidate is not silently durable; review item or rejected trace appears;
     no secret appears in trace payload, chat citation, or preview.
   - UI evidence: review status, redacted Agent Console trace, source refs still
     point to the raw capture.
   - Corner cases: provider says high confidence, provider returns malformed
     sensitivity JSON, review accepted/denied/expired, app restart with pending
     review.
4. Voice attachment derived artifact path
   - Input: record or inject a short voice attachment: "明天十点看 Alpha 指标。"
   - Authentication/authorization: microphone permission allowed, denied, and
     cancelled paths are each tested.
   - Expected output: raw audio attachment remains source truth; fake ASR
     derived artifact is pending/ready/failed/needs-review as seeded; Context
     Packet and downstream outputs cite the attachment/artifact without exposing
     raw storage paths.
   - UI evidence: capture attachment row, artifact status chips, Timeline
     attachment artifact section, Agent Console tool trace.
   - Corner cases: denied mic, cancelled recording, blocked unsafe media,
     missing file after restart, artifact failed with raw path in adapter error.
5. Image/OCR/vision derived artifact path
   - Input: camera/gallery synthetic image with whiteboard text.
   - Authentication/authorization: camera/gallery permission allowed, denied,
     cancelled paths are each tested.
   - Expected output: raw image is stored locally; OCR/vision artifacts are
     derived and source-linked; blocked/dangerous previews render no raw unsafe
     content.
   - UI evidence: attachment preview, OCR/vision artifact status, Timeline
     safe excerpt, Chat cited answer can cite the artifact.
   - Corner cases: unsupported MIME, oversized image metadata, OCR pending,
     vision failed, blocked artifact reason.
6. Chat read-only tool loop
   - Input: "Alpha 项目下一步要做什么？引用来源。"
   - Authentication/authorization: read-only local Agent run; no write
     permission; no Memory/todo/card mutation.
   - Expected output: model may request allowed read tools; final answer
     includes citations; write/malformed/undeclared tools are denied with a
     model-visible error and no mutation.
   - UI evidence: Chat answer, citation chips, tool summary, Agent Console
     read-only traces.
   - Corner cases: empty model response, malformed JSON, undeclared tool,
     write tool in read-only mode, tombstoned Memory, no matching candidates.
7. Insight recap and detail
   - Input: seed several captures across two local days with repeated themes,
     todos, Memory items, cards, and derived artifacts.
   - Authentication/authorization: local-only recap/insight read.
   - Expected output: recap shows ranked insight cards with claim list, metrics,
     and source refs; no claim without refs is accepted; day boundary follows
     local timezone.
   - UI evidence: Daily Recap insight section, Timeline insight row/detail,
     source links navigate to originating capture/card/memory/artifact.
   - Corner cases: duplicate source refs, mixed source kinds, empty day, DST or
     timezone edge, unknown UI block kind rejected by validator.
8. Bounded child run
   - Input: trigger a parent Agent run that delegates a read-only review child.
   - Authentication/authorization: child run inherits the intersection of
     parent budget, preset budget, and requested budget.
   - Expected output: attenuated child succeeds when tools/source refs/run mode
     are narrower; write-capable child from read-only parent, auto child from
     confirm parent, nested delegation, and missing-source child output are
     rejected.
   - UI evidence: Agent Console parent run shows child run/delegation link,
     status, violations, and redacted details.
   - Corner cases: child timeout, child tool-call limit, token/cost limit,
     source ref outside parent, pack disabled between enqueue and execution.
9. Pack enable/disable and permission revocation
   - Input: disable default pack, capture once, re-enable, capture again, then
     revoke a permission before a pending task executes.
   - Authentication/authorization: explicit local pack toggle and permission
     state.
   - Expected output: disabled pack does not enqueue/execute; re-enabled pack
     only handles new events; revoked permission causes denied trace and no
     durable derived output.
   - UI evidence: Pack Library status, Agent Console denied/disabled traces,
     Timeline absence/presence of derived outputs.
   - Corner cases: stale queued task, duplicate event identity, permission
     revoked during retry, app restart before queue drain.

## Kimi Review 2026-06-29

Kimi reviewed the first draft in thinking mode with no secrets or private data.
The verdict was `needs changes`, not `blocked`.

Required changes accepted into this plan:

1. Capability E was renamed to Local Candidate Retrieval and now forbids local
   keyword, regex, substring, stop-word, synonym, tokenization, or similarity
   heuristics for semantic selection. It collects candidates only by explicit
   technical filters and lets the model make semantic judgments.
2. Capability C now defines child budgets as the intersection of parent budget
   and preset, including context surface, permission grants, approval state, and
   token/cost budgets. Parent runs cannot delegate around their own run mode or
   missing permissions.
3. Capabilities A, B, G, and H now require model-visible denial for malformed or
   undeclared tool names, mode-incompatible tools, disabled packs, revoked
   permissions, denied approvals, and unsupported script/remote/MCP tools.
4. Capability D now explicitly forbids raw media reconstruction through derived
   artifact outputs and requires raw path/content redaction across Context
   Packet, search, chat citations, and trace outputs.
5. Capability F now states that insight-derived durable knowledge must go
   through `MemoryService.submitProposal` and that insight claims must be
   navigable back to source refs.

Merge-blocking tests added from review:

- read-only/write-tool denial
- malformed tool-name denial
- empty model response error
- permission revoked between enqueue and execution
- pack disabled between enqueue and execution
- child permission/context/run-mode/token budget escalation denial
- child output missing source refs
- local retrieval no-keyword-heuristic invariants
- raw path/content redaction across retrieval, citations, and trace
- approval expired/orphaned state
- insight UI block whitelist validation

## Kimi Review Checklist

The review prompt must ask Kimi to focus on:

- privacy and source-truth regressions
- run-mode and approval bypasses
- Memory auto-accept/review correctness
- whether tool loops and subagents can escape declared capability budgets
- whether ASR/OCR/vision artifacts remain derived and revocable
- whether semantic retrieval violates ADR-0010 by deciding meaning locally
- whether the test plan covers simulator and corner-case risk

Review inputs must omit secrets and real user data.
