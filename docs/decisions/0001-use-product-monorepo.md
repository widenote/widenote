---
id: ADR-0001
title: Use a product monorepo
status: accepted
date: 2026-06-23
owners: [core]
tags: [repo, monorepo, architecture]
supersedes: []
superseded_by:
sources:
  - ../architecture/project-structure.md
  - ../research/2026-06-23-architecture-landing-notes.md
---

# Use a Product Monorepo

## Context

WideNote is not a conventional frontend/backend application. The mobile client owns core data and runtime behavior, while backend services enhance sync, backup, scheduling, runner execution, and ecosystem features.

The most volatile early contracts will cross runtime boundaries: events, memory, permissions, Agent Pack manifests, tasks, traces, and sync objects.

## Decision

Keep the mobile client, optional backend, runner, schemas, docs, and default Agent Pack in one main monorepo.

Use separate workspaces and package boundaries:

- `apps/` for runnable apps and services
- `packages/` for shared contracts and reusable code
- `packs/` for Agent Packs
- `docs/` for product and architecture memory

## Considered Options

- Product monorepo
- Mobile-core repo plus separate backend repo
- Full multi-repo organization
- Hybrid monorepo plus later ecosystem repos

## Rationale

The product monorepo supports atomic changes while the schemas and runtime semantics are still forming. It also keeps docs, default packs, and implementation aligned.

## Consequences

The monorepo must have explicit boundaries. `packages/schemas` is a first-class contract center. Backend and runner services must be independently buildable and deployable even when they live in the same repository.
