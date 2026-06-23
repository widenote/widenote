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
