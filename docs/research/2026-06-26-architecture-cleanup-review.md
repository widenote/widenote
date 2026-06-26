# Architecture Cleanup Review

Status: implemented cleanup review
Date: 2026-06-26
Scope: phase-one mobile runtime, backup, Memory, Timeline, and real route QA

## Review Inputs

- Architecture review subagent checked for stale skeletons, demo entries, and
  object/runtime conflicts.
- User-journey review subagent checked route-level recovery and backup edge
  cases.
- Existing W7 RFCs and ADRs remain the source of truth; this note records the
  cleanup outcomes, not a new product direction.

## Findings Resolved

- Accepted Memory IDs could be reused after app restart because the default
  Memory id factory restarted from `memory_1`.
  - Resolution: `MemoryService` now skips already-used ids, and mobile runtime
    passes the runtime id generator for Memory ids.
  - Regression: `apps/mobile/test/capture_orchestrator_test.dart`.
- Permission Gate decisions were persisted in UI state but not enforced by the
  capture runtime.
  - Resolution: mobile capture runtime now uses `LocalDbPermissionStore` and
    `LocalDbRuntimeStore`; built-in permissions are seeded only when no user
    grant / deny / revoke exists.
  - Regression: `apps/mobile/integration_test/phase_one_journey_test.dart`
    revokes `pack.default:model.complete`, submits another capture, and verifies
    raw input is preserved while restricted output is blocked.
- Timeline could render one generated Todo twice, once from the event and once
  from the Todo object.
  - Resolution: Timeline renders Todo object rows only; the
    `wn.todo.suggested` event remains provenance.
  - Regression: `apps/mobile/test/timeline_widget_test.dart`.
- Memory edit / delete / restore changed object state without lifecycle evidence.
  - Resolution: Memory controller now appends lifecycle event and trace evidence
    for user edits, tombstones, and restores.
  - Regression: `apps/mobile/test/memory_page_test.dart`.
- Secret-bearing `encrypted_full` backup import conflicted with the W7 safe-only
  backup boundary.
  - Resolution: current import rejects any `includes_secrets` or
    `encrypted_full` backup. Older backups that decode as secret-bearing are
    inspectable but not importable in this build.
  - Regression: `packages/dart/local_db/test/backup_export_test.dart`.
- Safe backup restore was only tested against a mounted Backup page, not through
  the real app shell.
  - Resolution: integration test now exports from a source app state, imports
    into an empty app through the real Plugins -> Backup route, verifies restored
    Home / Todo / Memory / Chat state, and then submits a fresh capture.
  - Regression: `apps/mobile/integration_test/phase_one_journey_test.dart` on
    Android and iOS simulators.

## Current Acceptance Standard

- No user-facing phase-one entry should be an empty implementation or demo-only
  surface.
- Raw capture must be preserved even when Pack work is denied or fails.
- Permission revoke must affect future runtime work, not only the Settings UI.
- Safe backup is the only implemented restore path; provider keys require
  re-entry after safe restore.
- Timeline and detail routes should resolve by durable source ids.
- Android and iOS simulator validation must run the real route-level journeys.

## Remaining Deferred Work

- Real encrypted full backup and credential restore.
- Broader manual media permission matrix beyond automated text / backup routes.
- Future Drift migration once the schema stabilizes enough to justify generated
  table ownership.
