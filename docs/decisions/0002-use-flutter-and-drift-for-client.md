---
id: ADR-0002
title: Use Flutter and Drift for the client foundation
status: accepted
date: 2026-06-23
owners: [core]
tags: [flutter, dart, sqlite, local-first]
supersedes: []
superseded_by:
sources:
  - ../architecture/technology-stack.md
  - ../research/2026-06-23-architecture-landing-notes.md
---

# Use Flutter and Drift for the Client Foundation

## Context

WideNote is mobile-first and local-first. The client must support fast capture, offline use, local memory, local search, local agent execution, BYOK model access, and optional sync.

## Decision

Use Flutter + Dart as the primary client stack.

Use SQLite + Drift as the core local data layer.

## Considered Options

- Flutter + Drift
- React Native
- Kotlin Multiplatform
- Native Swift and Kotlin
- Tauri or web-first clients

## Rationale

Flutter provides a practical cross-platform mobile UI and runtime foundation. Drift and SQLite provide durable, inspectable, migratable, queryable local storage suitable for records, events, memory, traces, permissions, and sync state.

## Consequences

Platform-specific capabilities such as share extensions, background tasks, notifications, and high-risk inputs may require native Swift/Kotlin modules. iOS and Android background execution must be treated as opportunistic, not reliable scheduling.

## Amendment: Current W7 SQLite Implementation

Date: 2026-06-26

ADR-0002 remains accepted: Drift is still the long-term local data-layer target
on top of SQLite.

The current W7 phase-one implementation uses hand-written SQLite through the
pure Dart `sqlite3` package in `packages/dart/local_db`. This was chosen so the
team could stabilize object truth, migrations, backup/import, runtime state,
permission state, provider metadata, and Context Packet caches before adding a
generated Drift layer.

Until Drift is introduced, docs should describe the current implementation as
hand-written `sqlite3` plus SQLite. Do not imply that phase-one W7 already has
Drift-generated tables, DAOs, or generated artifacts. When Drift lands, update
this ADR or create a follow-up ADR, and document the generator source of truth
and command in the owning module README.
