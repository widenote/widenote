# RFC: Agent Runtime Capability Boundaries

Status: Proposed implementation guardrail under ADR-0011
Date: 2026-06-27

## Summary

This RFC defines the implementation boundary for the Agent Runtime roadmap
accepted in ADR-0011. It answers, for each capability area, what WideNote should
build, what level of completeness is expected, and where the boundary is so
future work does not drift into an Omi clone, a Memex clone, or a generic agent
framework.

Reference projects:

- Omi snapshot:
  <https://github.com/BasedHardware/omi/tree/d7e89504b3e1f0b5281eff9f8503a21c6d88cc8a>
- Memex snapshot:
  <https://github.com/memex-lab/memex/tree/d1fc2351fb6144afbde5117d00dc97edd4c880ad>
- ADR-0011: `docs/decisions/0011-adopt-agent-runtime-roadmap.md`
- Tracking issue: <https://github.com/widenote/widenote/issues/14>

## Motivation

ADR-0011 accepts a broad roadmap: self-owned runtime kernel, declarative/script
and remote runtime options, orchestration, subagents, local tools, external
tools, MCP, webhooks, retrieval, graph views, product controls, custom agents,
and continuous capture.

That breadth is intentional, but it creates a risk: implementation teams could
start in different directions and accidentally build incompatible systems. This
RFC narrows each item into a target shape and explicit guardrails.

## Capability Completion Levels

Use these levels when splitting issues.

| Level | Meaning |
| --- | --- |
| L0 | Deliberately unsupported for the current slice. Documented as a non-goal. |
| L1 | Contract exists: schema, permission, trace, manifest field, validator, or RFC. |
| L2 | Local-first implementation works for official packs and deterministic tests. |
| L3 | User-controllable: visible UI, permission review, approval, retry/cancel, and source-linked trace. |
| L4 | Ecosystem-ready: external tools, MCP, backend/runner, community packs, or third-party integrations can use the contract. |

The first implementation wave after ADR-0011 should mostly target L1-L3. L4
capabilities need separate RFCs unless this document says otherwise.

Live off-device execution belongs to L4. L1-L3 may define contracts, local
fakes, local loopback adapters, and UI guardrails, but must not silently add
backend calls, remote MCP calls, external web fetch, webhook delivery, telemetry,
or cloud runner dispatch.

## Global Boundaries

These boundaries apply to every capability.

- Mobile local runtime remains the default host for capture, local persistence,
  Memory, Context Packets, traces, and first-run UX.
- Backend services are planned, but they enhance local truth. They cannot become
  prerequisites for quick capture, reading local records, or reviewing local
  agent traces.
- Original user records are source truth. Agent output is derived and must
  preserve source refs.
- All agent capabilities must be visible as contracts: manifest declaration,
  permission, tool schema or runtime API, trace event, and validation path.
- AI output must not directly mutate raw captures. It may create derived
  Memory proposals, cards, insights, todos, artifacts, or review requests.
- Any capability that exports user context off-device must be disabled by
  default, permissioned, traceable, and revocable.
- In the L1-L3 implementation wave, off-device export primitives are absent or
  no-op. No agent can override that absence with a prompt, tool call, or pack
  setting. Real off-device execution requires an L4 RFC and explicit user opt-in.
- Bounded subagents use capability attenuation: a child receives an explicit
  capability budget that is never broader than the parent run's tools, context,
  permissions, run mode, time, and token/cost budget.
- Omi is a reference for service topology, app tools, MCP, webhook health, and
  external integrations. It is not a license to make cloud services mandatory.
  L1-L3 must not copy Omi code, protocol, identity/auth model, telemetry, or
  storage assumptions.
- Memex is a clean-room reference for local orchestration, run modes, scoped
  tools, and bounded subagents. It is not a reason to make P.A.R.A or broad
  filesystem access the WideNote core. L1-L3 must not copy Memex code, data
  model, sync protocol, storage layout, or filesystem workspace assumptions.
- No GPL-licensed code may enter L1-L3. A license scan must be a merge-blocking
  validation gate before implementation PRs that add third-party code.
- L1-L3 must not add dynamic code loading from a network origin, regardless of
  marketplace status.
- L1-L3 must not implement continuous capture through polling by another name.
  Repeated jobs need a declared cadence, source, stop condition, and duty-cycle
  bound before they can run outside direct user action.

