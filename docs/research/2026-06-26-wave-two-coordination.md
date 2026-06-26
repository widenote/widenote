# Wave Two Coordination

Status: complete; see
`docs/research/2026-06-26-wave-two-results.md` for validation results.
Date: 2026-06-26
Scope: second implementation wave after wave-one contract/runtime/local-db
foundation

## Goal

Connect the first durable foundations into usable runtime building blocks
without broad mobile UI changes.

## Workers

| Worker | Agent | Scope | Write ownership |
| --- | --- | --- | --- |
| Worker D | Russell | Local DB runtime and permission adapters | `packages/dart/local_db/lib/src/runtime_adapters.dart`, `packages/dart/local_db/test/runtime_adapters_test.dart` |
| Worker E | Lovelace | Agent Pack manifest JSON to runtime registry bridge | `packages/dart/agent_runtime/**` |
| Worker F | Volta | Context Packet builder and cache foundation | `packages/dart/local_db/lib/src/context_packet_builder.dart`, `packages/dart/local_db/test/context_packet_builder_test.dart`, `packages/dart/local_db/lib/widenote_local_db.dart` |

## Reviewers

| Reviewer | Agent | Scope |
| --- | --- | --- |
| Review D | Pasteur | Runtime/local DB adapter acceptance and edge cases |
| Review E | Hegel | Manifest bridge acceptance and edge cases |
| Review F | Poincare | Context Packet builder/cache acceptance and edge cases |

## Coordination Boundaries

- Worker D and Worker F both touch `packages/dart/local_db`, but their source
  files are intentionally separated.
- Worker D must not edit the public export file because `runtime_adapters.dart`
  is already exported.
- Worker F owns the public export change for `context_packet_builder.dart`.
- Worker E must not modify official manifests or mobile capture orchestration in
  this wave.
- The coordinator owns documentation index updates, cross-module validation,
  conflict resolution, and next-wave mobile integration planning.

## Wave Exit Criteria

- Local DB can provide durable `RuntimeStore` and `PermissionStore`
  implementations to Agent Runtime.
- Agent Runtime can decode official manifest JSON into manifest snapshots and
  validate them against native pack registrations.
- Local DB can build and cache text-first Context Packets with source-linked
  provenance and no secret leakage.
- Each worker runs focused tests, package analysis, and sanitized Kimi review.
- Reviewers provide acceptance, edge-case, user-test, and unit-test checklists.
- Coordinator validates the combined repo after worker integration.

## Known Non-Goals

- No broad mobile UI redesign in this wave.
- No plaintext full-secret backup UI.
- No real script runner sandbox.
- No capture-orchestrator rewrite until manifest bridge and durable adapters are
  validated.

## Review Notes Forwarded To Workers

### Worker D: Local DB Runtime / Permission Adapters

Review D requires adapter tests to prove field-level parity with
`RuntimeStore` and `PermissionStore`, not just DAO coverage. Hard gates include:

- preserve `RuntimeRun.leaseExpiresAt` across DB close/reopen, even though the
  current local DB run record has no dedicated same-name field
- preserve task identity, dependency, missing dependency, attempts, errors, and
  timestamps
- keep pack installation metadata when updating runtime pack status
- clear stale permission `reason` / `revokedAt` across grant, deny, grant, and
  revoke transitions
- cover local DB backed `RuntimeKernel` restart, stale lease, and permission
  revocation flows

### Worker E: Agent Pack Manifest Bridge

Review E requires the Dart bridge to prove official manifest JSON can drive
runtime manifest snapshots and alignment checks. Hard gates include:

- parse real `packs/official/default/manifest.json` and
  `packs/official/todo/manifest.json`, not copied inline fixtures only
- reject missing or malformed required fields, unsupported runtime kinds,
  invalid retry bounds, empty output events, duplicate IDs, dangling
  dependencies, and invalid model profile references
- fail closed with no partial registration on malformed manifest batches
- preserve official pack guardrails: default pack cannot request/output todo;
  todo pack is restricted to todo permission/output
- keep script/remote/declarative execution out of scope

### Worker F: Context Packet Builder / Cache

Review F requires Context Packets to be source-linked, permission-aware derived
read models, not canonical truth. Hard gates include:

- public builder API exported from `widenote_local_db.dart`
- generated packet maps conform to the Context Packet schema shape
- Memory-first ordering with citations/source refs on every content section
- cache keys include surface, subject/request, permission scope, disclosure
  level, generator/prompt/pack version, local date, privacy profile, and source
  versions or hashes
- permission/source/Memory revision/sensitivity/generator changes prevent stale
  cache reuse
- no API keys, private DB dumps, raw attachment paths, or high-risk raw content
  in default packets
