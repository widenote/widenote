---
id: ADR-0004
title: Use progressive context structure for AI collaboration
status: accepted
date: 2026-06-23
owners: [core]
tags: [docs, ai-collaboration, context, project-structure]
supersedes: []
superseded_by:
sources:
  - ../architecture/context-structure.md
  - ../agent-context/project-map.md
---

# Use Progressive Context Structure for AI Collaboration

## Context

AI coding capability is not the main bottleneck for WideNote. The larger risk is context entropy: as the repository grows, agents can load too much context, miss the right local context, or act on stale structure.

WideNote also has an unusually context-heavy architecture: local runtime, event schemas, memory, Agent Packs, permissions, sync, backend services, and runners all need clear boundaries.

## Decision

Use progressive context structure as a repository rule.

The repository should expose context in layers:

- Root context: project-level intent and maps.
- Area context: top-level directory READMEs.
- Module context: module READMEs with ownership, dependencies, public surface, and generated artifacts.
- File context: focused source files, with comments only where boundaries are not obvious.

`docs/agent-context/project-map.md` is the canonical map for locating the right context entrypoints.

## Rationale

Progressive disclosure lets humans and agents inspect the project at the correct resolution. It keeps context loading targeted, reduces duplicated explanations, and makes module boundaries visible before code is read.

## Consequences

Adding or reshaping durable modules requires documentation updates. Generated files must document their source of truth and generation flow. The project map must be maintained as part of structural changes.
