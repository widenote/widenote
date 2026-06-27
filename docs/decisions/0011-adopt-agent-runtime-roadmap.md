---
id: ADR-0011
title: Adopt the WideNote Agent Runtime and Capability Roadmap
status: accepted
date: 2026-06-27
owners: [core, agents, product, privacy]
tags: [agent-runtime, orchestration, external-tools, local-first, backend, memory]
supersedes: []
superseded_by:
sources:
  - ../research/2026-06-27-agent-runtime-roadmap-research.md
  - ../rfcs/agent-runtime-capability-boundaries.md
  - https://github.com/widenote/widenote/issues/14
  - ./0003-build-agent-runtime-kernel.md
  - ./0007-defer-cloud-sync-from-core-phase-one.md
  - ./0009-use-object-truth-and-context-packets.md
  - ../rfcs/agent-pack-schema.md
  - https://github.com/BasedHardware/omi/tree/d7e89504b3e1f0b5281eff9f8503a21c6d88cc8a
  - https://github.com/memex-lab/memex/tree/d1fc2351fb6144afbde5117d00dc97edd4c880ad
  - https://openai.github.io/openai-agents-python/
  - https://modelcontextprotocol.io/specification/
  - https://langchain-ai.github.io/langgraph/
  - https://google.github.io/adk-docs/
---

# Adopt the WideNote Agent Runtime and Capability Roadmap

## Context

WideNote already has a lightweight local Agent Runtime Kernel, official native
Agent Packs, local trace storage, local object truth, Context Packets, and a
Memory-first product model.

The 2026-06-27 planning discussion compared WideNote with Omi, Memex, and
current agent-platform patterns. The product direction changed from "keep the
kernel narrow until phase-one closure" to "make the full agent runtime roadmap
explicit now, while still implementing it in staged slices."

The important clarification is that local-first is not local-only. WideNote must
continue to work without an account or official backend, but backend services,
sync, remote runners, external tool registries, MCP endpoints, and hosted
execution are planned extension surfaces. The long-term shape is closer to
Omi's service topology than to a purely offline note app, while the data and UX
contract stays anchored in WideNote's local source truth.

## Decision

Continue building and owning WideNote's Agent Runtime Kernel.

For this ADR, the Agent Runtime Kernel means the in-process product runtime that
manages local agent lifecycle and contracts: event routing, task creation,
pack registration, tool invocation, model invocation, permissions, trace
emission, output-event validation, and local run state. It is not a model SDK,
not a cloud workflow engine, not a remote runner process, and not a general
purpose scripting VM. Those pieces can integrate through adapters.

Third-party agent frameworks, MCP servers, cloud runners, model SDKs, workflow
engines, and scripting runtimes are integration targets or adapters. They do
not replace the WideNote kernel because the kernel owns product semantics that
external frameworks cannot decide for us: raw record preservation, source
references, Memory policy, Pack permissions, trace review, user approval, and
local-first fallback.

The planned backend/service topology is:

- mobile client as the default local runtime host and local object-truth owner
- optional backend API for account, sync, backup coordination, registry, and
  remote-control surfaces
- optional runner services for user-approved long-running or heavy agent work
- optional app/tool registry for declared HTTP tools, MCP servers, and pack
  distribution
- optional webhook broker for external integrations
- optional MCP gateway for exposing approved WideNote capabilities and calling
  approved external capabilities

This is Omi-like in topology breadth, not in default dependency. The first user
experience must not depend on any of these services.

Accept the following roadmap decisions.

These decisions are roadmap requirements, not a single iteration scope. The
immediate implementation sequence is:

1. Define schemas, permissions, run modes, and trace contracts.
2. Implement local core tools and Context Packet tools.
3. Add persisted run control, Agent Console, Pack status, and approval gates.
4. Add bounded subagent/delegation primitives.
5. Add HTTP and MCP external tool declarations.
6. Add script runtimes, remote runners, real third-party integrations, and
   continuous-capture surfaces only after their RFCs and permission reviews land.

Immediate non-goals for the first slice after this ADR: broad community pack
installation, unrestricted filesystem access, default web access, default
continuous audio or screen capture, and cloud-only agent execution.

## A. Engine And Runtime Environment