## Goals

- Define the expected scope for every A-E roadmap item from ADR-0011.
- Make implementation slices small enough to test.
- Keep Omi-like backend/external capability compatible with local-first data
  ownership.
- Keep Memex-like orchestration compatible with WideNote's Memory-first object
  model.
- Give future GitHub issues a reusable acceptance checklist.

## Non-goals

- No unrestricted file system, shell, browser, network, camera, microphone,
  location, contacts, credential, or notification access.
- No cloud-only agent execution path for the default product loop.
- No default continuous audio or screen capture.
- No community pack marketplace before manifest, permission, signature or
  trust, trace, and revocation contracts exist.
- No direct code reuse from GPL-licensed Memex or any GPL-licensed source.
- No hidden backend dependency for local Memory, local timeline, local trace,
  or local Pack status.
- No live backend, external MCP, external HTTP, webhook, web search, remote
  runner, or telemetry calls in L1-L3 runtime slices.

## A. Engine And Runtime Environment

### A1. Self-Owned Runtime Kernel

Reference:

- WideNote `RuntimeKernel`
- Omi desktop runtime sessions/runs/artifacts/delegation
- OpenAI Agents SDK tracing/tools/guardrail concepts

Target level:

- L2 now for official local packs.
- L3 before broad external tools.
- L4 only through adapters.

WideNote should build:

- In-process runtime that owns event routing, task creation, pack registration,
  tool invocation, model invocation, permission checks, trace emission,
  output-event validation, local task/run state, retry, cancellation, and
  restore after app restart.
- A small public runtime contract that can be consumed by mobile, backend,
  runner, and tests without exposing private app tables.

Boundary:

- The kernel is not a model SDK, prompt framework, workflow engine, script VM,
  remote runner, or UI framework.
- External frameworks may be adapters, never the source of product truth.
- The kernel must not read arbitrary local DB tables on behalf of agents; use
  declared repositories, tools, or Context Packets.

Acceptance:

- Runtime tests cover event enqueue, dependency blocking, permission denial,
  retry, cancellation, output validation, trace emission, and restore behavior.
- Every run can be inspected by pack id, agent id, task id, run id, event id,
  status, failure reason, and source refs.

### A2. Third-Party Agent Framework Adapters

Reference:

- OpenAI Agents SDK tools, handoffs, tracing, guardrails
- LangGraph durable state and human-in-the-loop
- Google ADK multi-agent/tool/deployment framing

Target level:

- L1 until a concrete integration is needed.

WideNote should build:

- Adapter points for model calls, tool calls, handoff/delegation, trace import,
  and remote runner dispatch.
- A policy that third-party frameworks receive only the Context Packet or tool
  inputs granted to the run.

Boundary:

- Do not make a third-party framework own event storage, Memory policy,
  permissions, or object truth.
- Do not add framework-specific fields to public WideNote contracts unless they
  are wrapped in generic adapter metadata.

Acceptance:

- A future adapter can be added without changing Memory source refs, Pack
  permissions, or trace schema.

### A3. Native Pack Runtime

Reference:

- WideNote official native packs
- Memex built-in agents as local app behavior

Target level:

- L2 now.
- L3 once Pack Management exposes status, permissions, and enablement.

WideNote should build:

- Native Dart/Flutter handlers for official packs.
- Manifest alignment for every native pack: ids, permissions, subscriptions,
  runtime type, retry policy, and output events.
- Validator coverage that prevents native packs from bypassing manifest
  guardrails.

Boundary:

- Native packs are trusted first-party code, but not permission-free code.
- Native packs must still go through runtime traces and permission checks.

Acceptance:

- Official pack manifests and native registration fail tests when they drift.
- Disabling or revoking pack permissions changes runtime behavior visibly.

### A4. Declarative Pack Runtime

Reference:

- Omi app tool manifests and dynamic tool schemas
- MCP tool/resource declarations
- WideNote Agent Pack Schema RFC

Target level:

- L1 first.
- L2 for official non-code flows.
- L3 before user-authored declarative packs.

WideNote should build:

- A manifest executor for event subscription, Context Packet request, prompt
  reference, model role, tool list, output schema, retry policy, and review
  policy.
- Deterministic validation before a pack can be enabled.
- Clear errors when a declarative pack references missing permissions, tools,
  output events, or context surfaces.

