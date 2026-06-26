# 2026-06-26 Android Emulator QA

## Status

Android emulator QA passed for the phase-one local capture -> runtime -> chat -> todos -> packs -> backup slice.

At the time of this Android pass, iOS simulator QA was blocked because the
workspace did not contain `apps/mobile/ios`. That blocker was later resolved in
[2026-06-26 iOS Simulator QA](./2026-06-26-ios-simulator-qa.md).

## Environment

- Date: 2026-06-26
- Emulator: `Medium_Phone_API_35`
- Device serial: `emulator-5554`
- App package: `app.widenote.dev`
- Activity: `app.widenote.MainActivity`
- APK: `apps/mobile/build/app/outputs/flutter-apk/app-dev-debug.apk`

The emulator was started headlessly with:

```sh
/Users/guangmo/Library/Android/sdk/emulator/emulator -avd Medium_Phone_API_35 -no-window -no-audio -no-snapshot -no-boot-anim -gpu swiftshader_indirect -verbose
```

The app was rebuilt and installed after the Packs back-navigation fix:

```sh
cd apps/mobile
env -u ws_proxy -u wss_proxy NO_PROXY=localhost,127.0.0.1,::1 no_proxy=localhost,127.0.0.1,::1 flutter build apk --debug --flavor dev
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-dev-debug.apk
adb -s emulator-5554 shell am force-stop app.widenote.dev
adb -s emulator-5554 shell logcat -c
adb -s emulator-5554 shell am start -n app.widenote.dev/app.widenote.MainActivity
```

## Paths Tested

### Home Persistence

After reinstalling the debug APK, the home screen still showed the captured local state:

- Processing: `1 processed`
- Memory: `1 accepted`
- Cards: `2 cards`
- Insight: `3 source-linked`

This verifies that the local database persisted across reinstall and launch.

### Capture Pipeline

Input text was recorded through the home quick-capture field and processed by the local runtime.

Observed UI state after processing:

- `Processing 1 processed`
- `Memory 1 accepted`
- `Cards 2 cards`
- `Insight 3 source-linked`

No app crash or SQLite errors were found in logcat.

### Source-Linked Todos

The Todos tab showed one source-linked todo generated from the captured text:

- `Follow up: ...`
- `source: local-...`
- `suggested by agent`

This verifies the `pack.todo` path from event subscription to source-linked todo UI.

### Chat Context Packets

The Chat tab answered a local query using source-linked context and exposed source chips:

- Memory source chip
- Record source chip
- Todo source chip
- Card source chips

This verifies that Chat reads through `ContextPacketBuilder` instead of directly scanning raw local tables.

### Packs Root

The Packs tab showed runtime evidence from real trace events:

- Trace events: `15`
- Runs: `2`
- Warnings: `0`

### Pack Library

The Pack Library showed embedded official manifests:

- `pack.default v0.1.0 enabled 4 permissions 3 outputs`
- `pack.todo v0.1.0 enabled 1 permission 1 output`

### Model Provider Settings

The Model Provider page opened successfully and showed the empty local setup state:

- `Add provider`
- `No providers configured.`

### Trace Console

The Trace Console opened successfully and showed real runtime events:

- `Trace events: 15`
- `Runs: 2`
- `Warnings: 0`
- `pack.default / agent.capture_loop`
- `pack.todo / agent.todo_loop`

### Backup Export

The Backup page opened successfully, showed the safe-backup policy, and exported JSON.

Observed text:

- `Safe export omits provider API keys. Re-enter provider keys after restore.`
- `Safe backup JSON is ready.`

Observed manifest counts:

- `attachments: 0`
- `captures: 1`
- `cards: 2`
- `chat_messages: 2`
- `chat_sessions: 1`
- `context_packet_cache: 1`
- `event_log: 5`
- `insights: 3`
- `memory_candidates: 1`
- `memory_items: 1`
- `model_provider_configs: 0`
- `pack_installations: 0`
- `permission_grants: 0`
- `runtime_runs: 0`
- `runtime_tasks: 0`
- `todos: 1`
- `trace_events: 15`

### Packs Back Navigation

Android system Back was tested on Packs child pages.

Before fix, pressing system Back from Backup exited to the launcher even though the Packs tab remained selected.

After fix:

- Back from `/plugins/backup` returns to `/plugins`.
- Back from `/plugins/traces` returns to `/plugins`.
- The Packs tab remains selected.
- The Packs root still delegates Back to the platform, covered by widget test.

## Evidence Files

Local QA artifacts:

- `/tmp/widenote-after-reinstall-summary.txt`
- `/tmp/widenote-backup-before-back-summary.txt`
- `/tmp/widenote-backup-after-back-summary.txt`
- `/tmp/widenote-model-provider-summary.txt`
- `/tmp/widenote-trace-console-summary.txt`
- `/tmp/widenote-trace-after-back-summary.txt`
- `/tmp/widenote-pack-library-final-summary.txt`
- `/tmp/widenote-backup-exported-final-summary.txt`
- `/tmp/widenote-backup-exported-final.png`
- `/tmp/widenote-app-logcat-final.txt`

App process logcat was scanned with:

```sh
rg -n "FATAL EXCEPTION|E/flutter|Unhandled|CapturePipelineException|ContextPacket|SQLiteException|sqlite|Exception" /tmp/widenote-app-logcat-final.txt
```

No matching app-level errors were found.

## Automated Validation

Targeted Packs navigation tests:

```sh
cd apps/mobile
env -u ws_proxy -u wss_proxy NO_PROXY=localhost,127.0.0.1,::1 no_proxy=localhost,127.0.0.1,::1 flutter test test/plugins_page_test.dart
```

Result: 8 tests passed.

Mobile analyzer:

```sh
cd apps/mobile
env -u ws_proxy -u wss_proxy NO_PROXY=localhost,127.0.0.1,::1 no_proxy=localhost,127.0.0.1,::1 flutter analyze
```

Result: no issues found.

## Follow-Ups

- Add deeper Backup restore QA once encrypted full backup and secret restore flows are implemented.
- Add keyboard/focus Back behavior checks for Packs child pages if those pages gain multiline entry fields or nested modal flows.
