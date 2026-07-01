# Mobile Backup Feature

## Purpose

Provides the user-facing local backup and import surface for WideNote mobile.
It wraps the `widenote_local_db` backup codec so users can create a portable
`.widenote` archive, inspect manifest counts, open/share the archive with other
apps, save it to a user-selected destination, and import a `.widenote` file into
the local database after an explicit replace-all confirmation.

## Ownership Boundary

- Owns mobile backup UI state and presentation.
- Does not define the backup format; `packages/dart/local_db` is the source of
  truth for backup schema, validation, import, export, and migration rejection.
- Defaults to a compressed `.widenote` directory archive with
  `manifest.properties`, a full SQLite snapshot, and local capture media files.
  Provider credential values are preserved so restore can use configured model
  providers immediately.
- Runs archive compression and decompression off the main Flutter isolate, and
  imports the extracted SQLite snapshot from a staging directory.
- Includes local capture media bytes in the `.widenote` archive when the
  attachment storage path can be resolved to an app-local file. During restore,
  extracted media is copied back under the mobile capture media directory before
  database rows are replaced.
- Does not auto-import backups received from Android/iOS file-open intents.
  External `.widenote` opens load the file into the Backup page and wait for the
  same destructive replace-all confirmation as in-app import.
- Treats `.widenote` archives as secret-bearing local files because provider
  API keys and provider payload fields are included. The UI tells users to keep
  backups in a trusted destination.
- Keeps legacy JSON and Markdown projections out of the default mobile restore
  path; those projections remain safe/no-secret compatibility surfaces in the
  local DB package.

## Dependencies

- `app/local_database.dart`
- `widenote_local_db`
- Flutter / Riverpod

## Public Surface

- `BackupPage`
- `backupControllerProvider`
- `BackupImportListener`

## User-Tested Boundaries

- `.widenote` archives restore records, Memory, todos, provider credentials,
  pack installation state, permission grants, runtime state, context cache rows
  when present, traces, and local capture media files.
- Full SQLite snapshots preserve provider API key values and provider payload
  fields so restored provider settings are immediately usable.
- Android and iOS register `.widenote` as an app-openable backup file type.
- Android and iOS expose `.widenote` export through system share/open surfaces
  and save-to-selected-location document pickers instead of relying on the
  app-private support directory as the user-facing destination.
- Import is intentionally full replacement after confirmation; local rows that
  are absent from the backup are removed in the same transaction as restored
  rows are inserted.
- Import errors are recoverable; a malformed or unsupported `.widenote` file
  does not write partial rows and a later valid archive can still import.

## Generated Artifacts

Flutter localization bindings are generated from `apps/mobile/lib/l10n/*.arb`
with `flutter gen-l10n`.