Boundary:

- Declarative packs cannot execute arbitrary code.
- They cannot access private app tables, hidden repositories, undeclared
  tools, arbitrary network hosts, or broad filesystem paths.
- They must emit output events or review requests; they cannot mutate UI state
  directly.

Acceptance:

- A sample official declarative pack can run locally with fake model/tool
  clients and deterministic tests.
- Invalid manifests fail before runtime execution.

### A5. Script Pack Runtime

Reference:

- Memex `flutter_js` skill runtime and bridge
- Omi plugin services as out-of-process app logic

Target level:

- L1 only until a sandbox RFC is accepted.
- L2 local-dev only after sandbox tests land.

WideNote should build:

- A script runtime contract with entrypoint, timeout, memory limit, bridge API,
  permission scope, network policy, filesystem policy, and trace capture.
- A staged edition policy: local-dev first, then signed/verified packs later.

Boundary:

- No shell execution.
- No native library loading.
- No ambient network, file, credential, clipboard, microphone, camera, contacts,
  location, or notification access.
- No background daemon behavior.
- No script pack in default onboarding.

Acceptance:

- Sandbox tests prove blocked filesystem, blocked network, timeout, bridge-only
  access, permission denial, and trace redaction.
- Script failures cannot corrupt raw records or accepted Memory.

### A6. Remote And Cloud Runner

Reference:

- Omi backend and per-user VM shape
- LangGraph durable remote execution pattern
- WideNote `apps/api`, `apps/runner-ts`, and TS packages

Target level:

- L1 contract first.
- L2 fake or local-loopback runner before any off-device runner.
- L3 user-visible queue/control with no live off-device dispatch.
- L4 self-hosted or official hosted runner after a runner RFC.

WideNote should build:

- A runner task envelope that includes pack id, agent id, input event refs,
  Context Packet or redacted inputs, permissions, model/tool grants, run mode,
  trace correlation, and expected output events.
- A local fallback or graceful degradation for core product flows.
- Runner result validation before outputs enter local object truth.

Boundary:

- No raw local database upload.
- No silent upload of private records, backups, provider keys, or credentials.
- No cloud-only capture, Memory, timeline, or trace.
- Remote outputs are derived until validated and source-linked locally.
- L1-L3 contracts may describe remote execution, but live remote execution is
  absent or no-op.

Acceptance:

- A fake runner round-trip test proves task envelope, permission denial,
  output validation, trace correlation, cancellation, and failure handling.

### A7. Persisted Runtime Control

Reference:

- Omi desktop sessions/runs/attempts/artifacts
- Memex run mode and approval service

Target level:

- L3 for local runs before external tools are broadly enabled.

WideNote should build:

- Durable task/run/attempt state with status, timestamps, source refs,
  permission snapshot, run mode, tool/model calls, failure reason, retry count,
  cancellation, and approval outcomes.
- Agent Console read models and Pack Management status derived from runtime
  state.

Boundary:

- Persisted runtime state is not full event sourcing for all app objects.
- Trace retention and export must follow privacy and backup/export policies.

Acceptance:

- Users can inspect why a pack ran, what it touched, what it produced, why it
  failed, and how to retry/cancel when allowed.

## B. Orchestration

### B1. Event Subscription Triggers

Target level: L2 now, L3 when user-visible pack status lands.

WideNote should build:

- Event-based triggers for captures, memory changes, todo review, scheduled
  recaps, webhook receipt, integration results, and future continuous-capture
  chunks.
- Idempotent task identity per event, pack, agent, and subscription.

Boundary:

- Agents must not poll private tables as their trigger mechanism.
- External webhook events are disabled until C7 permission design lands.

Acceptance:

- Duplicate events do not create duplicate derived outputs unless the pack
  explicitly declares non-idempotent behavior.

### B2. Pack Dependency Graph

Target level: L2 now, L3 with visible blocked state.

WideNote should build:

- Subscription dependencies with runnable, blocked, succeeded, failed, denied,
  canceled, and skipped states.
- Clear trace entries for why a dependent task is blocked.

Boundary:

- Dependencies are within a bounded run graph. Do not introduce an unbounded
  workflow engine in this slice.

Acceptance:

- Tests cover success, upstream failure, permission denial, cancellation, and
  retry.

### B3. Multi-Round Tool Loop

