# Memex Parity Capability Plans

Status: technical plan, Kimi-reviewed, Memory policy alignment partially implemented
Date: 2026-06-27

Scope: ASR, multimedia/OCR/vision, Conversations Agent, semantic retrieval,
complex insights, and Memory write-policy alignment after comparing current
WideNote with Memex-like product closure patterns.

## Inputs

- Current contracts: `docs/architecture/current-contracts.md`
- ADR-0011: `docs/decisions/0011-adopt-agent-runtime-roadmap.md`
- Agent Runtime Capability Boundaries:
  `docs/rfcs/agent-runtime-capability-boundaries.md`
- Memory Model RFC: `docs/rfcs/memory-model.md`
- Current W7 state: `docs/research/2026-06-26-w7-current-integration-state.md`
- Current module READMEs for capture, media, chat, Memory, cards, local DB,
  Agent Runtime, and UI blocks.

The reference behavior is Memex/Omi product behavior only. WideNote must not
copy source code, prompts, schemas, private data models, UI assets, migrations,
or tests from reference projects.

## Current Direction

WideNote should absorb the useful Memex/Omi patterns through WideNote-owned
boundaries:

- raw records and original attachments stay source truth
- ASR/OCR/vision/transcripts are derived artifacts
- Context Packets and local tools are the governed read boundary
- Memory writes go through `MemoryService` and default auto-accept policy
- Conversations become read-only Agent runs first, then confirm-gated actions
- complex insights become source-linked `InsightRecord` plus structured
  payload/UI blocks, not dynamic UI or PKM objects

## 1. ASR Closure

### User Journey

1. User records voice from the Record tab.
2. The original audio file is saved immediately as a local attachment with
   metadata, hash, duration, and source refs.
3. The UI shows the raw audio record immediately, with transcript status such as
   pending, transcribing, ready, failed, or permission needed.
4. `pack.file_context` processes voice attachments after the raw source is
   durable.
5. A local or provider-backed transcription tool creates a transcript derived
   object.
6. Default capture, Memory, card, todo, and insight flows consume the transcript
   through Context Packets and source refs.
7. Failure never hides or deletes the raw audio; the user can retry or switch
   provider later.

### Architecture

```text
RecordVoiceCaptureAdapter
  -> Raw audio file + sha256 + AttachmentRecord
  -> wn.capture.created
  -> pack.file_context
  -> audio.transcribe tool
  -> TranscriptRecord / wn.transcript.created
  -> Context Packet transcript excerpt
  -> default pack Memory/Card/Todo/Insight
```

The recording adapter should not own ASR. It only requests microphone
permission, records audio, stores local source material, and reports platform
errors without creating phantom records.

### Data Model

Add a derived transcript object instead of overwriting capture text:

- `id`
- `capture_id`
- `attachment_id`
- `source_event_id`
- `text`
- `language`
- `segments`
- `confidence`
- `provider_id`
- `model`
- `status`
- `source_refs`
- `payload`
- `created_at`
- `updated_at`

`AttachmentRecord.payload` should only keep status pointers such as
`transcript_status`, `transcript_id`, `duration_ms`, `provider_kind`, and
`error_code`.

### Permissions And Tools

First local tool:

- `audio.transcribe`

Inputs should be attachment/source refs, not arbitrary filesystem paths.
Remote ASR requires explicit high-risk permission, declared provider host,
trace redaction, and user-controlled BYOK settings. Local/platform ASR can be
lower risk but still traceable.

### Outputs

- Transcript excerpt in record detail.
- Transcript source refs in Memory/cards/todos/insights.
- Trace entries showing permission, provider id, model, duration, and error
  class without keys or raw private audio.
- Review only when transcript quality, sensitivity, source evidence, or Memory
  policy requires it.

### Tests

- voice record permission denied/cancel/error creates no phantom capture
- audio attachment persists sha256, byte length, status, and source refs
- fake ASR creates transcript derived object without mutating raw capture
- remote ASR denied without permission/provider
- transcript ready re-runs downstream pack idempotently
- simulator journey: record voice -> raw source visible -> transcript ready ->
  source-linked Memory/card updates

## 2. Multimedia, OCR, And Vision Closure

### User Journey

1. User captures or imports multiple photos/files.
2. Raw attachments are saved locally, hashed, and linked to the capture.
3. UI shows each attachment state: saved, OCR pending, vision pending, failed,
   blocked, or needs permission.