| ID | Decision point | What it does | Decision |
| --- | --- | --- | --- |
| A1 | Self-owned Runtime Kernel | Owns event routing, task execution, permissions, traces, tools, models, and Pack output validation. | Accepted. Continue self-development and strengthen it. |
| A2 | Third-party agent framework adapters | Lets WideNote integrate OpenAI Agents SDK, LangGraph, Google ADK, or similar frameworks where they help. | Accepted as adapters only. Do not replace the kernel. |
| A3 | Native Pack runtime | Runs official first-party packs in Dart/Flutter with strict manifest alignment. | Accepted as the default trusted runtime. |
| A4 | Declarative Pack runtime | Executes packs whose triggers, inputs, outputs, tools, and policies are defined by manifest/schema rather than handwritten app code. | Accepted roadmap item. Required for scalable official and community packs. |
| A5 | Script Pack runtime | Runs pack logic in a sandboxed scripting environment such as JavaScript or another constrained runtime. | Accepted roadmap item. Must wait for sandbox, timeout, bridge, permission, and audit design. |
| A6 | Remote/cloud runner | Executes selected agent work on self-hosted or official backend services while preserving local source truth and fallback. | Accepted roadmap item. Backend services are planned; they are optional enhancements, not prerequisites for the default loop. |
| A7 | Persisted runtime control | Stores task/run/attempt/status, grants, cancellations, retries, and inspection state. | Accepted. Expand existing local runtime state into a user-visible control plane. |

## B. Orchestration

| ID | Decision point | What it does | Decision |
| --- | --- | --- | --- |
| B1 | Event subscription triggers | Starts agent work from events such as capture-created, memory-changed, todo-reviewed, or external webhook-received. | Accepted. Existing implementation stays foundational. |
| B2 | Pack dependency graph | Lets one pack wait on another pack's output or declared capability. | Accepted. Add visible blocked/runnable states and tests. |
| B3 | Multi-round tool loop | Lets a model call tools repeatedly until it has enough information or reaches a guardrail. | Accepted. Must include max-call limits, trace entries, permission checks, and stop conditions. |
| B4 | Bounded subagents/delegation | Lets a parent agent delegate a bounded task to a child agent with fixed tools, context, timeout, and result contract. | Accepted. Use Memex as clean-room pattern input, but implement with WideNote Pack and Context Packet semantics. |
| B5 | Parallel subtask execution | Runs independent delegated tasks concurrently and merges results through source-linked outputs. | Accepted. Requires B4, cancellation semantics, and merge policy first. |
| B6 | Run modes | Provides read-only, confirm-before-mutation, and auto execution modes. | Accepted. User-facing safety control for mutating tools. |
| B7 | Approval queue | Pauses high-risk or mutating operations until the user approves or rejects them. | Accepted. Approval outcome must be traceable. |
| B8 | Agent Console | Shows runs, tasks, traces, failure reasons, retries, cancellation, permissions, and source outputs. | Accepted. Required for trust and debugging. |
| B9 | Artifact lifecycle | Tracks reports, drafts, files, or structured results produced by agent runs. | Accepted. Start with metadata and source refs before adding rich file outputs. |

## C. External Capabilities

| ID | Decision point | What it does | Decision |
| --- | --- | --- | --- |
| C1 | Local core tool catalog | Exposes safe local tools for capture, Memory, todos, cards, insights, traces, and settings. | Accepted. Highest-priority capability layer. |
| C2 | Context Packet as a tool | Lets agents request scoped, source-linked context instead of scanning local tables directly. | Accepted. Must preserve permission mode, source refs, cache semantics, and redaction. |
| C3 | Memory query and write tools | Lets agents read accepted Memory, inspect proposals, and create source-linked Memory proposals. | Accepted. Writes should use proposal/review policy, not direct overwrite. |
| C4 | Todo tools | Lets agents suggest, create, update, complete, and source-link todos. | Accepted. Mutating actions follow run mode and approval policy. |
| C5 | HTTP app tools | Lets packs declare external HTTP tools with schema, auth, host constraints, status messages, and failure policy. | Accepted. Use Omi app-tool manifests as a reference shape, but design WideNote permissions first. |
| C6 | MCP bridge | Lets WideNote call MCP tools and expose approved WideNote tools/resources to external MCP clients. | Accepted. Required for long-term ecosystem compatibility. |
| C7 | Webhook triggers | Lets external apps receive or send events such as capture-created, recap-ready, or integration-result. | Accepted. Must be off by default and permissioned because it can export user context. |
| C8 | Real third-party integrations | Adds concrete integrations such as calendar, mail, documents, task tools, health, storage, and chat systems. | Accepted. Build on C5/C6/C7 instead of one-off integration code. |
| C9 | Web search and URL fetch | Allows agents to read public web context when explicitly permitted. | Accepted. Default should be disabled or confirm-gated for privacy-sensitive surfaces. |
| C10 | File-system tools | Allows scoped file import, export, backup, attachment, and developer workflows. | Accepted. Do not grant broad file access; use scoped roots and run modes. |