Reference:

- Omi Anthropic native tool-use loop
- OpenAI Agents SDK tool calls and guardrails

Target level: L1 contract before implementation, L2 for local tools, L3 for
mutating/external tools.

WideNote should build:

- A loop that lets an agent call declared tools repeatedly within configured
  max calls, max time, max tokens/cost where available, stop reasons, and
  permission scope.
- Trace events for every tool request, approval, execution, result, denial, and
  model continuation.

Boundary:

- No unbounded loops.
- No hidden tool discovery during a run unless the pack has a declared
  discovery permission.
- No tool call may bypass run mode or approval policy.

Acceptance:

- A failing or looping model exits with a bounded failure state and useful
  trace.

### B4. Bounded Subagents And Delegation

Reference:

- Memex SuperAgent child presets and scoped tool profiles
- OpenAI handoffs
- Google ADK multi-agent composition

Target level: L1 design first, L2 fixed official presets, L3 user-visible runs.

WideNote should build:

- Fixed child-agent presets with name, purpose, allowed tools, Context Packet
  surface, read/write permissions, timeout, output schema, and parent merge
  policy.
- Initial presets should be narrow: memory-review, todo-planner, recap-builder,
  research-readonly, and integration-diagnostics.
- Each child receives an explicit capability budget: tool allowlist, context
  surface, source refs, run mode, max duration, max tool calls, and token/cost
  budget when available.

Boundary:

- Initial child agents cannot spawn further child agents.
- No arbitrary user-created child agent until custom-agent authoring and
  permission UX exist.
- Child agents cannot receive broader context or tools than the parent run.
- A parent cannot use delegation to bypass its own approval, permission, or
  run-mode constraints.

Acceptance:

- Parent trace links to child run ids.
- Child output is rejected when it lacks source refs or violates schema.

### B5. Parallel Subtask Execution

Target level: L1 after B4, L2 for independent read-only child runs.

WideNote should build:

- Parallel execution for independent child runs with separate cancellation,
  timeout, trace, and result merge.

Boundary:

- No shared mutable state between child agents.
- Merge happens through validated output events or parent review, not direct
  object mutation.

Acceptance:

- One child failure does not corrupt successful sibling outputs.

### B6. Run Modes

Reference:

- Memex `read_only`, `confirm`, and `auto`

Target level: L3 before broad mutating tools.

WideNote should build:

- `read_only`: tools can inspect approved context but cannot mutate or export.
- `confirm`: mutating, external, or sensitive operations require approval.
- `auto`: low-risk declared operations can execute without interruption.

Boundary:

- External network, filesystem write, credential access, continuous capture,
  and destructive actions cannot default to auto.
- Background official packs may auto-run only inside low-risk permissions.

Acceptance:

- Tests prove mode-specific allow/deny behavior for representative read,
  write, external, and high-risk tools.

### B7. Approval Queue

Target level: L3.

WideNote should build:

- Approval requests with action summary, tool name, pack/agent/run ids, source
  refs, proposed payload diff where applicable, permission requested, expiry,
  approve-once/deny options, and trace outcome.

Boundary:

- Approval is not a way to permanently grant broad permissions unless the UI
  explicitly says so.
- Denied actions must not be retried blindly.
- The L3 approval store persists pending requests and decisions; it does not
  resume or execute a paused tool by itself. A later RuntimeKernel control
  bridge must atomically claim an approval decision with the affected task/run
  transition before any approved action executes.
- Startup recovery must classify stale approval requests as pending, expired,
  canceled, or orphaned before the user can approve them.

Acceptance:

- Denial returns a model-visible result so the agent can continue safely.
- Tests cover pending request persistence, decision persistence, expiry
  filtering, and the fact that pending approval stops execution without
  bypassing permission or run-mode policy.

### B8. Agent Console

Target level: L3.

WideNote should build:

- A user-facing control room for recent runs, active runs, failed runs,
  approvals, pack status, tool/model calls, outputs, source refs, retry, cancel,
  and permission-denied states.

Boundary:

- Console should explain behavior without exposing raw secrets, hidden prompts,
  provider keys, or private backups.
- Retry and cancel controls remain disabled until a live RuntimeKernel control
  provider exists. The UI must say this explicitly and must not fake success.

Acceptance:

- A user can answer: what ran, why it ran, what data it used, what it produced,
  and what needs approval.