4. OCR/vision tools produce derived artifacts.
5. Context Packet exposes attachment metadata and derived artifact excerpts,
   not raw files by default.
6. Default packs produce gallery cards, Memory candidates, todos, and insights
   with capture/file/artifact source refs.

### Storage

Long-term layout:

```text
media/originals/yyyy/mm/{attachment_id}-{sha256}.{ext}
media/derived/{attachment_id}/{artifact_id}.{txt|json|webp}
```

SQLite stores relative storage refs, MIME, original filename, hash, byte length,
status, source refs, and payload metadata. Context Packets must not expose
absolute paths.

### Derived Artifacts

Add a generic `attachment_derivations` or `derived_artifacts` table:

- `id`
- `source_attachment_id`
- `capture_id`
- `artifact_kind`
- `status`
- `generator_id`
- `generator_version`
- `prompt_version`
- `input_sha256`
- `content_hash`
- `mime_type`
- `storage_path`
- `source_refs_json`
- `sensitivity`
- `confidence`
- `payload_json`
- `created_at`
- `updated_at`
- `invalidated_at`

Artifact kinds:

- `thumbnail`
- `ocr_text`
- `ocr_blocks`
- `vision_summary`
- `vision_entities`
- `safety_labels`

OCR and vision outputs are untrusted source data. They cannot instruct tools.

### Context Packet Shape

Default:

- capture safe excerpt
- attachment metadata
- redaction that raw file is not expanded

With permission and derived artifacts:

- OCR excerpt section
- vision summary section
- artifact source refs and evidence hashes

Raw file bytes remain outside Context Packet unless a future high-risk
permission explicitly grants expansion.

### Model Output

The model consumes source-linked sections and returns structured outputs:

- cards
- Memory candidates
- todos
- insights

Every output must carry source refs. Missing source refs should fail validation
or route to review, not silently create durable knowledge.

### Tests

- multi-attachment order, hash, dedupe, and source refs are stable
- blocked/review attachments do not trigger agent runs
- derived artifact invalidates when input hash changes
- Context Packet excludes raw file and absolute path
- fake OCR/vision creates source-linked cards/Memory/todos/insights
- backup/export includes safe metadata and derived text, not provider secrets

## 3. Conversations Agent And Semantic Retrieval

### User Journey

The second tab should become WideNote Quick Query:

1. User asks a question in Conversations.
2. WideNote starts a local `conversation.local_qa` Agent run in `read_only`
   mode by default.
3. The run builds a Context Packet and calls approved read tools.
4. The model answers with source citations.
5. Citation chips open Memory, timeline records, cards, todos, attachments, or
   trace detail.
6. Save-as actions start confirm-gated runs; read-only mode never mutates state.

### Run Modes

- `read_only`: default. Can read governed local context only.
- `confirm`: can propose Memory/todo/card actions but pauses for user approval.
- `auto`: later and narrow. Never default for external, destructive,
  credential, attachment-expansion, or high-risk tools.

### First Read Tools

Existing:

- `context_packet.build`
- `memory.read`
- `trace.read`

Add:

- `timeline.read`
- `capture.read`
- `card.read`
- `insight.read`
- `todo.read`
- `attachment.metadata.read`
- later `semantic_search.query`

Agents must not scan private tables directly. They should ask for Context
Packets and tool outputs.

### Semantic Retrieval

Semantic search should be a derived cache and local tool, not a canonical truth
layer:

- object truth remains SQLite rows
- embeddings/vector indexes are rebuildable
- source refs, source versions, content hashes, provider/model, generator
  version, privacy profile, and invalidation metadata are required
- safe export excludes vector cache by default
- deletion/tombstone/purge invalidates derived entries

No local keyword, regex, substring, or stop-word logic should decide semantic
meaning.

### Tool Loop

The current chat flow is one model call over compact local sources. The target
is a model-driven loop:

```text
question
  -> create local run
  -> model sees tool schemas and source policy
  -> model requests read tools
  -> runtime validates permissions/run mode
  -> tool result returns to model
  -> final answer + citations + optional proposed actions
  -> assistant message stores run_id/source_refs/tool summary
```

Providers without native tool calling can use a strict JSON tool-call protocol
for the first slice, backed by fake-model tests.

### Save-As Actions

- Save as Memory -> `memory.propose`, governed by Memory policy
- Save as Todo -> `todo.suggest` or confirm-gated create
- Save as Card/Insight -> source-linked derived output event

The chat answer itself is not canonical truth.

### Tests

