---
id: ADR-0007
title: Defer cloud sync from the core phase-one implementation
status: accepted
date: 2026-06-23
owners: [core, privacy]
tags: [sync, backup, local-first, phase-one]
supersedes: []
superseded_by:
sources:
  - ../architecture/phase-one-technical-plan.md
---

# Defer Cloud Sync From the Core Phase-One Implementation

## Context

WideNote must be useful without an account or official backend. Phase one already needs to establish capture, local persistence, native Memory, Agent Runtime, cards, insights, todos, conversations, packs, backup/export, and trace review.

Cloud sync adds hard product and security questions: E2EE key creation, device pairing, recovery, tombstones, attachment encryption, runner trust, conflict resolution, and remote execution boundaries.

## Decision

Do not make cloud sync part of the core phase-one implementation path.

Phase one should implement:

- Local-first app behavior.
- Local backup and restore.
- JSON/JSONL and human-readable exports.
- Sync object schema placeholders where needed.
- Clear boundaries so E2EE sync can be added later without changing local truth.

E2EE sync remains an RFC-level follow-up and optional backend enhancement.

## Rationale

This keeps the first runnable Android client focused on the local value loop and avoids blocking core product validation on identity, cryptography, device pairing, and backend operations.

## Consequences

- `apps/mobile` must work without login.
- `apps/api` and `apps/runner-ts` remain optional enhancements.
- Local data schemas should still include tombstone/revision concepts so future sync is possible.
- The project needs a later E2EE sync RFC before implementation.

