---
id: ADR-0006
title: Use clean-room parity specs for MemeX-like behavior
status: accepted
date: 2026-06-23
owners: [core, product]
tags: [clean-room, product-parity, memex, omi, agents]
supersedes: []
superseded_by:
sources:
  - ../architecture/phase-one-technical-plan.md
  - ../research/2026-06-23-phase-one-technical-research.md
---

# Use Clean-Room Parity Specs for MemeX-Like Behavior

## Context

WideNote phase one should fully cover MemeX-like behavior except PKM/PARA as a core model. Omi is also a useful interaction and ecosystem reference. At the same time, WideNote must have its own implementation, schemas, prompts, runtime semantics, UI, and acceptance tests.

## Decision

Use clean-room parity specs as the bridge between reference products and implementation.

Allowed:

- Public product capability lists.
- Public user flows and interaction patterns.
- Public documentation and high-level architectural principles.
- WideNote-authored behavior specs derived from those references.

Forbidden:

- Copying reference code, database schemas, migrations, prompts, private APIs, UI assets, proprietary algorithms, or test data.
- Renaming a reference schema and placing it into WideNote.
- Making Agent Packs depend on reference-project private internals.

## Rationale

This lets WideNote pursue product parity without inheriting technical debt, licensing risk, privacy assumptions, or runtime constraints from reference projects.

## Consequences

- Reference findings should be summarized in `docs/research/`.
- Durable behavior belongs in WideNote RFCs, ADRs, schemas, and module READMEs.
- Implementers should work from WideNote specs, not from reference source code.
- Acceptance tests should validate WideNote behavior and user outcomes, not copied fixtures.

