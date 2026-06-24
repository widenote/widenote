# Mobile Backup Feature

## Purpose

Provides the user-facing local backup and import surface for WideNote mobile.
It wraps the `widenote_local_db` backup codec so users can export a portable
JSON backup, inspect manifest counts, and import a pasted backup into the local
database.

## Ownership Boundary

- Owns mobile backup UI state and presentation.
- Does not define the backup format; `packages/dart/local_db` is the source of
  truth for backup schema, validation, import, export, and migration rejection.
- Exports provider credential values because backup/restore is a product
  portability feature. The UI must warn users that exported JSON is
  secret-bearing and should be kept private.

## Dependencies

- `app/local_database.dart`
- `widenote_local_db`
- Flutter / Riverpod

## Public Surface

- `BackupPage`
- `backupControllerProvider`

## Generated Artifacts

None.