### B9. Artifact Lifecycle

Target level: L1 first, L2 for metadata-only artifacts.

WideNote should build:

- Artifact metadata for reports, drafts, exported files, generated summaries,
  integration results, and diagnostics. Include source refs, privacy class,
  lifecycle state, creator run, and retention policy.

Boundary:

- Do not add rich file generation before export/backup/privacy rules are clear.
- Artifacts are derived outputs, not source truth.

Acceptance:

- Artifact deletion or export follows the same privacy boundary as other
  derived outputs.

## C. External Capabilities

### C1. Local Core Tool Catalog

Reference:

- Omi core tools for memory, conversations, todos, calendar, files, web, and
  health
- WideNote Memory, local DB, Context Packet, trace, and todo packages

Target level: L2 first, L3 with run modes and console.

WideNote should build these first-party local tools:

| Tool family | Minimum capabilities |
| --- | --- |
| Capture | Read source refs and safe previews; never overwrite raw captures. |
| Context | Build scoped Context Packets for chat, pack run, recap, trace review, and export preview. |
| Memory | Query accepted Memory, inspect proposals, create proposals, and attach source refs. |
| Todo | Suggest, create, update, complete, and source-link todos. |
| Cards/Insights | Create derived cards and insights through output events. |
| Trace | Read run traces for console and diagnostics with redaction. |
| Settings/Providers | Read non-secret provider metadata and runtime settings needed for behavior explanations. |

Boundary:

- Local tools are the only default tool surface.
- Tools cannot expose raw attachment contents beyond the run's permission mode.
- Tools cannot mutate source truth except through explicit user correction
  flows outside agent automation.

Acceptance:

- Each tool has JSON-schema-like input/output, permission id, trace event,
  deterministic fake, and denial test.

### C2. Context Packet Tool

Target level: L2 first, L3 when exposed to custom packs.

WideNote should build:

- A tool that takes surface, subject refs, privacy profile, source window,
  permission mode, and token/size budget, then returns a source-linked Context
  Packet.

Boundary:

- Agents do not request arbitrary SQL or table scans.
- Context Packet caches are rebuildable derived state, not source truth.

Acceptance:

- Redaction, cache invalidation, source refs, and permission scope are tested.

### C3. Memory Tools

Target level: L2 first, L3 with approval/review UI.

WideNote should build:

- Read accepted Memory by source ref, time, type, sensitivity, recency, and
  explicit search when available.
- Create Memory proposals with confidence, type, sensitivity, source refs, and
  review policy.
- Review actions remain user-visible when required by Memory policy.

Boundary:

- Agents cannot silently rewrite accepted Memory.
- Low-confidence, sensitive, conflicting, or unsupported Memory goes to review.

Acceptance:

- Tests cover auto-accept, review routing, conflict, tombstone, merge, and
  source-ref preservation.

### C4. Todo Tools

Target level: L2 first, L3 before mutating todos by default.

WideNote should build:

- Suggest todos from capture or chat context.
- Create/update/complete todos only under run mode and permission policy.
- Preserve source refs and user review action when relevant.

Boundary:

- Agent-generated todos must be distinguishable from user-created todos until
  accepted or edited by the user.
- No calendar/email/task-system sync until external tool contracts land.

Acceptance:

- Mutating todo tools are blocked in read-only mode and approval-gated in
  confirm mode.

### C5. HTTP App Tools

Reference:

- Omi app tools manifest, webhook health, and circuit breaker

Target level: L1 contract first, L2 fake/local-loopback tool execution, L3 UI
guardrails, L4 live external HTTP tools after an external-tool RFC.

WideNote should build:

- Tool manifest fields for endpoint, method, declared hosts, auth type,
  request/response schema, status message, timeout, retry policy, circuit
  breaker, privacy class, and permission id.

Boundary:

- No arbitrary host calls.
- No sending raw records by default.
- No credential values in prompts, traces, docs, fixtures, or exports.
- External tool failures must not block local core capture.
- L1-L3 must not perform live external HTTP calls. They may validate manifests,
  run local fakes, and render permission/review UI.

Acceptance:

- A fake HTTP tool proves success, timeout, host denial, auth missing,
  circuit-breaker open, and redacted trace behavior.

### C6. MCP Bridge

Reference:

