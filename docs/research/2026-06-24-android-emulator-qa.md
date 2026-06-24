# 2026-06-24 Android Emulator QA And MemeX Parity Report

Status: complete

Scope: WideNote phase-one Android client, MemeX feature parity baseline, real
Xiaomi MIMO QA model adapter, local-first capture and agent chain validation.

## Final Phase-One QA Update

This section supersedes earlier baseline/gap notes in this file. Provider
settings, backup/import, chat, i18n, timeline/card browsing, media capture, and
the Agent chain now exist in the phase-one implementation. The final pass was
run on `Medium_Phone_API_35` / `emulator-5554` with real `adb` taps and a
debug APK built with the QA Xiaomi MIMO key and live provider-test flag.

Latest APK:

- `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`
- Built with the QA-only Xiaomi MIMO dart-define path for real model calls.
- The API key was not committed to source, fixtures, docs, or report output.

Latest emulator evidence:

| Scenario | Real-click coverage | Result | Notes |
| --- | ---: | --- | --- |
| Capture + full Agent chain | 10 processed captures | Passed | Real MIMO endpoint was called on every capture. One capture produced a model response; nine hit provider failure/rate-limit paths and were safely routed to Memory Review as low-confidence proposals. Memory/Card/Insight/Todo/Trace generation still completed. |
| Attachment controls | 10 Photo + 10 Voice + 10 Import add/remove loops | Passed | Voice review required `Use transcript`; all attachment controls were exercised by real taps. Attachments were removed after each loop, so final DB attachment count is intentionally zero. |
| Chat | 10 user questions | Passed | Persistent local chat produced 20 messages in one session and kept the composer reachable. |
| Provider settings | MIMO add/save + live connection test | Passed | The provider was configured through the UI with the real key, persisted to local DB, and live endpoint connection returned `connected`. Packs status no longer stayed `not connected`. |
| Backup export/import | Export UI plus unit/widget import coverage | Passed | Emulator verified warning and manifest counts. Unit/widget tests verify import, migration compatibility, duplicate rejection, read-model invalidation, and provider API key round-trip. |
| Timeline/search/card browsing | Open timeline + search `QA01` | Passed | Timeline showed source-linked content and search found the capture-derived item. |

Final emulator counters:

| Section | Count |
| --- | ---: |
| `captures` | 10 |
| `memory_items` | 1 |
| `memory_candidates` | 10 |
| `cards` | 11 |
| `insights` | 3 |
| `todos` | 10 |
| `chat_sessions` | 1 |
| `chat_messages` | 20 |
| `model_provider_configs` | 1 |
| `event_log` | 50 |
| `trace_events` | 110 |
| `model_fallback_events` | 9 |
| `fallback_status_events` | 3 |

Final artifacts:

- XML/UI/log evidence directory:
  `/tmp/widenote-final-android-qa-20260624` with 130 non-SQLite files after
  deleting temporary DB copies that contained the UI-entered provider key.
- Summary:
  `/tmp/widenote-final-android-qa-20260624/continue_result.json`.
- Logcat:
  `/tmp/widenote-final-android-qa-20260624/logcat.txt`.

Logcat note: repeated `FATAL EXCEPTION` entries belonged to
`com.android.commands.uiautomator.Launcher` with
`UiAutomationService already registered`, caused by overlapping UI-tree dumps
from the QA harness. App-filtered markers for `app.widenote.widenote_mobile`
were empty: no app-process fatal, unhandled exception, or capture failure was
found in the final log.

Issues found and fixed during the latest emulator pass:

- Chat composer was part of the scrollable message content and disappeared
  after a long answer. Fixed by pinning the composer outside the message
  `ListView`. Added `chat_page_test.dart` coverage for long answers and
  tab-navigation state retention.
- Kimi flagged the first Chat localization fix as a blocker because it created
  a nested `ProviderScope` inside `ChatPage`. Fixed by hoisting localized chat
  provider overrides to `WideNoteApp`. Kimi re-reviewed the follow-up patch and
  confirmed the blocker was fixed.
- Backup export preview exposed the full backup JSON to Android accessibility
  dumps. Fixed by wrapping the visible `SelectableText` in `ExcludeSemantics`;
  the warning and manifest counts remain accessible.
- Backup import controls were hard to operate after export because the import
  text field was too tall. Reduced the field to a fixed four-line multiline
  input and added a widget geometry regression test.