- read-only run cannot call write tools
- confirm run creates approval and does not execute until approved
- citations persist on assistant messages
- no model provider shows retryable model-required state
- semantic cache invalidates on source mutation/deletion
- simulator: ask with seeded local records -> cited answer -> no mutation; then
  confirm save-as todo -> source-linked suggestion

## 4. Complex Insight Closure

### User Journey

1. Capture and Memory flows create source-linked local objects.
2. Insight Pack triggers on capture, Memory, todo, recap window, or manual
   re-analysis.
3. Deterministic statistics create candidates and source windows.
4. Model synthesis names patterns, explains claims, and suggests next steps.
5. Timeline and Recap show compact insight cards.
6. Insight detail shows claims, metrics, source refs, trace, and feedback.
7. User feedback affects future dedupe, ranking, and thresholds.

### Insight Types

Start with:

- `daily_recap`
- `trend`
- `anomaly`
- `pattern`
- `progress`
- `conflict`
- `relationship`
- `opportunity`
- `action_plan`
- `gallery`
- `timeline_synthesis`

### Model And Statistics Split

Statistics layer:

- counts
- windows
- completion rates
- trend slopes
- anomaly thresholds
- source coverage
- candidate scores

Model layer:

- theme naming
- relationship explanation
- action suggestions
- conflict interpretation
- natural-language summary

The model must use Context Packet sections and candidate stats. It should
output structured JSON with title, summary, claims, source refs, UI blocks,
confidence, and generator metadata.

### UI Blocks

Complex insights should be stored as source-linked `InsightRecord` payloads:

- compact summary and metric fields for Timeline/Recap
- `payload.claims[]`
- `payload.stats`
- `payload.window`
- `payload.ui_blocks[]`
- `payload.generator`

Allowed UI block kinds should be white-listed, for example:

- `metric_strip`
- `trend_chart`
- `source_list`
- `claim_list`
- `action_buttons`
- `timeline_cluster`

No WebView or dynamic plugin UI in the store-safe path.

### Triggering And Idempotency

Use Agent Pack subscriptions:

- `wn.capture.created`
- `wn.memory.edited`
- `wn.memory.deleted`
- `wn.todo.completed`
- `wn.recap.window.closed`
- `wn.insight.feedback`

Idempotency key:

```text
pack_id + agent_id + window + source_version_hash + insight_kind + generator_version
```

### Tests

- cards/insights require source refs
- insight claims without refs are rejected or draft/review
- deterministic stats cover timezone/window boundaries
- output event declarations and permission denial are tested
- Timeline/Recap/detail widget tests cover loading/empty/error/source links
- simulator journey: capture -> insight -> Recap -> detail -> source ref ->
  feedback -> trace

## 5. Memory Policy Alignment

### Current Conflict

The current contract says durable, low-risk, source-linked, non-conflicting
Memory auto-accepts by default; review is the exception path.

Before this plan, the capture prompt asked providers to return only text, while
the orchestrator expected metadata from `ModelResponse.raw`. Real provider
responses therefore lacked `memory_type`, `confidence`, `sensitivity`, and
`durability`, which defaulted to low confidence / medium sensitivity and routed
ordinary captures to review.

The local core `memory.propose` tool also forced every proposal into review even
when the default Memory policy would auto-accept it.

### Updated Contract

- Capture Memory output uses `capture.memory_candidate.v2`.
- Providers should return a JSON object with `text`, `memory_type`,
  `confidence`, `sensitivity`, and `durability`.
- Safe structured Memory candidates auto-accept.
- Missing or malformed metadata becomes `policy_unclear` and routes to review.
- `credential`, `health`, `finance`, `location`, medium/high sensitivity, low
  confidence, transient, missing evidence, and conflicts remain review paths.
- `memory.propose` uses `MemoryService.submitProposal` instead of forcing
  review.
- Review remains an exception/correction surface, not a per-capture admission
  queue.

### Tests

Implemented coverage:

- provider-style JSON candidate auto-accepts without raw metadata
- unstructured provider output routes to exception review
- policy-unclear proposal preserves policy reasons
- safe `memory.propose` auto-accepts
- sensitive `memory.propose` remains review

### User Experience

The product should invest in Memory maintenance rather than mandatory
admission:

- accepted Memory visible in Memory page and source-linked surfaces
- edit, delete/tombstone, restore, and revision remain easy
- exception review is low-noise and contextual
- raw capture is always preserved even if model/policy fails