- Omi MCP server and MCP streamable HTTP/server concepts
- MCP official specification

Target level: L1 design, L2 local MCP fake or loopback dev mode, L3 UI
guardrails, L4 live MCP client/server exposure after an MCP RFC.

WideNote should build:

- MCP client support for approved external tools.
- MCP server/gateway support that exposes approved WideNote resources and tools
  such as memory read, context packet build, todo operations, and trace read.

Boundary:

- MCP exposure is off by default.
- External MCP servers need declared transport, host, scopes, and permission.
- WideNote MCP server cannot expose all local data by default.
- L1-L3 must not connect to remote MCP servers or expose a remotely reachable
  MCP server.

Acceptance:

- Tool/resource lists reflect permissions and revocation immediately.

### C7. Webhook Triggers

Reference:

- Omi conversation-created and realtime integration triggers

Target level: L1 contract before implementation.

WideNote should build:

- Inbound and outbound webhook contracts with event type allowlist, payload
  schema, redaction profile, retry, backoff, dead-letter state, health checks,
  and revocation.

Boundary:

- Webhooks are disabled by default.
- No realtime raw audio, screen, or full capture payload without a high-risk
  permission and explicit user review.

Acceptance:

- Failed webhook delivery is visible and cannot retry forever.

### C8. Real Third-Party Integrations

Reference:

- Omi calendar, Gmail, health, file, and app integrations

Target level: L1 design after C5/C6/C7, L2 local fake or fixture-backed
integration, L4 per real integration after an integration RFC.

WideNote should build:

- Integrations as packs/tools using the external capability contracts, not
  bespoke shortcuts.
- OAuth or credential storage that is local, secret-safe, revocable, and
  excluded from safe owner export.

Boundary:

- Do not hard-code one integration path before the generic tool/MCP contract
  is stable.
- Do not sync third-party data into source truth without source refs and
  permission design.
- L1-L3 must not connect to real third-party services.

Acceptance:

- First real integration proves permission grant, revoke, trace, source refs,
  failure handling, and safe backup/export behavior.

### C9. Web Search And URL Fetch

Target level: L1 contract, L2 fake/local test tool, L3 UI guardrails, L4 live
web access after a web-access RFC.

WideNote should build:

- Separate permissions for public URL fetch, web search, and authenticated web
  content.
- Returned web content should carry URL, retrieval timestamp, and citation refs.

Boundary:

- Disabled by default on privacy-sensitive surfaces.
- No browser cookies, private browsing data, or authenticated pages unless a
  separate high-risk permission exists.
- L1-L3 must not perform live web fetch or search.

Acceptance:

- Web-derived insights are distinguishable from personal-record-derived
  insights.

### C10. File-System Tools

Reference:

- Memex scoped file tools and permission manager

Target level: L1 contract, L2 for user-selected import/export roots.

WideNote should build:

- User-selected file import/export, backup, attachment, and developer workspace
  roots with read/write scopes.

Boundary:

- No broad home directory scan.
- No shell execution.
- No hidden indexing of user files.

Acceptance:

- File access outside the granted root fails with a non-retriable permission
  error and trace entry.

## D. Memory, Retrieval, And Context

### D1. Raw Record Source Truth

Target level: L2 now, L3 with review/trace UX.

WideNote should build:

- Raw captures and original attachments as canonical user input.
- Corrections and revisions as explicit user actions, not AI overwrites.

Boundary:

- Derived outputs cannot replace raw records.

Acceptance:

- Agent failures never remove or hide the original capture.

### D2. Source References Everywhere

Target level: L2 now, L3 across all derived surfaces.

WideNote should build:

- Source refs on Memory, cards, insights, todos, recaps, chat answers, artifacts,
  traces, and external integration outputs.

Boundary:

- Any output without required source refs is rejected or routed to review.

Acceptance:

- UI can navigate from derived output back to source context where allowed.

### D3. Vector And Semantic Retrieval

Reference:

- Omi Pinecone/vector search
- Industry semantic retrieval patterns

Target level: L1 design, L2 local rebuildable index before remote index.

WideNote should build:

- Rebuildable local embedding or semantic indexes with source refs, generator
  version, privacy scope, deletion/purge invalidation, and export policy.

Boundary:

- Vector indexes are derived caches, not source truth.
- Remote embeddings or indexes require provider permission and privacy review.
- Safe owner export excludes semantic caches by default.

