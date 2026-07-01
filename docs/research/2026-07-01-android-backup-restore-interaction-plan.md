# Android Back, Backup Export, And Restore Interaction Plan

Date: 2026-07-01

Status: implementation plan, Kimi-reviewed

Scope: system-back behavior, visible back controls, user-accessible backup
export, and destructive restore confirmation for the WideNote mobile app.

## User Problems

The implementation needs to address four production-use problems:

- Android system Back should return to the previous in-app level when a user
  opened search, details, source links, settings children, plugin children, or
  modal surfaces. It should not unexpectedly leave the app.
- Page-level back controls should be placed as left-side navigation controls.
  Right-side controls should be reserved for close/dismiss or real page
  actions.
- Backup export should produce a user-accessible compressed archive. It should
  not make the main path feel like JSON export, and it should not save only to
  the app-private support directory.
- Import/restore should be an explicit full-replacement flow after a clear
  warning. It should not reject the restore as a local-data conflict after the
  user has chosen to restore.

## WideNote Findings

### Android Back And Navigation

The main router lives in `apps/mobile/lib/app/app_router.dart`.

Current `WideNoteShell` only intercepts Back for `/settings/*` and
`/plugins/*`. It does not cover timeline search/details or cross-feature source
links. Many user-initiated drill-ins currently use `context.go(...)`, which
replaces the route instead of preserving the previous screen in the navigation
stack.

High-risk drill-in examples:

- Timeline search:
  - `apps/mobile/lib/features/timeline/presentation/timeline_page.dart`
  - `apps/mobile/lib/features/capture/presentation/home_header.dart`
  - `apps/mobile/lib/features/timeline/presentation/timeline_search_page.dart`
- Timeline item/card details:
  - `apps/mobile/lib/features/timeline/presentation/timeline_page.dart`
  - `apps/mobile/lib/features/capture/presentation/home_page.dart`
  - `apps/mobile/lib/features/timeline/presentation/timeline_widgets.dart`
- Source links opened from details:
  - `apps/mobile/lib/features/timeline/presentation/card_detail_page.dart`
  - `apps/mobile/lib/features/timeline/presentation/timeline_item_detail_page.dart`
- Source links opened from other modules:
  - `apps/mobile/lib/features/memory/presentation/memory_page.dart`
  - `apps/mobile/lib/features/todos/presentation/todos_page.dart`
  - `apps/mobile/lib/features/chat/presentation/chat_page.dart`
  - `apps/mobile/lib/features/traces/presentation/trace_console_page.dart`

The fix should use `context.push(...)` for user-initiated drill-ins and keep
existing fallback behavior for direct links or cold starts.

Dialogs and sheets generally use Flutter modal routes and are lower risk. The
capture sheet should still get an explicit widget test that proves Android Back
closes the sheet without leaving Home.

### Back Control Placement

WideNote mostly uses custom page headers rather than `AppBar`.

The most visible wrong-placement controls are:

- Timeline search uses a right-side `Icons.arrow_back`.
- Timeline item detail uses a right-side `Icons.arrow_back`.
- Card detail uses a right-side `Icons.arrow_back`.
- Daily Recap uses a right-side close icon despite being a normal pushed page.
- Settings root uses a right-side close icon. This is acceptable only if the
  page is intentionally modal, but the current route behaves like a normal page.

The implementation should introduce a small shared mobile page-header pattern
or update the existing timeline/recap/settings headers so that:

- Back navigation appears on the left.
- Right side is used for search, save, copy, close modal, or other actions.
- Android Back and visible back controls share the same destination.

### Backup Export

The current user-facing backup path is still two-stage:

1. User taps "Create .widenote backup".
2. The page generates safe backup JSON and Owner Export Markdown in memory.
3. The page shows "Copy JSON", "Copy Markdown", JSON preview, Markdown
   preview, and a separate "Save .widenote file" action.
4. Saving writes to `getApplicationSupportDirectory()/local-data/exports`,
   which is an app-private path on mobile.

Current platform code supports opening/sharing `.widenote` into WideNote for
import, but there is no equivalent Android document-create or share/export
flow for getting the backup out of the app-private directory.

The backup archive is ZIP-compatible and currently includes:

