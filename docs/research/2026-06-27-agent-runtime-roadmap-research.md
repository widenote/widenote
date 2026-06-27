# Agent Runtime Roadmap Research

Status: direction research for ADR-0011
Date: 2026-06-27
Scope: Agent engine, runtime environments, orchestration, memory/context, and
external capabilities after comparing Omi, Memex, and current industry patterns.

## Inputs

- BasedHardware Omi snapshot:
  <https://github.com/BasedHardware/omi/tree/d7e89504b3e1f0b5281eff9f8503a21c6d88cc8a>
- memex-lab Memex snapshot:
  <https://github.com/memex-lab/memex/tree/d1fc2351fb6144afbde5117d00dc97edd4c880ad>
- WideNote runtime docs and ADRs:
  - `docs/architecture/runtime.md`
  - `docs/rfcs/agent-pack-schema.md`
  - `docs/decisions/0003-build-agent-runtime-kernel.md`
  - `docs/decisions/0007-defer-cloud-sync-from-core-phase-one.md`
  - `docs/decisions/0009-use-object-truth-and-context-packets.md`
  - `docs/decisions/0010-delegate-semantic-selection-to-models.md`
- Tracking issue:
  - <https://github.com/widenote/widenote/issues/14>
- Industry references used as pattern checks:
  - OpenAI Agents SDK: <https://openai.github.io/openai-agents-python/>
  - Model Context Protocol: <https://modelcontextprotocol.io/specification/>
  - LangGraph: <https://langchain-ai.github.io/langgraph/>
  - Google Agent Development Kit: <https://google.github.io/adk-docs/>

## Product Owner Direction

The accepted direction from the 2026-06-27 planning discussion is:

- WideNote continues to own its Agent Runtime Kernel instead of replacing it
  with a third-party agent framework.
- WideNote remains local-first: the mobile client must work without an account
  or official backend for capture, local persistence, local Memory, local trace,
  and the first user experience.
- Local-first does not mean local-only. Backend services, sync, remote runners,
  external tool registries, MCP endpoints, and hosted execution are planned
  product surfaces. The eventual topology is closer to Omi than to a purely
  offline note app, but backend services must enhance rather than replace local
  truth.
- Runtime variants that are not implemented today are still part of the
  roadmap: declarative packs, script packs, remote/cloud runners, and richer
  persisted runtime control.
- All orchestration, external capability, memory/context, and product-control
  decision points from the Omi/Memex comparison enter the roadmap. Prioritizing
  them across iterations is still open, but none of those categories should be
  treated as rejected.

## Omi Pattern Summary

Omi is strongest as a broad external-capability and lifelog platform.

Useful patterns:

- A backend agent loop can expose a large core tool catalog and dynamically add
  app-provided tools.
- App tools can be discovered through a manifest, converted into model-callable
  schemas, executed through HTTP or MCP, and protected with health checks and
  circuit breakers.
- Realtime triggers, conversation-complete triggers, and webhook delivery make
  integrations feel like an operating environment instead of a passive plugin
  list.
- MCP servers are a useful boundary for exposing memory, conversation, and
  search capabilities to user-owned agents and external clients.
- A desktop runtime with sessions, runs, attempts, artifacts, grants, and
  delegation provides a strong control-plane shape for long-running agent work.

Fit risks for WideNote:

- Omi's default architecture is cloud-heavy. Firebase, hosted backends,
  transcription services, vector infrastructure, and per-user VMs cannot become
  prerequisites for WideNote's default capture loop.
- Continuous audio, screen, email, calendar, and health integrations create a
  large privacy surface. WideNote can support them later only behind explicit
  permissions, reviewable traces, and clear source references.
- Omi's breadth should be treated as a service topology reference, not as a
  reason to abandon WideNote's local object truth.

## Memex Pattern Summary

Memex is strongest as a local agent workspace with rich in-app orchestration.

Useful patterns:

- A SuperAgent can delegate bounded work to child agents with fixed presets,
  scoped tools, scoped read/write roots, timeouts, and structured results.
- Run modes such as read-only, confirm, and auto are a practical user-facing
  control model for mutating tools.
- A local file permission manager shows how tool access can be scoped by
  explicit roots rather than by broad ambient authority.
- A JavaScript runtime can make skill execution flexible, but it must be gated
  by sandboxing, timeouts, bridge contracts, and permissions.
- Context compression, hooks, and child-agent prompts are useful when agent work
  becomes long-running or multi-step.

Fit risks for WideNote:

- Memex is centered on a P.A.R.A-like workspace and file/tool operations.
  WideNote should remain Memory-first; project/area/resource views can be
  derived organization layers, not the canonical product model.
- Memex is GPL-licensed. WideNote should use it as a clean-room reference for
  product and architecture patterns, not as copied implementation.
- File-system tools should not become WideNote's default external ability.
  They are useful for import/export, attachments, backup, and developer modes.

## Industry Pattern Checks

OpenAI Agents SDK is relevant because it makes tools, handoffs, tracing, and
guardrails first-class concepts. WideNote should map those concepts onto its own
runtime instead of making a third-party SDK the kernel.

MCP is relevant because it separates tool/resource exposure from a single app
runtime. WideNote should support MCP as an external-capability boundary, both
for calling declared tools and for exposing user-approved WideNote capabilities
to external clients.

LangGraph is relevant because it treats long-running agent flows as stateful,
durable graphs with human-in-the-loop checkpoints. WideNote should borrow the
durable-state and approval concepts for runs, retries, and review gates.

Google ADK is relevant because it frames multi-agent systems as composed agents,
tools, deployment targets, and evaluation surfaces. WideNote should use that as
validation that subagents, tool boundaries, and runner deployment should be
designed together.

## Roadmap Implications

The next major roadmap should not be a single feature. It should be a set of
capability tracks:

1. Runtime environment expansion: native, declarative, script, and remote runner
   execution all share the same manifest, permission, trace, and output-event
   semantics.
2. Orchestration: event subscriptions, dependencies, tool loops, bounded
   subagents, approval gates, run modes, control plane, and artifacts.
3. External capability: local tools first, then HTTP tools, MCP, webhooks,
   real integrations, web access, and file tools with explicit permissions.
4. Memory and context: raw object truth, source-linked derived outputs,
   Context Packet tool access, semantic/model selection, vector search, graph
   organization, and review policy.
5. Product controls: Agent Console, Pack Management, custom agent authoring,
   and optional continuous capture surfaces.

## Review Notes

Kimi review was attempted with a full sanitized prompt containing this research
note and ADR-0011. That run did not return within the review window and was
interrupted.

A smaller text-only Kimi review of the ADR summary completed. Verdict:
`APPROVE with revisions`; no blockers. P1 risks:

- define "self-owned Agent Runtime Kernel" with an explicit scope boundary
- replace vague "Omi topology" wording with a concrete service topology
- separate future runtimes from immediate implementation
- clarify that "all items enter the roadmap" does not mean one iteration or no
  prioritization
- turn governance nouns such as permissions, traces, approvals, Context
  Packets, and source refs into an ordered implementation sequence

ADR-0011 was updated to resolve these review findings. Raw user records, local
databases, backups, credentials, tokens, and private traces were not included in
the Kimi prompt.
