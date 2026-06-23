---
id: ADR-0005
title: Use Memory-first instead of PKM as the core product model
status: accepted
date: 2026-06-23
owners: [core, product]
tags: [memory, pkm, local-first, product-model]
supersedes: []
superseded_by:
sources:
  - ../architecture/phase-one-technical-plan.md
  - ../research/2026-06-23-phase-one-technical-research.md
---

# Use Memory-First Instead of PKM as the Core Product Model

## Context

WideNote should provide the full MemeX-like capture, card, insight, conversation, companion, backup, export, and Agent Pack experience. However, the project should not make PKM/PARA, Markdown vaults, backlinks, folders, wiki pages, or a note graph the source of truth.

The desired product center is native Memory: visible, editable, deletable, source-linked, and available for retrieval and agent context.

## Decision

Use `memory_items` and related Memory contracts as the long-term personal context source of truth.

PKM-like outputs may exist only as projections or exports:

- Markdown
- Obsidian-style folders
- HTML documents
- Character cards
- External knowledge-base exports
- Vector indexes

These projections must be rebuildable from WideNote-owned records, events, and Memory.

## Rationale

Memory-first keeps the product closer to how agents actually need context: structured, scoped, ranked, source-linked, and lifecycle-aware. It also avoids forcing users into a note-taking metaphor when the primary experience is record capture and AI-assisted recall.

## Consequences

- AI writes proposed Memory changes through the Memory service. Durable, low-risk, non-conflicting Memory is auto-accepted by default.
- Low-confidence, conflicting, highly sensitive, or policy-unclear Memory is routed to review.
- Every Memory needs provenance, lifecycle, sensitivity, confidence, and revision support.
- Exports and indexes are not authoritative and can be rebuilt.
- Future PKM integrations must depend on public export/projection APIs, not private Memory tables.
- A detailed Memory RFC is required before implementation.
