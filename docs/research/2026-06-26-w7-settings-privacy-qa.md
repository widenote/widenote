# W7-A Settings and Privacy QA

Status: W7-A module accepted with a global full-suite caveat
Date: 2026-06-26

## Scope

This worker only covered the Settings / Privacy hub. It did not change backup
codecs, media adapters, model-provider persistence, trace storage, or permission
schemas.

Changed surfaces:

- `apps/mobile/lib/features/settings/presentation/settings_page.dart`
- `apps/mobile/lib/features/settings/README.md`
- `apps/mobile/test/settings_page_test.dart`
- `apps/mobile/lib/l10n/app_en.arb`
- `apps/mobile/lib/l10n/app_zh.arb`
- generated Flutter localization bindings

## Acceptance Mapping

- Settings is opened from the Home header action and remains outside the bottom
  tab model.
- Settings is a hub for permissions, model providers, backup/restore, and trace
  console.
- Settings child routes under `/settings/*` return to `/settings` through
  system Back.
- Privacy copy states local-first/no-account core usage, revocable/deferred
  permissions, and the safe-backup secret boundary.
- Safe export copy says provider API keys are omitted. Encrypted full backup is
  the future secret-bearing restore path and has no action in this build.
- The hub reads lightweight local status instead of acting as a static note:
  built-in permission count, deferred high-risk permission count, provider
  status, backup state, and trace events/warnings.

## User QA Path

1. Launch the app and tap the Settings icon in the Home header.
2. Confirm Settings is not a bottom tab.
3. Open Privacy & Permissions, Model Providers, Backup & Restore, and Trace
   Console from Settings.
4. Use system Back from each child page and confirm it returns to Settings.
5. Confirm the Privacy section says records work without an account, high-risk
   capabilities are deferred/reviewable, and safe backup does not include API
   keys.
6. Switch app locale through the test harness or app bootstrap and verify both
   English and Chinese Settings copy.

## Test Evidence

Passed:

- `flutter test test/settings_page_test.dart`
  - 5 passed
- `flutter analyze`
  - no issues found

Attempted:

- `flutter test`
  - failed in existing non-Settings tests:
    - `test/widget_test.dart`
    - `test/i18n_widget_test.dart`

The full-suite failures were stale assertions around Home counters, Home empty
text, failure text, and a Chinese backup button label. Targeted W7-A tests and
analyze passed.

## Kimi Review

Review input was sanitized. It included only acceptance criteria, changed file
list, diff summary, and test results. It did not include source files, local DB
content, backups, API keys, secrets, screenshots, or real user data.

Kimi conclusion:

- W7-A Settings / Privacy meets the module criteria.
- No backup codec or media adapter files were touched.
- If W7-A is gated on targeted Settings tests plus analyze, there are no
  functional module blockers.
- If W7-A is gated on the full mobile test suite, current non-Settings stale
  assertions are a branch-health blocker and should be fixed before merge.

## Result

NO_BLOCKERS_FOR_W7A.

Global caveat: the current worktree is not full-suite green until stale
non-Settings widget/i18n assertions are updated.