Acceptance:

- Deleting or purging source records invalidates derived semantic entries.

### D4. Model-Guided Semantic Selection

Reference:

- ADR-0010

Target level: L2 for current model-backed chat/agent flows.

WideNote should build:

- Models choose relevant material from governed Context Packets or search
  results. Trace the packet/search source and preserve citations.

Boundary:

- No core local keyword heuristics for semantic decisions.
- Model selection cannot access data outside the run's permission scope.

Acceptance:

- Tests prove semantic selection uses supplied Context Packet/search inputs and
  preserves citations.

### D5. Graph And Organization Layers

Reference:

- Memex P.A.R.A and graph-like workspace patterns

Target level: L1 design, L2 derived views.

WideNote should build:

- Derived organization views such as topics, projects, areas, entities,
  timelines, maps, or graph edges when they help recall and insight.

Boundary:

- Graph/P.A.R.A views are not canonical source truth.
- Memory-first remains the core product model.
- Organization layers must be rebuildable or reviewable derived state.

Acceptance:

- Removing a graph edge does not delete source records or accepted Memory unless
  the user explicitly performs those actions.

## E. Product Experience

### E1. Preserve The Core Product Loop

Target level: L2 now, L3 as advanced capabilities land.

WideNote should build:

- The default first screen and default mental model stay:
  quick capture -> timeline/cards -> Memory -> insight.

Boundary:

- Agent Console, packs, external tools, backend setup, and continuous capture
  cannot become first-run prerequisites.

Acceptance:

- A new user can capture, see the raw record, get local derived outputs, and
  inspect source refs without account setup.

### E2. Agent Console

Target level: L3 before broad external tools.

WideNote should build:

- User-facing explanations, approvals, retry/cancel, trace details, pack status,
  tool/model calls, source refs, and failure recovery.

Boundary:

- Do not expose secret values or raw private exports.
- Do not require users to understand internal package names to make decisions.

Acceptance:

- For a failed run, the console shows the cause, affected pack, source event,
  next possible action, and residual risk.

### E3. Pack Management

Target level: L3 before custom agents.

WideNote should build:

- Pack list, runtime type, publisher, edition, status, permissions, last run,
  failures, enable/disable, revoke permissions, and update availability.

Boundary:

- Official packs can be visible before community install exists.
- Store/community install requires trust/signature or equivalent review policy.

Acceptance:

- Disabling a pack prevents future task creation and explains existing pending
  tasks.

### E4. Custom Agent Authoring

Reference:

- Memex custom agent prompts/skills
- Omi apps/plugins

Target level: L1 design, L2 local-dev, L3 user-facing after declarative packs.

WideNote should build:

- Authoring for trigger, prompt, Context Packet surface, tool list,
  permissions, model profile, run mode, output schema, and review policy.

Boundary:

- No arbitrary script by default.
- No external network or filesystem by default.
- Custom agents must be exportable/reviewable as manifests.

Acceptance:

- A custom read-only agent can be created, run, inspected, disabled, and
  exported without gaining write or network permissions.

### E5. Continuous Capture Surfaces

Reference:

- Omi audio, desktop, wearable, and realtime capture surfaces

Target level: L1 design, L2 manual import/share or local fixture experiments,
L3 explicit local opt-in experiments after privacy and platform permission
review, L4 production continuous capture after a dedicated RFC.

WideNote should build:

- Optional audio, screen, wearable, share/import, and other capture surfaces
  with visible recording state, source refs, review, redaction, and stop/pause.

Boundary:

- No default background recording.
- No stealth capture.
- No raw realtime stream to external tools without high-risk permission.
- Continuous capture outputs must still enter the same raw-record and derived
  Memory pipeline.
- No L1-L3 feature may simulate continuous capture through hidden polling of
  sensors, screen, files, network, clipboard, or location.

Acceptance:

- Users can see what is being captured, stop it, review source records, delete
  or purge them, and inspect which agents consumed them.

## Data Model / API / UX

Every implementation issue should name:

- manifest fields
- permission ids
- tool schemas or runtime APIs
- trace event types
- source-ref requirements
- run-mode behavior
- approval behavior
- local/offline behavior
- backup/export behavior
- tests and, for user-visible Flutter work, widget tests

Suggested permission namespaces:

