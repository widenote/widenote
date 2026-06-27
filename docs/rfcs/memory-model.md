# RFC: Memory Model

Status: Accepted phase-one contract; follow-ups open
Date: 2026-06-23

## Context

WideNote uses native Memory instead of a PKM core. The product default is silent capture and automatic acceptance for low-risk durable memories, with review reserved for conflicts, sensitive content, weak evidence, and low confidence.

## Goals

- Make Memory the durable user-editable knowledge layer.
- Preserve source links for every Memory item.
- Auto-accept safe memories without requiring user confirmation.
- Keep review queues small and meaningful.
- Support deletion, tombstones, revision history, and future sync.

## Core Entities

### Memory Candidate

An agent-produced proposal before policy evaluation.

Required fields:

- `id`
- `key`
- `body`
- `source_refs[]`
- `memory_type`
- `confidence`
- `sensitivity`
- `durability`
- `status`
- `policy_reasons[]`
- `conflicting_memory_ids[]`

`memory_type`, `confidence`, `sensitivity`, and `durability` are proposal
metadata supplied by an LLM-backed agent, explicit user action, or a permissioned
plugin/Agent Pack. WideNote core must not derive them from local keyword,
regular-expression, substring, or stop-word rules over user natural-language
content.

### Memory Item

The accepted durable record.

Required fields:

- `id`
- `key`
- `body`
- `source_refs[]`
- `memory_type`
- `confidence`
- `sensitivity`
- `status`
- `revision`
- `created_at`
- `updated_at`
- `tombstone`

## Memory Types

Types below describe accepted proposal metadata and review policy. They are not
instructions for core to classify user text locally.

| Type | Examples | Default Handling |
| --- | --- | --- |
| `preference` | Preferred tools, communication style | Auto-accept when evidenced and low sensitivity |
| `project` | Current project facts, repo names, module decisions | Auto-accept when evidenced and non-conflicting |
| `task_context` | Commit intent, near-term work context | Auto-accept when durable enough |
| `person` | Names and relationship context | Review when sensitive or ambiguous |
| `health` | Health, medical, therapy, medication | Review |
| `finance` | Income, expenses, account details | Review |
| `location` | Home, travel, frequent places | Review unless explicitly low sensitivity |
| `credential` | Secrets, tokens, passwords | Reject or redact; never auto-accept |
| `insight` | Inferred pattern or reflection | Review unless strongly evidenced |

## Sensitivity

Sensitivity below describes accepted proposal metadata and review policy. It is
not a core keyword scanner or masking rule.

| Level | Meaning | Auto-Accept |
| --- | --- | --- |
| `low` | Normal project, preference, or workflow context | Allowed |
| `medium` | Personal context that could surprise the user | Review |
| `high` | Health, finance, location, relationship, legal, credential-adjacent | Review or reject |

## Auto-Accept Policy

Auto-accept only when all conditions are true:

- Candidate has at least one source ref with evidence text or URI.
- Candidate has `confidence != low`.
- Candidate has `sensitivity == low`.
- Candidate has `durability == durable`.
- Candidate does not conflict with an active Memory item.
- Candidate type is not `credential`, `health`, `finance`, or `location`.

Everything else goes to review. Review is a background correction surface, not a capture-time confirmation dialog.

## Review Operations V1

The phase-one review surface supports a narrow set of explicit user actions:

- `accept`: create an active Memory item from the reviewed candidate while preserving source refs.
- `edit then accept`: replace the candidate body with the user's edited body, then create an active Memory item with the same provenance.
- `reject`: mark the candidate rejected without creating Memory.
- `merge`: update a selected active Memory item, increment its revision, merge provenance refs, and mark the candidate merged.

These operations are Memory service semantics. SQLite adapters may provide atomic transition helpers, but UI code should call the Memory service/repository boundary rather than mutating private tables directly.

## User Visibility

The product should remain mostly silent during capture. Visibility happens through:

- Recent Memory section on the home tab.
- Daily/weekly review cards for accepted memories.
- Searchable Memory detail with source links.
- Reversible delete/tombstone behavior.

## Conflict Detection

Phase one uses exact key conflict detection:

- Same `key`
- Existing active item
- Different normalized `body`

Future versions may add semantic similarity, time-aware facts, and per-type merge strategies.

## Open Questions

- Whether `insight` memories should default to review until trust is earned.
- Whether location-derived Memory should require a dedicated permission even for low-sensitivity places.
- Whether user-level policy overrides belong in Memory or Settings.