- The release/main Android manifest lacked `INTERNET`, so real model calls
  failed on device even though unit tests passed. The manifest now declares the
  permission and a regression test checks it.
- Processing remained editable during a long model request, allowing later
  `adb input text` calls to concatenate into the previous capture. The capture
  composer is now disabled while processing and has a widget regression test.
- Provider connection testing is now live when explicitly enabled with the
  QA/build flag, while CI and normal local tests still use deterministic
  offline validation.
- Packs provider status now reflects saved/connected providers instead of a
  static `not connected` label.

## Inputs

- MemeX upstream reference: `memex-lab/memex` README, current public repository
  snapshot reviewed on 2026-06-24.
- MemeX backup sample:
  `/Users/guangmo/Downloads/memex_backup_2026-06-16T01-11-47-828425.memex`.
  Only aggregate structure was inspected; private note contents were not copied
  into this repository.
- WideNote APK:
  `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`.
- Emulator: `Medium_Phone_API_35`, serial `emulator-5554`.
- Package: `app.widenote.widenote_mobile`.
- Real model: Xiaomi `mimo-v2.5-pro` through the QA-only
  `WIDENOTE_QA_MIMO_API_KEY` dart-define path. The key is not stored in source,
  fixtures, docs, or QA artifacts.

## MemeX Backup Shape

The backup is a zip archive of about 140 MB with 3,955 files and about
263.9 MB uncompressed data. Aggregate structure:

- Top-level areas: `workspace`, `db`, `settings.json`, `manifest.json`.
- Main workspace folders: `_System`, `Cards`, `Facts`, `KnowledgeInsights`,
  `PKM`, `ChatSessions`, `ScheduleAggregations`, `Characters`, `Schedule`.
- System subareas: `state_dir`, `llm_calls`, `EventLogs`,
  `character_memory`, `memory`, tag/stat files, processed hashes, schedule
  refresh state.
- File mix: 3,069 JSON files, 675 YAML files, 102 Markdown files, 69 JSONL
  files, 21 text files, 15 media files, and one SQLite database.

This confirms MemeX is not only a capture app; it has durable cards/facts,
insights, chat sessions, characters, schedules, event logs, LLM call traces,
backup metadata, and local database state.

## Parity Baseline

MemeX capabilities used as the phase-one comparison baseline:

- Local-first capture for text, photos, and voice.
- Multi-agent processing into cards, knowledge/facts, insights, and memory.
- P.A.R.A. organization, auto tags, entities, and cross references.
- Conversational assistant with persistent memory.
- Character/companion mode and SillyTavern-compatible character workflows.
- Custom Agent system with event triggers, per-agent prompts/config, scripts,
  retry, sync/async modes, and working directories.
- Data freedom: local storage, backup/restore, export, and no required cloud
  dependency.
- Broad model provider support, including BYOK providers and local providers.

Current WideNote phase-one status:

- Covered in this run: local-first text capture, raw record preservation,
  source-linked todos, accepted Memory, sensitive Memory review,
  accept/reject/edit review actions, basic tabs for chat/todos/plugins,
  runtime event and trace persistence, and Agent Pack-shaped UI placeholders.
- Partially covered: model provider path exists as QA-only Xiaomi MIMO adapter,
  but not yet a user-facing provider settings flow.
- Not yet covered: photo/voice capture, real chat assistant, import/export UI,
  backup/restore, P.A.R.A. views, character/companion flows, schedule flows,
  custom Agent editor/runner UI, and full MemeX backup import.

## Code Changes From QA

The emulator run found a real bug before the final pass:

- Symptom: during a real MIMO normal capture, the raw record was saved, but the
  runtime emitted no Memory proposal. The UI showed
  `CapturePipelineException: Capture pack did not emit a Memory proposal.`
- Cause: `RuntimeKernel` correctly records failed agent runs internally, but
  `CaptureOrchestrator` expected a Memory proposal after every capture. A
  transient model failure therefore broke the user-visible agent chain.
- Fix: `_CaptureAgent` now falls back to a deterministic local preview summary
  if `model.complete` throws, so Memory/Card/Insight/Todo still complete.
  `CaptureController` also clears any prior error after a successful capture.
- Review: Kimi reviewed the bugfix diff and reported no blockers for
  local-first/privacy, data loss, test coverage, or complexity.

Related hardening:

- Release/main Android manifest does not request `INTERNET`; debug/profile keep
  Flutter's development network permission.
