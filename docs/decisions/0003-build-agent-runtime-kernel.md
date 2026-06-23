---
id: ADR-0003
title: Build a lightweight WideNote Agent Runtime Kernel
status: accepted
date: 2026-06-23
owners: [core]
tags: [agent-runtime, events, plugins, memory]
supersedes: []
superseded_by:
sources:
  - ../architecture/runtime.md
  - ../research/2026-06-23-architecture-landing-notes.md
---

# Build a Lightweight WideNote Agent Runtime Kernel

## Context

WideNote needs event-driven Agent Pack execution across local, self-hosted, and cloud environments. Existing agent and workflow frameworks are useful, but they do not define WideNote's product semantics around local-first memory, plugin permissions, user-visible context, and raw record preservation.

## Decision

Build a lightweight runtime kernel inside WideNote.

The kernel owns:

- Event protocol
- Task protocol
- Agent Pack manifest
- Permission model
- Memory model
- Tool registry
- Trace and audit log
- Local runtime

External frameworks should be adapters or integration targets.

## Considered Options

- Build a heavy standalone agent engine
- Embed a lightweight product runtime
- Depend directly on a third-party workflow or agent platform

## Rationale

The lightweight kernel keeps WideNote's core semantics under product control while avoiding early over-engineering. It leaves room to integrate LangGraph, OpenAI Agents SDK, Mastra, Hatchet, Inngest, Trigger.dev, Temporal, Dify, n8n, or Flowise later.

## Consequences

The MVP should start with local event storage, a task queue, a pack registry, permissions, tool registration, memory storage, trace logging, and local Dart execution. Remote runners can be added after the local semantics are proven.