## Cross-Cutting Risks

- Over-copying Memex implementation instead of using clean-room product
  patterns.
- Accidentally making remote ASR/OCR/vision or embeddings a default dependency.
- Treating transcript/OCR/vision/model answers as source truth.
- Sending raw attachments, keys, private DB contents, or traces to providers or
  external reviewers.
- Reintroducing local keyword heuristics for semantic decisions.
- Letting tool loops bypass run modes, approval, permissions, or trace.
- Producing cards/Memory/todos/insights without source refs.
- Filling Timeline with noisy insights instead of ranked, deduped, source-linked
  outputs.

## Kimi Review

Kimi review is required before this note is treated as ready. Review prompts
must use thinking mode and must not include API keys, raw private records,
local database contents, backup JSON, secret-bearing traces, or provider
credentials.

Kimi was run with explicit thinking mode and a sanitized summary of the five
capability plans. It did not block the direction, but marked most capability
areas as "needs changes" until the privacy, source-reference, and policy gates
below are explicit in implementation and tests.

### ASR

Verdict: needs changes.

- Local/offline transcription must be the default path.
- Remote ASR must never be silent fallback for raw audio.
- Provider use needs explicit consent, a local downgrade path, and retention or
  deletion policy acceptance.
- Tests must prove raw audio hash integrity, transcript segment source refs,
  and transcript-as-derived-output behavior.

### OCR And Vision

Verdict: needs changes.

- Local thumbnails and local OCR should be preferred before provider vision.
- Provider image reading needs explicit per-scope consent; sensitive images such
  as identity documents, health records, faces, and private screenshots must not
  be uploaded by default.
- Every OCR block, vision card, and claim needs an image source ref.
- PII redaction and sensitive-content review tests are required before broad
  enablement.

### Conversation Agent And Search

Verdict: needs changes.

- Read tools and semantic search need sensitivity-aware scoping before they can
  recall credentials, health, finance, location, or other sensitive sources.
- Save-as flows must route Memory writes through `MemoryService.submitProposal`;
  confirm or auto modes must not bypass Memory policy.
- Tests must prove read-only answers do not mutate local DB state.

### Complex Insights

Verdict: needs changes.

- Claims and stats need evidence spans or equivalent granular refs, not only
  object-level refs.
- Insight-derived Memory candidates should route through Memory policy; insight
  content must not silently auto-write durable Memory.
- UI blocks should remain rebuildable derived projections, not private tables
  that become a parallel source of truth.
- Regression tests must prove raw records are not overwritten by insights.

### Memory

Verdict: acceptable direction with stricter gates.

- Structured candidate v2 is aligned with the ADR direction if schema validation
  and policy checks both run.
- Missing fields, non-JSON output, and malformed metadata must route to
  `policy_unclear` review.
- Auto-accept remains valid only when source refs exist, confidence is not low,
  sensitivity is low, durability is durable, no conflict is detected, and the
  type is not credential, health, finance, or location.
- Conflict detection and source-ref persistence need explicit assertions.

### Highest Priority Risks

1. Remote ASR or vision providers becoming defaults and sending raw media
   off-device.
2. A weak auto-accept gate allowing sensitive, conflicting, or low-confidence
   Memory into the durable store.
3. Conversation save-as flows bypassing `MemoryService.submitProposal`.
4. Insight and vision cards carrying only object refs instead of auditable
   evidence spans.
5. Provider consent being too coarse, with no per-batch or per-type revocation
   and local downgrade path.

## Validation Notes

The plan review and Memory-policy alignment patch were validated with real
provider calls and simulator smoke, but only the Memory alignment slice is
implemented in this change.

- Kimi review was run with explicit thinking mode and a sanitized plan summary.
- DeepSeek live unit QA ran against the Anthropic-compatible endpoint with a
  real provider model. It verified that low-risk work, home, and product
  captures auto-accept durable Memory, while a health capture routes to review.
- The first DeepSeek run exposed truncated JSON from a provider response. The
  fix was to raise default provider output headroom and tighten the capture
  prompt around complete, closed JSON output.
- A separate simulator QA subagent ran the low-risk Quick Capture UI journey on
  an iPhone 17 iOS 26.5 simulator with a real DeepSeek provider. It verified
  source-linked Memory, Todo, card, insight, and trace creation with no review
  candidate for the low-risk capture.
- Remaining simulator gap: the health/sensitive review UI journey and generated
  result visibility in list surfaces still need explicit device-level tests.
