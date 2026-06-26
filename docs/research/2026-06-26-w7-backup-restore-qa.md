# W7 Backup / Owner Export / Restore QA

Status: W7-B worker verification
Date: 2026-06-26
Scope: phase-one backup/restore boundary, Owner Export clarity, provider and
Pack restore usability

## Acceptance Standard

- Safe restore JSON is the default mobile export.
- Safe restore JSON restores records, Memory, todos, model-provider metadata,
  default-provider state, pack installations, permission grants/revocations,
  runtime tasks/runs, traces, and context packet cache rows when present.
- Safe restore JSON never includes provider API key values. It preserves
  `has_api_key` so the app can tell the user which provider keys must be
  re-entered.
- Encrypted full backup is the only secret-bearing backup mode. Plaintext
  secret-bearing JSON export is blocked until a real encryption flow exists.
  Mobile does not expose a full-backup export button in this build, and current
  restore rejects `includes_secrets` / `encrypted_full` imports.
- Owner Export Markdown is readable and secret-free. It is not a restore source.
- Restore rejects unsupported versions, malformed JSON, missing required
  sections, duplicate ids, and existing-row conflicts before partial writes.
- Restore tolerates stale or missing Context Packet cache because it is
  rebuildable derived state.
- Restore must not revive tombstoned Memory content.

## Implemented Boundary

- `LocalBackupManifest` now writes `kind`, `schema_version`,
  `includes_secrets`, and `encryption` metadata while staying compatible with
  older local backups.
- Current-format `encrypted_full` manifests must declare encryption metadata;
  secret-bearing backups cannot be encoded as plaintext JSON through the local
  codec.
- Safe backup recursively redacts provider payload fields with secret-like names
  such as `api_key`, `access_token`, `refresh_token`, `password`, and
  `client_secret`, while preserving ordinary metadata. It also scans string
  payload values for common `api_key: ...` / token / password assignment shapes
  so serialized provider config snippets do not bypass the safe boundary.
- `LocalBackupImportReport` summarizes restored provider/pack/permission/runtime
  counts and whether provider keys need re-entry after safe restore.
- Secret-bearing full-backup fixtures are decoded for boundary validation, but
  import is rejected until encrypted full restore is implemented.
- `BackupPage` shows three explicit surfaces:
  - safe restore JSON
  - Owner Export Markdown
  - encrypted full backup unavailable until encryption is implemented
- Backup UI refreshes local capture, timeline, todo, Memory, and model-provider
  state after import.

## User Manual Checks

1. Open Plugins -> Backup.
2. Confirm the page explains that safe restore JSON restores app state except
   provider keys.
3. Confirm Owner Export Markdown is labeled as readable and not a restore
   source.
4. Confirm encrypted full backup is described as future secret-bearing restore
   behavior and has no action button in the mobile UI.
5. Configure a synthetic provider with an API key, create a record and todo,
   then export safe JSON.
6. Confirm the JSON manifest says `backup_mode: safe` and
   `includes_secrets: false`.
7. Confirm no provider key appears in JSON or Markdown.
8. Import the safe JSON into an empty local database.
9. Confirm records, todos, provider metadata, pack state, permission state, and
   runtime evidence are restored.
10. Confirm the UI says provider keys need re-entry before model calls.
11. Paste malformed JSON, confirm recoverable error, then paste valid JSON and
   confirm import succeeds.
12. Paste a secret-bearing `encrypted_full` JSON fixture, confirm import is
   rejected and no provider key is restored.

## Automated Verification

Passed:

```sh
cd packages/dart/local_db && dart analyze
cd packages/dart/local_db && dart test test/backup_export_test.dart
cd packages/dart/local_db && dart test
cd apps/mobile && flutter analyze lib/features/backup test/backup_page_test.dart
cd apps/mobile && flutter test test/backup_page_test.dart
cd apps/mobile && flutter test integration_test/phase_one_journey_test.dart -d emulator-5554 --flavor dev
cd apps/mobile && flutter test integration_test/phase_one_journey_test.dart -d AC67CA3B-F4D5-428C-ABBB-08F5AF83DF1D
```

Coverage:

- manifest counts and secret-boundary fields
- provider/model config safe metadata and encrypted-full codec branch
- recursive provider payload secret redaction
- serialized provider payload string redaction
- plaintext secret-bearing backup export blocked
- secret-bearing backup import blocked
- current encrypted-full manifests without encryption metadata rejected
- pack installation, permission grant, runtime task/run, context cache, trace
  round trip
- malformed, unsupported, missing sections, duplicate ids, manifest mismatches
- existing rows rejected before writes
- tombstone not revived
- missing Context Packet cache tolerated
- Backup UI safe/owner/full boundary text
- legal JSON import and visible restore result
- malformed JSON error recovery
- full app-shell safe restore on Android and iOS simulators, followed by
  restored Home / Todo / Memory / Chat state checks and a fresh capture

## Full Mobile Suite Notes

Earlier W7-B notes recorded stale full-suite failures outside the backup module.
The later architecture-cleanup pass removed those blockers and added full app
route coverage for safe backup import into an empty local database, followed by
continued Home / Todo / Memory / Chat / capture usage.

## Kimi Review

Input must stay redacted:

- file list
- diff summary
- acceptance criteria
- test commands and results
- no real backup JSON
- no SQLite files
- no provider keys or raw user data

Result: NO_BLOCKERS for W7-B scope.

Kimi findings:

- The implemented safe/full boundary, restore transaction semantics, Context
  Packet cache tolerance, and tombstone behavior satisfy the W7-B acceptance
  bar.
- Kimi suggested extra future hardening around explicit default-provider
  assertions, v1 compatibility, encrypted-full missing-encryption errors,
  metadata preservation, Owner Export copy actions, and malformed-error
  specificity. These are already mostly covered by local tests; the review did
  not mark them as blockers.
- Kimi flagged serialized string payloads such as `{"api_key":"..."}` as a
  possible secret-redaction gap. W7-B addressed this after review by scanning
  provider payload string values for common secret assignment shapes and adding
  unit/widget coverage.

## Remaining Risk

- Mobile encrypted full backup export and import are intentionally unavailable
  until encryption and secret storage UX are designed.
- The current Owner Export is Markdown projection plus safe JSON, not yet a
  multi-file archive with attachments/checksums.
- Cross-route app refresh after import is covered by
  `apps/mobile/integration_test/phase_one_journey_test.dart` on Android and iOS
  simulators.