## D. Memory, Retrieval, And Context

| ID | Decision point | What it does | Decision |
| --- | --- | --- | --- |
| D1 | Raw record source truth | Preserves original captures and user records as canonical source input. | Accepted. Non-negotiable. |
| D2 | Source references everywhere | Requires derived Memory, cards, insights, todos, recaps, and chat answers to preserve supporting source refs. | Accepted. Strengthen tests and schema coverage. |
| D3 | Vector and semantic retrieval | Adds embeddings or semantic indexes for recall beyond recency/source refs. | Accepted roadmap item. Must remain rebuildable derived state and respect privacy/export rules. |
| D4 | Model-guided semantic selection | Lets models choose relevant source material from governed Context Packets instead of local keyword heuristics. | Accepted. Align with ADR-0010. |
| D5 | Graph and organization layers | Adds knowledge graph, project/area/resource views, or other organization structures. | Accepted as derived views. Memory remains the product core; graph/PKM structures must not replace raw records or accepted Memory. |

## E. Product Experience

| ID | Decision point | What it does | Decision |
| --- | --- | --- | --- |
| E1 | Preserve the core product loop | Keeps quick capture -> timeline/cards -> Memory -> insight as the default user loop. | Accepted. Backend and advanced agents must not obscure this loop. |
| E2 | Agent Console experience | Gives users a plain control room for what agents did, why, and what they need next. | Accepted. Product requirement, not only developer diagnostics. |
| E3 | Pack management | Lets users inspect official/custom packs, permissions, runtime type, status, failures, and revocations. | Accepted. Required before broad external capabilities. |
| E4 | Custom agent authoring | Lets users create or install agents with prompts, triggers, tools, model profiles, and review modes. | Accepted roadmap item. Requires declarative packs and permission UX first. |
| E5 | Continuous capture surfaces | Supports optional audio, screen, wearable, share/import, and other lifelog-style inputs. | Accepted roadmap item. Must be explicit, permissioned, reviewable, and source-preserving. |

## Considered Options

- Freeze the current local-only kernel scope until phase one ends.
- Replace the kernel with a third-party agent framework.
- Follow Omi as a cloud-first agent and lifelog platform.
- Follow Memex as a local file-workspace SuperAgent product.
- Use WideNote's own local-first kernel as the source of truth, while planning
  Omi-like backend services and Memex-like local orchestration as staged
  capability layers.

## Rationale

The accepted roadmap keeps WideNote's core semantics under product control
while preventing a false local-only ceiling.

Omi shows that external capability, MCP, app manifests, webhooks, realtime
triggers, and hosted execution are strategically important. Memex shows that
bounded subagents, run modes, approval, local tool scopes, and skill execution
are important for a useful in-app agent environment. Industry frameworks confirm
that tools, handoffs, durable state, tracing, guardrails, and human review are
standard agent-platform primitives.

WideNote should absorb those primitives into its own object-truth, Memory-first,
source-linked, permissioned runtime.

## Consequences

- The Agent Runtime Kernel becomes a long-term platform surface, not a phase-one
  implementation detail.
- ADR-0007 remains valid for phase one, but it is clarified: backend services
  are deferred from the default core loop, not rejected from the product.
- Future implementation must split contracts before UI work: schema, manifest,
  permissions, traces, run modes, and tool declarations should land before
  broad custom-agent or integration screens.
- Every external capability needs a privacy and trace story before it ships.
- This roadmap is intentionally larger than one iteration. Implementation work
  must be tracked through issues and smaller RFCs/ADRs.

## Follow-ups

- Use GitHub issue <https://github.com/widenote/widenote/issues/14> to expand
  A-E into implementation slices.
- Use `docs/rfcs/agent-runtime-capability-boundaries.md` as the guardrail for
  capability scope, boundary, and acceptance criteria when splitting those
  slices.
- Draft RFCs for local core tools, run modes/approval, Agent Console, and
  external HTTP/MCP tool declarations.
- Run sanitized Kimi review on the research note and this ADR; record findings
  in `docs/research/`.
- Update project-map and onboarding docs so future agents treat backend
  services as planned optional surfaces rather than as rejected scope.