- Xiaomi MIMO support is opt-in via debug QA dart-define.
- MIMO protocol tests cover request headers/body, multi-block text extraction,
  non-2xx, malformed JSON, empty text content, provider default behavior, and
  secret-safe exceptions.

## Automated Tests

Commands run successfully after the fix:

```sh
dart format --set-exit-if-changed apps/mobile/lib apps/mobile/test
git diff --check
flutter analyze --no-pub
flutter test --no-pub --concurrency=1
```

Flutter test result: 26 tests passed, including widget tests for tabs, capture,
blank submit, pipeline failure raw preservation, multiple captures, Memory
review accept/edit/reject, Todos source links, Plugins, Chat, local DB runtime
trace persistence, and orchestrator fallback behavior.

## Emulator Method

The Android QA used real `adb` interactions:

- `adb shell input tap` with coordinates derived from `uiautomator` XML.
- `adb shell input text` for capture bodies.
- `adb shell input swipe` to move between top capture controls, Stage metrics,
  records, and review actions.
- `uiautomator dump` after steps to verify visible UI state.
- `screencap` and `logcat` artifacts captured to `/tmp`.

The official formal run had two artifact groups because the long capture pass
completed first and a later resume script completed navigation/review after a
QA-script filename bug:

- Capture/blank evidence:
  `/tmp/widenote-android-qa-real-20260624-fix3`
- Tab/review evidence:
  `/tmp/widenote-android-qa-real-20260624-fix3-resume2`

The QA-script filename bug came from saving XML with the tab label
`首页/记录` in the filename. It did not affect app behavior.

## Emulator Results

Formal post-fix results:

| Scenario | Rounds | Result | Notes |
| --- | ---: | --- | --- |
| Normal capture | 10 | 10/10 passed | Real MIMO was used; processed, accepted Memory, and source-linked todo increased. |
| Sensitive capture | 10 | 10/10 passed | API key/token/password/doctor/medical/salary/bank/address/GPS/credential cases all went to review. |
| Blank capture | 10 | 10/10 passed | Processed count stayed at 20; no error shown. |
| Tab navigation | 10 | 10/10 passed | Repeated Home, Chat, Todos, Plugins navigation by real taps. |
| Memory review actions | 10 | 10/10 passed | Mix of accept, reject, and edit-save actions drained the review queue. |

Final verified UI metrics after all review actions:

- `processed`: 20
- `accepted`: 17
- `review`: 0
- `linked`: 22
- `has_error`: false

The 17 accepted Memories equal 10 normal auto-accepted Memories plus seven
accepted/edited sensitive review candidates. Three sensitive candidates were
rejected intentionally. The 22 linked todos equal the two seed todos plus 20
captured todos.

## Observations

- Real MIMO latency varied from about 3 seconds to about 19 seconds in the
  tested cases. The UI stayed usable and eventually returned to idle.
- One sensitive GPS/location capture produced a refusal-style model sentence in
  the review candidate. This was safe because the item remained in Memory
  Review, but it shows that real-model output quality needs review-stage UX and
  future prompt/model tuning.
- Intermediate `linked` metrics occasionally read as `0` in the script when
  only the Processing/Memory Stage cards were visible after scrolling. Final
  metrics and Todos page verification confirmed the linked todo state.
- `adb shell input text` was kept to ASCII for reliable automation. Chinese UI
  labels were still exercised through real tab and button taps.
- The debug APK contains the QA key by construction of `--dart-define`; do not
  distribute it. Production/release behavior remains offline by default.

## Logcat

`/tmp/widenote-android-qa-real-20260624-fix3-resume2/logcat.txt` was scanned
for app crashes and unhandled failures. No `FATAL EXCEPTION`, app
`E AndroidRuntime`, `Unhandled Exception`, `Capture failed`, `agent failed`,
or `XiaomiMimoModelException` entries were found for the final pass. The log
does include normal `uiautomator` process start/stop lines and emulator system
network-time warnings.

## Remaining Parity Gaps

- Implement import/restore support for MemeX-like backup structures.
- Add media capture: images, audio, speech transcription, and asset safety.
- Build real chat assistant flows over local Memory and source-linked records.
- Add provider settings UI and BYOK/local provider routing beyond QA-only MIMO.
- Add P.A.R.A., cards/facts/insights browsing, and richer cross-reference UI.
- Add custom Agent Pack authoring/runtime controls, scheduler flows, retry
  controls, and trace console depth.
- Add companion/character workflows only after privacy and permission gates are
  designed.
