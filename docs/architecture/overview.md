# Architecture Overview

WideNote uses a local-first architecture:

```text
Flutter client
  owns capture, local data, local memory, local runtime, permissions, and immediate UX

Optional backend
  enhances sync, backup, scheduling, registry, push, hosted runner, and ecosystem features

Optional runners
  execute long, expensive, scheduled, or externally integrated Agent Pack tasks
```

The backend is not the canonical brain. The client must be useful with no account, no official backend, and user-provided model keys.

## Core Runtime Shape

```text
capture event
  -> local event store
  -> subscriptions from enabled Agent Packs
  -> task queue
  -> local or remote executor
  -> output events
  -> memory, cards, insights, exports, or UI blocks
```

Core records and generated outputs should be represented as events and durable objects. Derived indexes such as full-text search or vector indexes can be rebuilt.

## First-Class Concepts

- Capture: raw user input and imported material.
- Event: append-only fact about something that happened.
- Memory: user-visible, editable, deletable durable context.
- Agent Pack: installable bundle of subscriptions, prompts, tools, permissions, and UI/output behavior.
- Tool: capability exposed to agents through permissioned APIs.
- Runner: execution host for local, self-hosted, or cloud tasks.
- Trace: audit trail for agent and plugin behavior.
