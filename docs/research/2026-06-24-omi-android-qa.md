# Omi Reference Slice Android QA

Date: 2026-06-24

Device: `emulator-5554`

Package: `app.widenote.widenote_mobile`

Build: `flutter build apk --debug`

Artifacts: `/tmp/widenote-omi-qa/`

## Scope

This QA pass validates the Omi clean-room reference slice in the Android
emulator: Capture Console mode switching, text capture, voice draft review,
share/photo import, attachment removal, and bottom navigation.

The slice does not change model-provider routing or ASR. It uses the local
deterministic runtime path. `WIDENOTE_QA_MIMO_API_KEY` was not present in the
shell environment, and no API key was written into commands, files, APK
dart-defines, logs, or reports.

## Real-Tap Coverage

All taps were driven through `adb shell input tap` after deriving coordinates
from `uiautomator` XML bounds. Screenshots and XML trees were captured in
`/tmp/widenote-omi-qa/`.

| Flow | Rounds | Result |
| --- | ---: | --- |
| Clean launch and blank Record tap | 1 | Passed; no crash and no local record created. |
| Text capture | 10 | Passed; reached `10 processed` / `10 accepted`. |
| Voice draft review | 10 | Passed after fixes; pending transcript blocks save, exposes `Review attachments before saving.`, then `Use transcript` allows save. |
| Import/share capture | 10 | Passed; reached `30 processed`. |
| Photo add/remove | 1 | Passed after fixes; attachment name is exposed to UI tree and removal clears it. |
| Bottom navigation | 4 tabs | Passed; Home, Chat, Todos, Packs were tapped with UI-tree coordinates. |

## Bugs Found And Fixed

1. Voice review error was visually inserted but not exposed to Android
   accessibility/UIAutomator.
   - Fix: `_CaptureErrorLine` now provides explicit live-region semantics.
   - Test: `widget_test.dart` reads the `capture-error-line` semantics label.

2. Attachment rows exposed action buttons but not the attachment display name in
   Android accessibility/UIAutomator.
   - Fix: `_AttachmentPreviewRow` now provides an explicit semantics label with
     display name and state line.
   - Test: `widget_test.dart` reads the `attachment-row-*` semantics label.

3. QA script exact-matched bottom navigation labels as single-line text, while
   Android exposed them as multi-line labels.
   - Fix: script-only change; navigation rerun used contains matching. No app
     code change was needed.

## Logs

- `crash.log`: 0 lines.
- `logcat.txt`: no app crash. Observed emulator system time warnings and
  `uiautomator` command process start/stop noise.

## Key Evidence Files

- `/tmp/widenote-omi-qa/qa-10-text-rounds.png`
- `/tmp/widenote-omi-qa/qa-20-voice-rounds.png`
- `/tmp/widenote-omi-qa/qa-30-import-rounds.png`
- `/tmp/widenote-omi-qa/qa-photo-removed.png`
- `/tmp/widenote-omi-qa/qa-tab-chat.png`
- `/tmp/widenote-omi-qa/qa-tab-todos.png`
- `/tmp/widenote-omi-qa/qa-tab-packs.png`
- `/tmp/widenote-omi-qa/qa-tab-home.png`
- `/tmp/widenote-omi-qa/qa_summary.json`
- `/tmp/widenote-omi-qa/crash.log`
