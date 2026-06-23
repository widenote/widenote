---
id: ADR-0000
title: Use ADRs and RFCs for durable decisions
status: accepted
date: 2026-06-23
owners: [core]
tags: [docs, decisions, ai-collaboration]
supersedes: []
superseded_by:
sources:
  - ../research/2026-06-23-architecture-landing-notes.md
---

# Use ADRs and RFCs for Durable Decisions

## Context

WideNote will be developed through long-running human and AI collaboration. Raw conversation history contains useful evidence but is noisy, hard to search, and easy to misread as a final decision.

The project needs a durable way to preserve decisions, alternatives, consequences, and open questions.

## Decision

Use:

- `docs/decisions/` for ADRs
- `docs/rfcs/` for major open proposals
- `docs/research/` for summarized discussion and external research
- `docs/agent-context/` as the AI entrypoint into project context

## Consequences

Future agents and contributors should read the decision index before making architectural changes. Conversation summaries may support decisions, but ADRs are the authority.
