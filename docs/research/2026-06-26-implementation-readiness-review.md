# Implementation Readiness Review

Status: ready for implementation
Date: 2026-06-26
Scope: final review before drafting the umbrella technical-plan RFC

## Inputs

- `docs/decisions/0009-use-object-truth-and-context-packets.md`
- `docs/research/2026-06-26-product-technical-direction-summary.md`
- `docs/research/2026-06-26-kimi-technical-direction-review.md`
- `docs/agent-context/open-questions.md`

Kimi CLI was asked to classify remaining questions into:

- product-owner decisions
- engineering-owner RFC decisions
- implementation details

## Go / No-Go

The direction is ready for the umbrella technical-plan RFC and first
implementation wave.

No additional phase-one product/runtime direction gap was found.

## Product-Owner Decisions Confirmed

### 1. Backup Encryption UX

Question:

Should secret-bearing full backups be mandatory encrypted, or should they allow
an explicit warning plus user choice?

Options:

| Option | Meaning | Tradeoff |
| --- | --- | --- |
| A | Full backups with secrets must be encrypted | Strongest privacy promise; more friction and recovery-key UX |
| B | Full backups show explicit warning and strongly recommend encryption, but user may export unencrypted | Easier local/manual workflows; higher accidental leak risk |
| C | Two backup modes: safe backup without secrets, encrypted full backup with secrets | Clearest security model; adds one more product concept |

Confirmed: C.

Reason:

Backup is expected to restore the app to a fully usable state, including
provider/model config and necessary credentials. That makes a full backup
secret-bearing user data.

### 2. Soft Delete Window Configurability

Question:

Should the 30-day recoverable delete window be fixed or user-configurable?

Options:

| Option | Meaning | Tradeoff |
| --- | --- | --- |
| A | Fixed 30-day recoverable window | Simple and predictable |
| B | Default 30 days, with advanced setting to change/disable | Better privacy control; more settings complexity |
| C | No timed auto-purge; user manually purges | Maximum recovery; weak privacy cleanup |

Confirmed: A for phase one. Design the model so B can be added later.

Reason:

Phase one should keep deletion semantics predictable. A configurable window can
be added after the backup/export/deletion UX is stable.

## Engineering-Owned Decisions For the RFC

The engineering owner can decide these in the umbrella RFC without more
product-owner review unless the design changes the accepted product shape.

| Area | Default to write into RFC |
| --- | --- |
| Daily Recap date boundary | Group by device local date at capture time; preserve time-zone metadata for future travel-aware grouping |
| Owner Export provider metadata | Include provider/model metadata without secrets |
| Context packet cache export boundary | Cache may be included in encrypted/restorable Backup; excluded from Owner Export; restore tolerates missing/stale cache |
| Context packet schema | Define source refs, disclosure levels, hashes/source versions, generator version, permission scope, and invalidation rules |
| Permission broker tests | Cover declaration, install/review, runtime check, denial, revocation, and high-risk capability classification |
| Umbrella RFC scope | Object boundaries, lifecycle diagrams, storage/schema proposals, Agent Pack boundaries, UI read models, backup/export, validation gates |

## Implementation Details

These should be decided during implementation and test design:

- exact table names and migration numbers
- exact context packet cache eviction policy
- exact wording of backup warnings
- exact widget layout for backup mode choice
- exact test fixture names
- exact trace field names beyond public schema requirements

## Result

The next step can start without more product-direction research:

```text
Draft umbrella technical-plan RFC
  -> review with product owner
  -> split stable decisions into ADRs
  -> begin implementation slices
```

## Preflight Kimi Follow-Up

After the umbrella RFC draft was created, Kimi ran a preflight review. It used a
slightly stale RFC snapshot that still showed the two product-owner decisions as
open, but the useful non-stale finding was conflict isolation:

- Do not start broad mobile UI rewrites before runtime/pack contracts stabilize.
- Treat `capture_orchestrator.dart`, `pack_catalog.dart`, `app_router.dart`, and
  model-routing glue as coordination hotspots.
- First implementation wave should focus on contracts, durable runtime state,
  pack registry, and manifest/runtime alignment.

This is accepted as a coordination rule.