- `capture.read`
- `context_packet.build`
- `memory.read`
- `memory.propose`
- `todo.suggest`
- `todo.write`
- `card.write`
- `insight.write`
- `trace.read`
- `tool.http.declared_host`
- `tool.mcp.call`
- `tool.mcp.expose`
- `web.fetch.public`
- `web.search.public`
- `file.read.user_selected`
- `file.write.user_selected`
- `runner.remote.execute`
- `capture.continuous.audio`
- `capture.continuous.screen`

## Privacy and Security Impact

This RFC increases the planned capability surface. The privacy posture must be
more explicit, not weaker:

- Default local tools can run without account setup.
- External tools, MCP, webhooks, remote runners, web access, filesystem access,
  and continuous capture require explicit permission design.
- Provider keys, OAuth tokens, credentials, local DB files, backup files, and
  raw private records must not be sent to external review, traces, fixtures, or
  docs.
- Runtime trace payloads, task/run errors, redacted trace tools, and Agent
  Console read models must sanitize known credential-like strings. Raw stack
  traces and platform crash logs are outside the L3 console read model until a
  shared redaction pipeline owns those sinks.
- L1-L3 implementation must not add live off-device calls. Off-device execution,
  external tool calls, remote MCP, webhooks, web access, remote runners, and
  telemetry require an L4 RFC and explicit user opt-in.
- Secret-bearing backup and safe owner export remain separate.
- Revocation must stop future use and explain whether prior traces/artifacts
  remain.

## Local-First and Sync Impact

Local-first means:

- local capture works offline
- local records remain readable offline
- local Memory and trace review work offline
- local Pack status is inspectable offline
- backend/runner failures degrade gracefully

Future sync and runner work must preserve:

- local object ids and source refs
- tombstone/purge semantics
- rebuildable derived caches
- conflict handling for derived outputs
- clear distinction between local truth and remote-derived outputs

## Agent / Plugin Impact

Agent Packs are the durable extension boundary.

- Official native packs prove behavior first.
- Declarative packs move behavior into manifest-first execution.
- Script packs wait for sandbox RFC.
- HTTP/MCP tools wait for external capability RFCs before live off-device use.
- Community/store packs wait for trust, permission, update, and revocation
  policies.

## Alternatives

- Follow Omi more directly: rejected as default because it would make cloud
  services and continuous integrations too central for WideNote's local-first
  loop.
- Follow Memex more directly: rejected as default because WideNote is not a
  P.A.R.A/file-workspace-first product.
- Keep only phase-one native packs: rejected because it would under-specify the
  planned backend and external capability direction.

## Migration / Compatibility

- ADR-0011 remains the durable roadmap decision.
- This RFC should be treated as the boundary checklist for implementation
  issues created under GitHub issue #14.
- Existing official native packs remain valid but must keep aligning with
  manifest, permission, trace, and output-event contracts.
- Future RFCs may refine specific slices such as local core tools, run modes,
  Agent Console, HTTP tools, MCP, remote runners, script sandbox, and continuous
  capture.

## Open Questions

- Which local core tools should ship first: Memory, todo, Context Packet, or
  trace/console tools?
- Should remote runner outputs require user approval before entering local
  derived objects?
- Should MCP exposure ship before or after HTTP app tools?
- What trust model should store/community packs use: signatures, verified
  publishers, local-only warning, or a combination?
- What retention policy should long-running traces and artifacts use?

## Review Notes

Kimi performed a text-only architecture review of this RFC summary. Verdict:
`CONDITIONAL APPROVE`; no blockers. P1 risks centered on boundary erosion:

- backend planned-but-optional could drift into a de facto cloud dependency
- off-device export must be absent or no-op in L1-L3, not merely disabled by
  default
- subagents need capability attenuation rather than inherited host authority
- Omi and Memex references must remain architecture analogies, not copied code,
  protocols, identity/auth, telemetry, data model, sync, or storage layout
- L1-L3 must not hide continuous capture behind polling or frequent context
  refresh
- dynamic code loading from network origins must remain absent in L1-L3
- GPL code needs a merge-blocking license gate

This RFC was updated to incorporate those guardrails.

## Decision Outcome

Proposed as the implementation guardrail for ADR-0011. Link this RFC from
future implementation issues and split narrower RFCs when a slice changes
schema, privacy, sync, runtime, or public API behavior.
