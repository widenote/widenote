# 2026-06-23 Phase One Technical Research

Status: draft

Scope: technical research and review notes for WideNote phase one

This note summarizes the research that informed `docs/architecture/phase-one-technical-plan.md` and `docs/architecture/phase-one-module-plan.md`.

## Research Inputs

- Public MemeX repository and README for product capability reference.
- Current public MemeX main implementation for design critique and avoid-list.
- User-linked MemeX memory-primary branch for Memory-first behavioral direction.
- Public Omi repository and developer docs for four-tab product shape, app marketplace, and integrations.
- Public framework docs for runtime principles: LangGraph, OpenAI Agents SDK, CrewAI, and durable queue/workflow patterns.
- Six parallel subagent reviews:
  - Overall architecture and clean-room boundary.
  - Local storage, Drift/SQLite, filesystem, Memory, search, backup, restore, export.
  - Agent Runtime and Agent Pack protocol.
  - UI/interaction and phase-one capability coverage.
  - Backend, sync, runner, plugin marketplace, integrations.
  - Module plan and progressive context loading.

Kimi CLI review was attempted with the local command during this first pass, but it failed with `401 invalid_authentication_error`, indicating the local API key was invalid or expired. Kimi login was later fixed and architecture/code reviews were rerun; see `docs/research/2026-06-23-kimi-review-followup.md`.

## External Findings

MemeX is a local-first AI journal for iOS and Android. Its public README describes fragment capture through text, photos, and voice; AI organization into cards; insights; companion characters; local storage through filesystem and SQLite; app lock; backup/restore; multi-provider BYOK model setup; and a custom agent system with event triggers, per-agent model configuration, skill files, working directories, JavaScript execution, dependencies, sync/async modes, and retry behavior.

Omi positions itself as a second brain across desktop, phone, and wearables. The public README and docs show a Flutter mobile app, backend APIs for memories/conversations/action items, app/plugin ecosystem, MCP support, and developer app structure under `plugins/`. Its product structure strongly supports a home/conversations/action-items/apps mental model, but WideNote should not copy the always-on capture posture by default.

LangGraph emphasizes durable execution, persistence, streaming, and human-in-the-loop as orchestration runtime concerns. The useful lesson for WideNote is to separate durable run state from long-term Memory and to make interrupt/retry boundaries explicit.

OpenAI Agents SDK documentation frames agents as applications that plan, call tools, collaborate, and keep enough state for multi-step work. It is useful as a source of concepts around tools, handoffs, guardrails, tracing, and application-owned orchestration, but WideNote should not bind its runtime model to one SDK.

CrewAI highlights agents, flows, tasks, guardrails, memory, knowledge, and observability. The useful lesson is lifecycle visibility and structured process design; WideNote should avoid adopting a role-playing framework as its product kernel.

## Synthesis

The converged architecture is:

```text
local mobile runtime
  -> append-only events
  -> declarative Agent Pack subscriptions
  -> durable local task DAG
  -> PermissionBroker-gated model/tool/context calls
  -> output events
  -> Memory/cards/insights/todos/UI blocks
  -> local trace and audit review
```

The product should copy the capability shape, not implementation details:

- Complete MemeX-style functionality except PKM/PARA core.
- Omi-style tab organization and plugin ecosystem shape.
- WideNote-owned Memory-first data model.
- WideNote-owned Agent Runtime and Pack manifest.
- Local-first default with optional encrypted backend and remote runner.

## Subagent Review Synthesis

Overall architecture review:

- Mobile should be the canonical phase-one runtime.
- Backend should enhance sync, backup, scheduling, registry, runner coordination, and ecosystem features.
- Runner should execute authorized tasks and return output events/traces, not write private tables.
- Clean-room behavior specs should be written before implementation.

Storage review:

- SQLite/Drift should hold structured truth.
- Filesystem should hold large objects, backups, exports, plugin bundles, and rebuildable projections.
- `memory_items` should be the long-term context source of truth.
- Markdown, Obsidian output, vector indexes, and generated documents are projections.
- AI should write Memory candidates through the Memory service. Durable, evidenced, low-risk, non-conflicting Memory is auto-accepted by default; sensitive, conflicting, low-confidence, or policy-unclear Memory enters review.

Agent Runtime review:

- Events are append-only and at-least-once.
- Handlers must be idempotent.
- Runs and tasks form DAGs with retries, leases, and dead-letter states.
- External side effects require effect ids.
- PermissionBroker should gate all data reads, model calls, tools, and external writes.
- Trace/spans are a first-class trust surface.

UI review:

- Four tabs should be Home/Record, Conversations, Todos, Packs.
- Raw capture must appear immediately.
- AI card, Memory, insight, transcript, and OCR processing should be non-blocking.
- Todo, companion, custom agents, export, and marketplace are phase-one functionality, but can be implemented as official packs or advanced modes.

Backend/runner review:

- No official backend should be required.
- Static signed pack index is enough for phase-one marketplace basics.
- Backend can later add registry search, revocation, ratings, paid distribution, E2EE sync, webhooks, push, scheduling, and hosted runners.
- Remote execution must be opt-in and privacy-tier gated.

Module review:

- Add `packages/dart/memory` and `packages/dart/model_providers`.
- Add feature modules when they create useful boundaries.
- Add schema generation, pack validation, and doc lint tooling.
- Keep progressive context loading mandatory.

## Key Adjustments Made

- Todo and companion are not deferred; they are phase-one capabilities delivered through official packs and product tabs.
- The default runtime loop remains narrow: capture to cards to Memory to insights.
- Vector search is treated as a rebuildable projection, not the Memory truth.
- Markdown/Obsidian export is treated as a projection, not PKM core.
- Initial Kimi review failed due local authentication, then succeeded after login/config was fixed; follow-up actions are recorded in `2026-06-23-kimi-review-followup.md`.
- Current MemeX design critique is documented separately in `2026-06-23-memex-design-critique.md`.

## Recommended RFCs

- Memory model and lifecycle.
- Agent Pack manifest and permission model.
- BYOK model provider abstraction.
- Local data, backup, restore, export, and search.
- E2EE sync and runner trust.
- Plugin sandbox and marketplace trust.
- Four-tab UI and interaction spec.

## Sources

- MemeX repository: https://github.com/memex-lab/memex
- Omi repository: https://github.com/BasedHardware/omi
- Omi open-source app docs: https://docs.omi.me/doc/developer/apps/OpenSource
- LangGraph overview: https://docs.langchain.com/oss/python/langgraph/overview
- OpenAI Agents SDK: https://developers.openai.com/api/docs/guides/agents
- CrewAI documentation: https://docs.crewai.com/
- SQLite FTS5: https://sqlite.org/fts5.html
- SQLite Backup API: https://sqlite.org/backup.html
- Drift package: https://pub.dev/packages/drift