- `widenote-backup/manifest.json`
- `widenote-backup/restore/safe-backup.json`
- `widenote-backup/owner-export/owner-export.md`

The current architecture contract also says safe `.widenote` backup includes
original media/audio bytes, but the codec only writes JSON, Markdown, and
manifest entries. This must be closed before the restore flow is presented as
complete backup coverage.

### Import And Restore

The current local DB import is an append-only import with conflict rejection:

- `LocalBackupService.importJson(...)`
- `LocalBackupService.importBackup(...)`
- `_rejectImportConflicts(...)`

If local rows already have matching IDs, import throws `StateError`, which UI
maps to "Backup conflicts with local data." It does not replace all local data,
does not delete local rows missing from the backup, and does not ask the user
to confirm a destructive restore.

The fix should add an explicit replace strategy instead of simply removing
conflict checks.

## Memex Reference Findings

The reference checkout was
`/Users/guangmo/.codex/worktrees/292-quick-note-deeplink/memex`.

Relevant patterns:

- Custom overlay back handling uses `PopScope` and widget tests with
  `tester.binding.handlePopRoute()`.
- Common page back controls are left-side `AppBar.leading` or left-side custom
  detail header controls.
- Backup export creates a `.memex` ZIP archive and then immediately opens the
  system share surface so the user can save to Files, cloud storage, or another
  app.
- Android automatic backup supports user directory choice through
  `ACTION_OPEN_DOCUMENT_TREE` and persisted URI permission.
- Backup import inspects the archive, shows a confirmation dialog with metadata,
  then performs restore.
- Memex restore copy says "overwrite all data", but its file restore path mainly
  replaces files present in the archive. WideNote should be stricter: if the UI
  says full replacement, tests must prove local rows/files absent from the
  backup are removed.

## Proposed Implementation Groups

### Group A: Navigation And Visible Back Controls

Implementation:

- Change user-tap drill-ins from `context.go(...)` to `context.push(...)` for
  timeline search, timeline detail, card detail, source links, and source-link
  openings from Memory, Todos, Chat, and Trace Console.
- Keep direct-link fallback: when a detail page has no navigation stack, the
  visible back control goes to `/timeline`.
- Move timeline search/detail/card-detail visible back controls to the left
  side of the page header.
- Move Daily Recap and Settings root navigation controls to left-side back
  controls unless they are changed to actual modal presentation later.
- Extend existing settings/plugins Back tests to cover all child entries,
  including transcription and pack/model-provider/permission children.

Tests:

- `timeline_widget_test.dart`: system Back from search/detail/source detail
  returns to the originating screen.
- `memory_page_test.dart`, `todos_page_test.dart`, `chat_page_test.dart`,
  `trace_console_page_test.dart`: system Back from opened source detail returns
  to the originating feature page.
- `settings_page_test.dart`: system Back from Settings root opened from Home
  returns Home; settings child routes include transcription.
- `plugins_page_test.dart`: plugin child Back coverage includes pack library,
  permission gate, model providers, backup, and trace console.
- `recap_page_test.dart`: system Back from recap opened from Home returns Home.
- `capture_console_widget_test.dart`: system Back closes the capture sheet
  without leaving Home.

### Group B: User-Accessible Backup Export

Implementation:

- Collapse the primary export path into one user action that creates a
  `.widenote` archive and hands it to a user-accessible destination.
- Add a platform export boundary:
  - Android: `ACTION_CREATE_DOCUMENT` for "Save to..." and a share intent for
    "Open in/send to another app".
  - iOS: share/document export surface.
- Keep the app-private directory only as temporary staging, not as the final
  user-visible destination.
- Hide JSON/Markdown copy and preview from the default path. If retained, keep
  them behind an advanced/debug disclosure.
- Extend archive entries to include original attachment/media bytes when the
  source file is available. Add manifest entries with role, attachment ID, size,
  and SHA-256.
- During restore extraction, verify media checksums and rewrite restored
  attachment paths to the current app storage location.

Tests:

- `packages/dart/local_db`: archive contains media entries; checksum mismatch
  rejects; extraction reports restored media paths; missing source media is
  reported without leaking local paths.
- `apps/mobile`: widget tests prove the primary export path calls the platform
  exporter and no longer presents JSON as the main export.
