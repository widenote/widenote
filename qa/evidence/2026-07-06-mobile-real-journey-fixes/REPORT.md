# WideNote Mobile Real Journey Fix Verification

## Environment
- Device: `sdk_gphone64_arm64` (`emulator-5554`, `Medium_Phone_API_35`)
- OS: Android 15, API 35
- Flutter: 3.41.7 stable
- Dart: 3.11.5
- Commit: `054e80b6`
- Build: `flutter build apk --debug --flavor dev`
- Clean install: `adb install -r -d -g`, `adb shell pm clear app.widenote.dev`
- Live model: not used. Phase-one journey used deterministic fake provider fixtures.
- Secret scan: `secret-scan-key-patterns.txt` has 0 matches for pasted key fragments or `sk-*` key patterns.

## Commands
- `flutter devices`
- `adb devices`
- `flutter doctor -v`
- `flutter analyze`
- `flutter test test/navigation_hierarchy_test.dart test/settings_page_test.dart test/agent_execution_status_widget_test.dart test/backup_page_test.dart test/android_manifest_test.dart test/backup_import_listener_test.dart test/plugins_page_test.dart test/todos_page_test.dart test/chat_page_test.dart test/trace_console_page_test.dart`
- `flutter test integration_test/phase_one_journey_test.dart -d emulator-5554 --flavor dev`
- `flutter build apk --debug --flavor dev`
- `adb shell am start -n app.widenote.dev/app.widenote.MainActivity`
- `adb shell am start -n app.widenote.dev/app.widenote.MainActivity -a android.intent.action.VIEW -d file:///sdcard/Download/widenote-intent-smoke.widenote -t application/octet-stream`

## Results
| Bug | Fix summary | Emulator evidence | Result |
| --- | --- | --- | --- |
| BUG-001 child pages lacked stable AppBar Back | Added shell-level pinned back for owned child routes without app bars; route parent fallback still uses declared contract. | `screenshots/FIX-BUG001-timeline-child-back-visible.png`, `FIX-BUG001-system-back-home.png`, `FIX-BUG001-appbar-back-home.png`; `flutter-test-targeted-final.txt` | PASS |
| BUG-002 Plugins Permission Gate returned through Settings | Added source-aware parent stack and opened `/settings/permissions` from Plugins with `/plugins` as source parent. | `screenshots/FIX-BUG002-permission-gate-from-packs-final.png`, `FIX-BUG002-system-back-packs-final.png`; `navigation_hierarchy_test.dart` | PASS |
| BUG-003 restore picker cancel showed backup failure | Added explicit picker-cancel exception path that preserves previous state and does not show failure. | `screenshots/FIX-BUG003-system-picker-opened.png`, `FIX-BUG003-picker-cancel-no-error.png`; `backup_page_test.dart` | PASS |
| BUG-004 fake-provider phase-one Todo generation missing | Replaced generic fake model with prompt-ref specific deterministic JSON fixtures and source-ref assertions for todo/insight events. | `logs/flutter-test-phase-one-journey-emulator-final.txt` (`+2 All tests passed`) | PASS |
| BUG-005 small screen Settings overlapped agent status | Agent status layer now measures status pill and reserves height/gap/safe inset; compact large-font widget coverage added. | `screenshots/FIX-BUG005-small-settings-large-font.png`; `agent_execution_status_widget_test.dart` | PASS |
| BUG-006 Android `.widenote` ACTION_VIEW opened wrong route / was silent on unreadable file URI | Disabled Flutter deep-link consumption for backup intents; app-owned listener builds `/ -> /settings -> /settings/backup`; native bridge now emits a safe unreadable marker when copy fails so Backup shows visible error. | `screenshots/FIX-BUG006-explicit-action-view-backup-after-fallback.png`, `FIX-BUG006-explicit-back-settings-after-fallback.png`, `FIX-BUG006-explicit-back-home-after-fallback.png`; `logs/FIX-BUG006-explicit-after-fallback-logcat.txt` | PASS |
| BUG-007 discovered while validating: clean Android launch could hang on splash | `main()` no longer blocks first frame on WorkManager initialization; initialization remains reported via `FlutterError`. | `screenshots/FIX-00-clean-home-after-main-fix.png`; `logs/logcat-clean-launch-after-main-fix-filtered.txt` | PASS |

## Validation Summary
- `flutter analyze`: PASS (`logs/flutter-analyze-final.txt`)
- Targeted widget/unit route suite: PASS, 107 tests (`logs/flutter-test-targeted-final.txt`)
- Android emulator integration journey: PASS, 2 tests (`logs/flutter-test-phase-one-journey-emulator-final.txt`)
- Android dev debug APK build: PASS (`logs/flutter-build-apk-dev-debug-after-intent-fallback.txt`)
- Manual emulator screenshots: captured under `screenshots/`
- Device/log evidence: captured under `logs/`

## Notes
- The ACTION_VIEW chooser path is device-dependent because this emulator also has another app declaring compatible file handlers. The final proof uses an explicit WideNote component with the same ACTION_VIEW data/type to isolate WideNote initial-route behavior.
- The invalid `.widenote` file used for BUG-006 is a deterministic test fixture containing only `invalid-widenote-smoke`.
