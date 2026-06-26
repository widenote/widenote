# Daily Recap QA

Date: 2026-06-26

## Scope

This note records the coordinator QA pass for the Daily Recap second-level page
after the worker and edge-case review agents completed their module review.

Daily Recap is intentionally a read-only local projection:

- It does not create durable recap storage.
- It does not call live model providers.
- It does not mutate captures, Memory, cards, insights, or todos.
- Todo inclusion follows the source capture/event local date, not todo
  `updatedAt`, so completing an old todo does not pull yesterday's source into
  today's recap.

## Acceptance Checks

- Home exposes a lightweight Daily Recap header action.
- The action opens `/recap` as a second-level page, not a bottom tab.
- The page renders captures, Memory, open/completed todo counts, cards,
  insights, and local evidence counts.
- Empty state works when there is no local object truth for the day.
- Source labels remain visible for source-linked entries.
- Deleted captures/todos and tombstoned Memory are excluded from recap content.
- Android and iOS can open Daily Recap and return to Home in a real simulator.

## Automated Verification

Passed:

```sh
dart format apps/mobile/lib/features/recap/application/daily_recap_repository.dart apps/mobile/test/recap_page_test.dart
cd apps/mobile && flutter test test/recap_page_test.dart
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test
git diff --check
node packages/schemas/validate_fixtures.mjs
node tools/pack_validator/validate_test.mjs
node tools/pack_validator/validate.mjs packs/official/default/manifest.json packs/official/todo/manifest.json
cd packages/dart/agent_runtime && dart analyze && dart test
cd packages/dart/local_db && dart analyze && dart test
cd packages/dart/memory && dart test
cd packages/dart/model_providers && dart test
cd apps/mobile && flutter build apk --debug --flavor dev
cd apps/mobile && flutter build ios --simulator --debug --flavor dev
```

Observed counts:

- `apps/mobile/test/recap_page_test.dart`: 4 passed.
- `apps/mobile` full test suite: 123 passed, 2 live-provider tests skipped by
  explicit opt-in flag.
- `packages/dart/agent_runtime`: 37 passed.
- `packages/dart/local_db`: 61 passed.
- `packages/dart/memory`: 13 passed.
- `packages/dart/model_providers`: 22 passed.

## iOS Simulator Smoke

Tooling: XcodeBuildMCP

- Workspace: `apps/mobile/ios/Runner.xcworkspace`
- Scheme: `dev`
- Configuration: `Debug-dev`
- Simulator: `iPhone 17`
- Bundle id: `app.widenote.dev`

Passed:

- `build_run_sim` succeeded.
- Home rendered with `Open Daily Recap`.
- Tapped `Open Daily Recap`.
- `/recap` rendered with local object truth metrics:
  - 1 record
  - 1 Memory
  - 1 open todo
  - 0 completed
  - 2 cards
  - 3 insights
- Recap entries retained source/event labels.
- Tapped `Close Daily Recap` and returned to Home.
- Stopped simulator app successfully.

Build/runtime logs:

- Build log:
  `/Users/guangmo/Library/Developer/XcodeBuildMCP/workspaces/widenote-f9abedaa71ac/logs/build_run_sim_2026-06-26T06-19-16-518Z_pid23409_5a121d16.log`
- Runtime log:
  `/Users/guangmo/Library/Developer/XcodeBuildMCP/workspaces/widenote-f9abedaa71ac/logs/app.widenote.dev_2026-06-26T06-19-40-717Z_helperpid62871_ownerpid23409_d40ade98.log`

## Android Emulator Smoke

Tooling: adb + `Medium_Phone_API_35`

Passed:

- Built `apps/mobile/build/app/outputs/flutter-apk/app-dev-debug.apk`.
- Installed the APK on `emulator-5554`.
- Resolved launch activity:
  `app.widenote.dev/app.widenote.MainActivity`.
- Home rendered with `Open Daily Recap`.
- Tapped `Open Daily Recap`.
- `/recap` rendered with today's empty state and zero metrics.
- Tapped `Close Daily Recap` and returned to Home.
- Crash buffer was empty.
- Emulator was shut down with `adb emu kill`.

Tooling note:

- The Android QA helper `ui_pick.py` currently uses Python union type syntax not
  supported by the default `python3` on this machine. The smoke used UI tree
  bounds directly after `uiautomator dump`.

## Residual Risk

- Daily Recap source chips are visible labels today; deep-linking each chip to
  a timeline/detail view remains a follow-up.
- The current page is "today" only. Historical day navigation should remain a
  separate product decision before adding durable recap objects or a date
  picker.
- Real camera/microphone capture permission flows are outside this module QA.