- Android manifest/platform tests cover document-create/share export wiring.
- Android emulator validation saves a `.widenote` through the system picker or
  share surface and then opens it back into WideNote.

### Group C: Full-Replacement Restore

Implementation:

- Add an explicit restore strategy to `LocalBackupService`, for example
  `importBackup(strategy: LocalBackupImportStrategy.replaceAll)` or
  `replaceWithBackup(...)`.
- Keep append/import-with-conflict-check only if tests or migration needs still
  require it.
- Add a preflight/inspection step for pasted JSON and `.widenote` archive paths.
- Show a destructive confirmation dialog before any write:
  - State that current local records, Memory, cards, providers, todos, traces,
    and restorable media will be replaced.
  - Show backup counts and whether provider keys must be re-entered.
  - Cancel does not write anything.
- On confirm, run one transaction that clears restorable tables in foreign-key
  safe order, inserts backup rows, verifies `PRAGMA foreign_key_check`, and
  rolls back on failure.
- Restore media from the staged archive before committing metadata, or ensure
  metadata paths are not committed until media restore succeeds.

Tests:

- `packages/dart/local_db`: replace-all deletes local rows absent from backup,
  replaces same-ID rows, restores extra backup rows, and rolls back on failure.
- `apps/mobile`: pasted JSON import asks for confirmation; cancel does not
  write; confirm replaces data. `.widenote` direct-open uses the same
  confirmation path.
- Platform smoke: opening a `.widenote` file should route to Backup and wait
  for user confirmation before writing.

## PR Split

Recommended split:

1. Navigation and visible back controls.
2. Backup export platform access plus archive media entries.
3. Full-replacement restore confirmation.

If a single PR is preferred, keep commits grouped by the three sections above.

## External Review Request

Kimi review should check:

- Whether the navigation plan misses any user-visible page or modal where
  Android Back can still exit unexpectedly.
- Whether `push` versus Shell `PopScope` can conflict with the existing
  settings/plugins child-route fallback.
- Whether the backup export plan is too large for one PR and should split
  platform export from media archive inclusion.
- Whether replace-all restore has any ordering, foreign-key, or media-path
  failure mode not covered by the tests above.
- Whether any proposed external-review input risks exposing private records,
  credentials, local database contents, or backup archives.

## Kimi Review Result

Kimi reviewed this plan and the referenced WideNote code paths in read-only
mode. It did not inspect local databases, backup archives, credential stores,
API keys, or private user records.

### P0 / P1 Findings

Kimi confirmed these P0 blockers:

- Safe `.widenote` backup does not include original media bytes. This violates
  the current source-truth backup contract.
- Restore is append-only with conflict rejection, not full replacement.
- Restore has no destructive confirmation before writes. External `.widenote`
  open currently imports before the user can review and confirm.
- Backup export has no user-accessible destination. The app writes to an
  app-private support directory and lacks Android/iOS export UI.

Kimi confirmed these P1 interaction issues:

- Android system Back exits unexpectedly for user-initiated drill-ins that use
  `context.go(...)`.
- Timeline search/detail/card detail and some normal pages put back/close
  controls on the right side.
- Shell `PopScope` only covers settings/plugin child routes and does not
  replace preserving a real navigation stack for timeline/source drill-ins.

### Added Review Concerns

Kimi added these implementation concerns:

- Adding media entries should bump the archive format version and keep backward
  compatibility for older archives without media.
- Restore must handle missing source media, checksum mismatch, path rewriting,
  local file collisions, staging cleanup, and media-copy failure rollback.
- Replace-all restore must clear tables in foreign-key safe order and verify
  `PRAGMA foreign_key_check`.
- Runtime/background work could write while restore is running; the restore
  implementation should use a clear write boundary and avoid partial commits.
- External `.widenote` open should route to the backup page first and wait for
  confirmation before any write.

### Review-Adjusted PR Split

Kimi recommended four reviewable work packages:

1. Navigation and visible back controls.
2. User-accessible backup export with platform save/share UI.
3. Media bytes in `.widenote` archives.
4. Full-replacement restore confirmation.

This plan accepts that split. A single PR may still group those as separate
commits if repository cadence favors one PR, but each work package should keep
its own tests and validation evidence.
