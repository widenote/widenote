# Kimi Technical Direction Review

Status: reviewed and resolved into follow-up decisions
Date: 2026-06-26
Scope: external review of the WideNote mobile product/runtime direction before
the detailed technical-plan RFC

## Review Input

Kimi CLI was invoked with a read-only prompt containing:

- `docs/research/2026-06-26-storage-export-selection-options.md`
- `docs/research/2026-06-26-technical-plan-research-synthesis.md`
- the confirmed product-owner decisions as of 2026-06-26

No repository edits, credentials, backup files, local databases, or user records
were provided to the review prompt.

## Kimi Go / No-Go

Kimi's conclusion was:

```text
Go, with conditions.
```

It agreed that the direction is sufficient to enter an umbrella technical-plan
RFC, but said the RFC must make several boundary decisions explicit before
splitting into ADRs or implementation slices.

## Findings

### P0: Backup vs Owner Export Secrets Boundary

Kimi found that "Backup restores a fully usable app" and "Owner Export does not
include secrets" are both reasonable, but the provider config boundary needed to
be explicit.

Resolution:

- Backup is restorable app state. A full restorable backup includes provider
  configuration, model routing/defaults, installed pack state, app settings, and
  credentials/secrets needed to keep the app usable after restore.
- A backup that contains secrets is secret-bearing user data and must be treated
  as encrypted/explicit-user-action material.
- Owner Export is portable user data. It may include provider/model metadata
  needed to understand prior behavior, but must not include API keys, tokens, or
  other secrets by default.

### P0: Context Packet Cache Semantics

Kimi found that "cache generated context packets and invalidate on source
changes" was too vague.

Resolution:

- Context packets are generated read models, not source truth.
- Important context packets may be persisted in SQLite as rebuildable derived
  caches.
- Cache rows must carry source refs, source version or content hash inputs,
  policy/permission scope, and generator version so stale packets can be
  invalidated.
- Context packet caches are excluded from Owner Export. They may be included in
  encrypted/restorable Backup, but restore must tolerate missing or invalidated
  caches.

### P0: Tombstone and Purge Semantics

Kimi found that soft delete needed a concrete privacy/recovery meaning.

Resolution:

- Default deletion is recoverable soft delete with content retained for a short
  "recently deleted" window.
- Working default: 30 days.
- Permanent purge removes user content and keeps only minimal tombstone metadata
  needed for references, audit, and future sync conflict avoidance.
- Owner Export excludes soft-deleted and purged content by default. Full audit
  export can be added later.

### P1: Accepted Memory Provenance

Kimi found that accepted Memory becomes canonical only after a derived candidate
and policy decision.

Resolution:

- Accepted Memory is canonical for retrieval and personalization, but it remains
  source-linked derived knowledge.
- Each accepted Memory item must preserve provenance: source refs, candidate id
  or event id, policy decision, sensitivity/type, and user review action if any.

### P1: Daily Recap Date Boundary

Kimi found that "Daily" needed a date boundary.

Resolution:

- Phase one groups daily recap by the device local date at capture time.
- Captures should preserve enough timestamp/time-zone metadata to support future
  main-time-zone or travel-aware grouping.

### P1: Capability Broker

Kimi found that official packs only could weaken real permission testing.

Resolution:

- Official packs still go through the same manifest/capability broker path.
- Tests should cover permission declaration, runtime check, denial, revocation,
  and high-risk capability classification even before community packs exist.

### P1: SQLite Truth vs Append-Only Events

Kimi found possible ambiguity between SQLite object truth and append-only events.

Resolution:

- WideNote is not adopting full event sourcing in phase one.
- SQLite/Drift object tables are the canonical current object state.
- Original captures must preserve raw input and revisions/corrections.
- Append-only events are canonical for audit, routing, task idempotency, and
  future sync evidence, but they are not the sole source from which every object
  must be replayed.

## Result

The Kimi review did not change the major direction. It tightened boundaries that
the detailed technical-plan RFC must carry forward:

- Backup is secret-bearing and restorable; Owner Export is portable and safe by
  default.
- Context packets are rebuildable AI read models with explicit invalidation.
- Soft delete has a concrete recoverable window and a purge path.
- Accepted Memory and derived objects must remain source-linked.
- Official packs must still exercise the permission broker.
