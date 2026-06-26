# Mobile Backup Feature

## Purpose

Provides the user-facing local backup and import surface for WideNote mobile.
It wraps the `widenote_local_db` backup codec so users can export a portable
safe restore JSON, inspect manifest counts, copy a readable Owner Export
Markdown projection, and import a pasted backup into the local database.

## Ownership Boundary

- Owns mobile backup UI state and presentation.
- Does not define the backup format; `packages/dart/local_db` is the source of
  truth for backup schema, validation, import, export, and migration rejection.
- Defaults to safe restore JSON. Provider credential presence is preserved, but
  credential values are omitted and the import report tells the user which
  provider keys must be re-entered.
- Treats provider payload fields with secret-like names as unsafe for safe
  backup and recursively redacts them while preserving ordinary metadata such as
  provider name, endpoint, model, capabilities, default state, and
  `secret_storage`. String payload values are also scanned for common
  `api_key: ...` or token/password assignment shapes.
- Shows Owner Export as a readable, secret-free projection rather than a restore
  source.
- Shows encrypted full backup as unavailable until the mobile shell has a real
  encryption flow for secret-bearing artifacts.

## Dependencies

- `app/local_database.dart`
- `widenote_local_db`
- Flutter / Riverpod

## Public Surface

- `BackupPage`
- `backupControllerProvider`

## User-Tested Boundaries

- Safe restore JSON restores records, Memory, todos, provider metadata, pack
  installation state, permission grants, runtime state, context cache rows when
  present, and traces.
- Safe restore JSON never exports provider API key values.
- Safe restore JSON never exports provider payload token/API-key/password
  values, including common serialized string assignment forms.
- Owner Export Markdown never includes provider API key values or Context
  Packet cache contents.
- Import errors are recoverable; a malformed JSON paste does not write partial
  rows and a later valid JSON can still import.

## Generated Artifacts

Flutter localization bindings are generated from `apps/mobile/lib/l10n/*.arb`
with `flutter gen-l10n`.
