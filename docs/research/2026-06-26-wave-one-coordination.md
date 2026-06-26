# Wave One Coordination

Status: complete; see
`docs/research/2026-06-26-wave-one-results.md` for validation results.
Date: 2026-06-26
Scope: first implementation wave after phase-one umbrella plan acceptance

## Coordination Model

The main conversation acts as coordinator:

- define module boundaries and acceptance gates
- assign non-overlapping implementation scopes to worker subagents
- assign read-only edge-case reviewers to each module
- require each worker to run a sanitized Kimi module review when available
- integrate worker results, resolve conflicts, run repository-level validation,
  and coordinate emulator QA

Workers must not revert or clean up unrelated changes. Hotspot files are assigned
only when a wave explicitly gives one worker ownership.

## First Wave Goal

Stabilize the contracts and runtime foundation before broad mobile UI work.

The first wave intentionally avoids large edits to:

- `apps/mobile/lib/features/capture/application/capture_orchestrator.dart`
- `apps/mobile/lib/features/capture/application/capture_controller.dart`
- `apps/mobile/lib/app/app_router.dart`
- `apps/mobile/lib/features/plugins/application/pack_catalog.dart`
- `apps/mobile/lib/app/model_client.dart`

## Implementation Workers

| Worker | Scope | Write ownership |
| --- | --- | --- |
| Worker A | Schemas/contracts | `packages/schemas/**`, `tools/pack_validator/**`, related READMEs/tests |
| Worker B | Agent runtime ports and pack registry | `packages/dart/agent_runtime/**`, related README/tests |
| Worker C | Local DB durable runtime state | `packages/dart/local_db/**`, related README/tests |

## Review Subagents

| Reviewer | Scope | Output |
| --- | --- | --- |
| Review A | Schemas/contracts edge cases | fixture, compatibility, drift, validation, Kimi-input checklist |
| Review B | Runtime/pack registry edge cases | idempotency, permission, output event, trace, Kimi-input checklist |
| Review C | Local DB durable state edge cases | migrations, backup/import, permission state, context cache, secret-boundary checklist |

## Worker Requirements

Each implementation worker must report:

- files changed
- tests run and results
- Kimi review command outcome or skipped reason
- edge cases covered
- remaining coordinator risks

Kimi review inputs must not include:

- API keys, tokens, credentials, provider secrets
- real user records, local databases, backup files, private media
- raw private traces or full context packets

## Wave Exit Criteria

Wave one is complete when:

- schema/contract drift is reduced or documented
- runtime ports and pack registry can support durable adapters
- local DB has durable runtime/pack/permission/context-cache foundations
- module tests pass
- Kimi reviews either pass or have documented non-blocking findings
- coordinator can start the next wave without assigning the same hotspot files to
  multiple workers

## Review Notes Forwarded To Workers

### Worker A: Schemas / Contracts

Review A required synthetic fixtures for Event, Memory, Agent Pack manifest,
Permission, Trace, Task/Run, Context Packet, Backup manifest, Owner Export, and
provider/model routing. It highlighted drift in Memory statuses, source refs,
tombstone fields, Trace `run_id`, and Event idempotency/retention/redaction
fields.

Worker A should prefer fixture runner and compatibility documentation over a
large breaking migration.

### Worker B: Runtime Ports / Pack Registry

Review B required durable runtime semantics for task/run states, stale leases,
dependency blocking, denied/canceled terminal states, `appendAll` rollback,
manifest-to-native registry consistency, output event whitelist checks,
permission broker grant/deny/revoke, idempotency keys, and safe traces.

Worker B must not touch mobile hotspot files in this wave.

### Worker C: Local DB Durable State

Review C required migration coverage, DAO transactions, runtime task identity,
permission state, safe backup vs encrypted full backup, restore behavior,
context cache invalidation, tombstone/purge semantics, and secret-boundary
tests.

Worker C should not sign off on table read/write alone; migration, backup, and
restore boundaries are part of acceptance.
