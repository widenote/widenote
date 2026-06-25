# 2026-06-25 Mobile Entry Closure Android QA

Status: passed

Device: `Medium_Phone_API_35`

Serial: `emulator-5554`

Package: `app.widenote.dev`

Build: `flutter build apk --debug --flavor dev`

## Flow Covered

The QA run cleared app data, installed the dev debug APK, launched the app, and
used UIAutomator-derived coordinates for taps.

| Area | Result | Evidence |
| --- | --- | --- |
| Capture | Passed | Text capture saved and updated Processing, Memory, Cards, and Insight counters. |
| Timeline detail | Passed | Timeline rows for todos/insights/cards were clickable; Todo detail opened. |
| Source drill-down | Passed | Source ref from Todo detail opened Capture detail. |
| Todos | Passed | Todo completed, showed checked/completed state, then reopened to suggested state. |
| Memory | Passed | Memory page opened from Home, edit saved as revision 2, delete tombstoned as revision 3, restore returned active revision 4. |
| Pack Library | Passed | Built-in `pack.default` and `pack.todo` were visible with permission/output counts. |
| Permission Gate | Passed | Granted built-in permissions and deferred high-risk permissions were visible. |
| Backup | Passed | Backup exported, showed manifest counts, saved JSON/Markdown files, and displayed app-local paths. |

## Artifacts

- Final screenshot: `/tmp/widenote-entry-closure-final.png`
- Crash buffer: `/tmp/widenote-entry-closure-crash.log`
- Full logcat: `/tmp/widenote-entry-closure-logcat.log`
- UIAutomator snapshots: `/tmp/widenote-entry-*.xml`
- UI summaries: `/tmp/widenote-entry-*-summary.txt`

## Log Review

- `adb logcat -b crash` produced an empty crash buffer.
- App-filtered fatal markers were absent. The `AndroidRuntime` lines in the
  full log were from `com.android.commands.uiautomator.Launcher`, not from
  `app.widenote.dev`.

## Notes

- Import-latest-file success was not repeated on the same emulator database
  after export because the current backup import correctly rejects duplicate
  local IDs. The success path is covered by widget tests using an empty target
  database and fake file store.
- Real platform media/share/clipboard/file-picker entrypoints remain deferred.
