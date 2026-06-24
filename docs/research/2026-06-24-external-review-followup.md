# 2026-06-24 External Review Follow-Up

Status: complete

Scope: follow-up review for the subagent-driven phase-one foundation changes.

## Review Inputs

Kimi CLI and Xiaomi `mimo-v2.5-pro` were used as external reviewers after
local subagent changes landed. The review context was generated from the local
working tree and kept outside the repository. API keys and private user data
were not written to repository files.

## Confirmed Findings

- The `local_db` DAO split is behavior-preserving and removes the oversized
  production file, but `part` files still share one Dart library scope. This is
  acceptable for the current mechanical split, and future persistence work
  should still treat the DAO group as one coordinated write scope.
- The mobile widget tests intentionally assert user-visible behavior and use
  deterministic fake runtime/model paths. Their copy assertions may need updates
  when localization or copy changes land, but they are useful phase-one
  regression guards.
- Runtime tests should explicitly cover privacy tier materialization so
  local-first privacy fields do not regress while the event chain grows.
- The split DAO files should be documented in the module README so future
  agents understand that `daos.dart` remains the public import boundary.

## Actions Taken

- Documented the DAO split and public import boundary in
  `packages/dart/local_db/README.md`.
- Added a runtime test proving that explicit `WnPrivacy` values are materialized
  from capture and agent output drafts into persisted events.
- Kept widget tests focused on user-visible outcomes instead of replacing them
  with only internal state assertions.

## Rejected Or Deferred Findings

- Converting `local_db` DAO part files into standalone libraries is deferred.
  The current change is a low-risk mechanical split; a deeper persistence
  boundary refactor should happen only when DAO contracts or generated Drift
  code are redesigned.
- Reported missing test helper and provider type issues were false positives:
  local `dart test`, `dart analyze`, `flutter test`, and `flutter analyze`
  already compile and exercise those paths.

## Kimi Persistence / Provider Review

Kimi was run again on a narrowed, read-only path set covering local DB backup,
schema migration, provider DAOs, provider adapters, and mobile provider
settings. It found no P0 issues.

Confirmed issues and fixes:

- Backup import was non-idempotent and failed on duplicate primary keys without
  a product-level explanation. The implementation now preflights duplicate IDs
  and existing target rows before inserting, then runs `PRAGMA foreign_key_check`
  before commit. Tests cover conflict rejection and duplicate IDs inside backup
  sections.
- Provider settings persistence wrote provider rows and default selection in
  separate operations. The provider-config DAO now has an atomic `saveAll`
  path for provider records plus default selection.
- Unknown provider capabilities and kinds could silently downgrade to `chat` or
  OpenAI-compatible behavior. Loading now drops unknown capabilities and skips
  unknown provider kinds instead of changing protocol semantics.
- Provider HTTP tests now cover HTTP 408 timeout classification and
  pre-response network/timeout exceptions.

Product decision:

- Kimi suggested excluding API key values from backups. The product requirement
  is the opposite: user-initiated backups are full portability artifacts and
  must include provider API keys. The implementation now stores provider API
  keys in the local DB schema and exports/imports them in backup JSON. UI and
  docs explicitly mark backup JSON as secret-bearing user data.

## Kimi Mobile / I18n Review

Kimi was run on a narrowed mobile slice covering app routing, l10n ARBs, backup
UI, provider settings UI, chat UI/application code, capture Home rendering, and
the relevant widget tests. It found no P0 issues.

Confirmed issues and fixes:

- Capture Memory titles were using Chinese user-visible strings as state
  values. The capture pipeline now stores stable title keys and Home maps those
  keys through l10n.
- The deterministic local chat assistant and chat context source had embedded
  user-visible copy. Chat now injects localized assistant copy and context
  labels from the current `AppLocalizations`.
- Chat load errors no longer render raw exception strings. Backup failures are
  also mapped to short safe categories instead of displaying raw exception
  details.
- Backup widget tests now run with an explicit English locale and the i18n
  widget test covers the Chinese backup warning.
- Session chips now provide a localized tooltip when answer generation disables
  session switching.

Deferred to emulator QA / follow-up:

- Kimi flagged possible bottom navigation / composer safe-area issues on small
  devices. This will be checked in Android emulator click QA before finalizing
  the report.
- Provider settings still need an explicit "clear saved key" UX; the current
  documented behavior is "leave blank to keep the saved key."
- Backup export uses selectable JSON but does not yet provide a dedicated copy
  or share action.

## Kimi Latest UI Fix Review

After Android emulator QA found real UI issues, Kimi reviewed the latest Chat
and Backup fixes.

Confirmed issues and fixes:

- Kimi flagged the first Chat localization implementation as a blocker because
  `ChatPage` created a nested `ProviderScope`, which could tie
  `chatControllerProvider` lifecycle to the page subtree. The localized chat
  copy/context-label overrides are now hoisted to `WideNoteApp` through
  `MaterialApp.router.builder`, and `ChatPage` no longer creates a
  `ProviderScope`.
- A follow-up Kimi review of the P0 fix reported: blocker fixed, no new
  blocker.
- The Chat composer is now pinned outside the scrollable message list. Widget
  tests cover long answers and tab-navigation round trips.
- Backup JSON preview now excludes the full JSON from semantics so UI dumps and
  assistive technologies do not read secret-bearing backup content. The visible
  warning and manifest counts remain accessible.
- Backup import controls are constrained so they remain reachable after export;
  widget tests cover the post-export import-control geometry.

Remaining non-blocking review notes:

- Replace remaining hard-coded light colors in Chat surfaces with theme tokens
  before dark mode.
- Add a copy/share affordance for backups.

## Final External Review

Claude Code could not authenticate to the Xiaomi token-plan endpoint with the
provided key because the CLI used Anthropic authentication semantics that the
endpoint rejected. The same key was then used through the Anthropic-compatible
HTTP endpoint with `x-api-key`, matching the app adapter. The review context
was kept in `/tmp` and excluded secrets.

Confirmed final review inputs:

- Current working tree diff/stat.
- Final Android emulator result:
  `/tmp/widenote-final-android-qa-20260624/continue_result.json`.
- Final automated validation results.
- Focus diffs for capture fallback diagnostics, Packs provider status, and
  related widget/unit tests.

External findings and disposition:

- Reported P0: `harness_uiautomator_fatals: true` might invalidate emulator
  QA. Disposition: not an app blocker. The fatal traces are from
  `com.android.commands.uiautomator.Launcher` with
  `UiAutomationService already registered`; app-filtered bad markers are empty.
  The report now documents this explicitly.
- Reported P1: backup restore was not evidenced. Disposition: covered by
  `LocalBackupService` unit tests and Backup page widget tests for import,
  migration, duplicate rejection, read-model invalidation, and provider key
  round-trip. Emulator import by typing full JSON is not practical because the
  JSON preview is intentionally excluded from accessibility semantics to avoid
  secret leakage.
- Reported P1: provider API keys in backup need safety boundary. Disposition:
  product decision is to include keys. The UI keeps the export warning visible,
  backup JSON is excluded from accessibility dumps, tests cover key round-trip,
  and docs classify backup JSON as secret-bearing user data.
- Reported P2: orchestrator complexity and event/trace growth. Disposition:
  acceptable for phase one because targeted tests cover the chain, fallback,
  review, media, and provenance paths; extraction of knowledge-layer builders
  and retention/archival policy remain follow-up architecture work.

No final P0/P1 application code changes were required after this review.
