# W7 Integration QA

Date: 2026-06-26

Scope: phase-one usable-state integration after the Settings/Privacy, Backup/Restore, Real Media Capture, and Daily Recap modules landed in the mobile app and shared packages.

## Coordination Model

- W7-A Settings/Privacy was implemented by a module worker and reviewed with a redacted Kimi pass. Result: `NO_BLOCKERS_FOR_W7A`.
- W7-B Backup/Restore was implemented by a module worker and reviewed with a redacted Kimi pass. Result: `NO_BLOCKERS for W7-B scope`.
- W7-C Real Media Capture was implemented by a module worker and reviewed with a redacted Kimi pass. Result: `NO_BLOCKERS` at code level.
- Edge-case review found the right final risks: Settings needed to become the top-right control hub, backup needed a secret boundary before full encrypted restore, and real media needed platform permission/cancel/error coverage. Those are now represented in code, tests, and module QA notes.

## Automated Validation

All commands completed successfully after the W7 integration work:

```sh
git diff --check
node packages/schemas/validate_fixtures.mjs
node tools/pack_validator/validate_test.mjs
node tools/pack_validator/validate.mjs packs/official/default/manifest.json packs/official/todo/manifest.json
cd packages/dart/core && dart analyze && dart test
cd packages/dart/agent_runtime && dart analyze && dart test
cd packages/dart/local_db && dart analyze && dart test
cd packages/dart/memory && dart analyze && dart test
cd packages/dart/model_providers && dart analyze && dart test
cd packages/dart/cards && dart analyze && dart test
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test
cd apps/mobile && flutter test integration_test/phase_one_journey_test.dart -d emulator-5554 --flavor dev
cd apps/mobile && flutter test integration_test/phase_one_journey_test.dart -d AC67CA3B-F4D5-428C-ABBB-08F5AF83DF1D
cd apps/mobile && flutter build apk --debug --flavor dev
cd apps/mobile && flutter build ios --simulator --debug --flavor dev
```

Result counts:

- `packages/dart/core`: 3 tests passed.
- `packages/dart/agent_runtime`: 37 tests passed.
- `packages/dart/local_db`: 65 tests passed.
- `packages/dart/memory`: 13 tests passed.
- `packages/dart/model_providers`: 22 tests passed.
- `packages/dart/cards`: 8 tests passed.
- `apps/mobile`: 155 tests passed, 2 live-provider tests skipped behind opt-in.
- Android integration journey: 2 route-level tests passed.
- iOS integration journey: 2 route-level tests passed.

Post-rebase note: after rebasing onto `origin/main` at `9816d91`, the mobile
suite, Android integration journey, iOS XcodeBuildMCP build/run, and iOS
integration journey were rerun successfully.

## Android Emulator Smoke

Device: `Medium_Phone_API_35` on `emulator-5554`.

Build and install:

- Built `apps/mobile/build/app/outputs/flutter-apk/app-dev-debug.apk`.
- Installed `app.widenote.dev`.
- Cleared app data before the smoke run.

Flows verified:

- Home rendered with the phase-one capture console and top-right Settings entry.
- Settings opened from the top-right control, not from a bottom tab.
- Settings showed local-first/no-account privacy framing, permission/provider/backup/trace status, and safe export status.
- Backup opened from Settings; safe JSON export succeeded; encrypted full backup was described as the future secret-bearing path but did not appear as an action.
- System back returned from Backup to Settings, and the Home tab returned to Home.
- Daily Recap opened and rendered the empty local state correctly.
- Microphone permission denial showed the Android system prompt, produced `Microphone permission denied.`, and did not create a phantom record.
- Camera permission denial showed the Android system prompt, produced `Camera permission denied.`, and did not create a phantom record.
- Text capture still worked after denied media permissions and produced record, Memory, cards, and source-linked insights.
- Route-level integration verified capture -> Memory/card/insight/todo/trace,
  Todo source backlink, completed Todo hiding, permission revoke blocking future
  Pack output while preserving raw capture, and safe backup restore into an
  empty app shell.
- Targeted crash-buffer scan found no WideNote / Flutter fatal lines. The
  buffer contained an Android system Bluetooth crash during emulator startup;
  it was outside the app process.

## iOS Simulator Smoke

Simulator: iPhone 17, simulator id `AC67CA3B-F4D5-428C-ABBB-08F5AF83DF1D`.

Build and launch:

- Workspace: `apps/mobile/ios/Runner.xcworkspace`.
- Scheme: `dev`.
- Configuration: `Debug-dev`.
- Bundle id: `app.widenote.dev`.
- Uninstalled previous build before launch.
- Build and run completed successfully.

Flows verified:

- Home rendered with Chinese locale and top-right Settings entry.
- Settings opened and showed local-first/no-account privacy framing, permission/provider/backup/trace status, and safe export status.
- Backup opened from Settings by tapping the `备份与恢复` row; safe JSON export succeeded.
- Home tab returned to Home.
- Daily Recap opened and rendered source-linked counts from local data.
- Microphone permission prompt appeared with the app purpose string. Tapping `不允许` did not create a phantom record, did not enqueue processing, and returned safely to the voice capture state.
- Route-level integration verified capture -> Memory/card/insight/todo/trace,
  Todo source backlink, completed Todo hiding, permission revoke blocking future
  Pack output while preserving raw capture, and safe backup restore into an
  empty app shell.
- App stopped cleanly after the run.

Observed non-blocking issue:

- The iOS automation snapshot did not confirm a visible in-app error line after microphone denial, even though the capture error row has a stable key and live-region semantics and widget tests cover the denied state. Safety behavior was correct because no record, attachment, or task was created. Track this as a UX polish follow-up if future manual QA also fails to see an in-app denial message.

Simulator/system noise:

- Build logs included SQLite pod warnings and `record_iOS` deprecation warnings.
- Targeted runtime log scan found no app crash or app exception. Simulator
  logs contained UIKit focus and CoreHaptics resource noise from `Runner`;
  those did not fail the integration journey.

## Go / No-Go

Decision: `GO` for the phase-one usable-state milestone.

Rationale:

- Core flows now work without an account or official backend.
- Original capture input is preserved and AI output is derived from source-linked local truth.
- Default agents run without user confirmation noise for Memory/card/insight work.
- Todo remains a separate extension capability rather than a homepage obligation.
- Backup supports safe export now and blocks full secret-bearing export until encryption is implemented.
- Settings owns global controls through the top-right entry.
- Android and iOS simulator smokes both covered real platform permission prompts and no-phantom-record behavior.

Follow-up candidates:

- Recheck visible iOS denial copy in a later manual QA pass.
- Add real encrypted full-backup restore once the encryption boundary is implemented.
- Add orphan media cleanup and media-at-rest encryption policy before broader media storage usage.
