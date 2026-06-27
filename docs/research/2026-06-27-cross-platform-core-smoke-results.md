# Cross-Platform Core Smoke Results

Status: completed core smoke; full long-session plan still open
Date: 2026-06-27
Scope: Android emulator and iOS simulator user-perspective QA against the
current W7 mobile app checkout

## Summary

The full long-session plan in
`docs/research/2026-06-27-cross-platform-long-conversation-test-plan.md` was
created and used as the shared QA script. The simulator passes were then
intentionally narrowed to a core smoke because full 8-12 capture plus 10+ chat
turn automation was taking too long in this turn.

Core outcome: Android and iOS both passed the accountless local-first loop:

```text
clean launch -> text capture -> local runtime output -> chat -> source detail
-> todo -> safe backup export -> relaunch persistence -> log scan
```

No model key was written to docs, source, fixtures, screenshots, exported
backup, or reported logs. At the time of this smoke pass, both platforms used
the old deterministic local Chat fallback, not live provider mode. That behavior
has since been superseded by ADR-0010: Chat now requires a configured model path
and falls back to retryable error state, not a local template answer.

## Android Result

Subagent: Android emulator QA

Environment:

- Device: `Medium_Phone_API_35`
- Serial: `emulator-5554`
- Package: `app.widenote.dev`
- Activity: `app.widenote.dev/app.widenote.MainActivity`
- Evidence directory: `/tmp/widenote-android-long-qa-20260627-001011`
- Live model mode: not configured; historical run used deterministic local
  fallback, now superseded by model-required Chat behavior

Passed:

- Clean install, `pm clear`, launch, Home, and Settings.
- 3 text captures persisted across force-stop/relaunch.
- Home after relaunch showed `Processing 3 processed`, `Memory 3 accepted`,
  `Cards 6 cards`, and `Insight 3 source-linked`.
- 3 historical local fallback chat turns persisted across force-stop/relaunch.
- Timeline showed Todo, Memory, Card, and Capture entries.
- Capture detail opened and showed raw text, source refs, and event metadata.
- 3 source-linked Todos appeared; completing one hid it from the open list.
- Safe backup export/save succeeded.
- Backup JSON had `backup_mode=safe`, `includes_secrets=false`, and counts
  consistent with UI.
- App pid log, crash buffer, secret-ish log scan, backup scan, and Markdown
  scan had no app crash or secret-value leak.

Android experience / product-decision findings:

| ID | Area | Observation | User impact | Suggested decision |
| --- | --- | --- | --- | --- |
| A-UX-1 | Chat fallback | Local fallback answers cite sources but are mechanical and did not obey "three bullets" formatting. | The feature is useful for grounding, but feels like a diagnostic assistant rather than a polished conversation. | Resolved by ADR-0010 and code change: no production local template answer; Chat requires a configured model and otherwise shows retryable failure. |
| A-UX-2 | Draft/back behavior | During one text-entry flow, Android Back returned to launcher and the unsubmitted draft was lost. | A user can lose a thought before capture, which conflicts with low-friction capture expectations. | Fixed: Capture Console text draft now persists locally and clears after submit. |
| A-RISK-1 | Chinese input automation | `adb shell input text` could not enter real Chinese and hit Android shell input instability. | Automated QA did not prove real Chinese IME entry on Android in this pass. | Run a manual or IME-driven Chinese capture pass before release. |

No Android functional bug was confirmed or fixed in this pass.

## iOS Result

Subagent: iOS simulator QA

Environment:

- Simulator: iPhone 17
- Runtime: iOS 26.5
- Simulator id: `AC67CA3B-F4D5-428C-ABBB-08F5AF83DF1D`
- Bundle id: `app.widenote.dev`
- Evidence directory: `/tmp/widenote-ios-long-qa-20260627-001049`
- Live model mode: historical deterministic local fallback, now superseded by
  model-required Chat behavior

Passed:

- Clean install/launch, Home, and Settings.
- 6 captures processed locally.
- Relaunch still showed `Processing 6 processed` and `Memory 6 accepted`.
- DB terminal state observed by subagent: 6 captures, 6 Memory, 12 cards,
  3 insights, 6 todos, and 90 traces.
- 3 chat turns persisted: 1 session and 6 messages after relaunch.
- Timeline -> Card Detail -> Open source -> Capture Detail showed raw text,
  source refs, and event metadata.
- Todos showed 6 source-linked items; completing one hid it by default and DB
  showed 1 completed / 5 open.
- Safe backup export succeeded with `backup_mode=safe`,
  `includes_secrets=false`, and zero provider configs.
- Log scan found no app crash, Flutter fatal, SQLiteException, authorization
  header, or key leak. Only iOS simulator WebKit/WebCore accessibility duplicate
  class system noise appeared.

Functional bug found:

| ID | Severity | Repro | Evidence | Fixed? | Test added |
| --- | --- | --- | --- | --- | --- |
| I-BUG-1 | Medium | In chat, questions like "What follow-up tasks should I do?" and "Which source mentioned LIN?" could select unrelated QA sources ahead of the clearly relevant Todo/source. | iOS subagent report from `/tmp/widenote-ios-long-qa-20260627-001049`. | Superseded by ADR-0010. The local keyword-ranking fix was removed; local code now preserves Context Packet order and delegates semantic selection/answering to a configured model path. | Yes. `apps/mobile/test/chat_controller_test.dart` now covers query-independent selector behavior and model failure fallback-to-error. |

iOS experience / product-decision findings:

| ID | Area | Observation | User impact | Suggested decision |
| --- | --- | --- | --- | --- |
| I-UX-1 | Chat accessibility | Chat answer, sources, and history appeared as a very long accessibility text block. | VoiceOver and automation users may find source inspection noisy even though citations exist. | Split message body, source header, and source chips into cleaner semantic nodes. |
| I-UX-2 | List accessibility | Packs/Timeline clickable rows were not exposed as button targets in the iOS snapshot and required coordinate/text-area taps. | VoiceOver discoverability and automation stability are weaker than the visual UI suggests. | Mark actionable rows with explicit semantic button/link roles. |

## Code Fix

Current follow-up fix changed files:

- `apps/mobile/lib/features/chat/application/chat_context.dart`
- `apps/mobile/lib/features/chat/application/chat_assistant.dart`
- `apps/mobile/lib/features/chat/application/chat_controller.dart`
- `apps/mobile/lib/app/model_client.dart`
- `apps/mobile/lib/features/capture/application/capture_draft_repository.dart`
- `apps/mobile/lib/features/capture/presentation/home_page.dart`
- `apps/mobile/test/chat_controller_test.dart`
- `apps/mobile/test/chat_page_test.dart`
- `apps/mobile/test/capture_console_widget_test.dart`

Behavioral change:

- Local Chat selection no longer inspects the question or applies keyword
  ranking. It preserves Context Packet disclosure order and applies only a
  prompt-budget limit.
- Chat uses a dedicated model client path without local summary fallback.
- Missing model, model failure, or empty model response marks the message failed
  and keeps retry available.
- Capture Console text drafts persist locally and clear after submit.

Validation:

```sh
cd apps/mobile
env -u ws_proxy -u wss_proxy NO_PROXY=localhost,127.0.0.1,::1 no_proxy=localhost,127.0.0.1,::1 flutter test test/chat_controller_test.dart
env -u ws_proxy -u wss_proxy NO_PROXY=localhost,127.0.0.1,::1 no_proxy=localhost,127.0.0.1,::1 flutter analyze lib/features/chat/application/chat_context.dart test/chat_controller_test.dart
git diff --check
```

Results:

- `test/chat_controller_test.dart`, `test/chat_page_test.dart`,
  `test/capture_console_widget_test.dart`, `test/model_client_test.dart`, and
  `test/model_provider_settings_test.dart`: targeted tests passed.
- Targeted Flutter analyze: no issues found.
- `git diff --check`: passed.

## Still Open From The Full Plan

The following were not completed in this core smoke:

- 8-12 capture corpus on each platform.
- 10+ chat-turn long conversation on each platform.
- Memory edit/delete/restore on simulators.
- Permission revoke simulator path in this pass.
- Media permission denied/cancelled paths in this pass.
- Provider UI live connection.
- Safe backup restore into an empty app state on both platforms.
- Real Android Chinese IME input.

## Decision Needed

1. Chat fallback: resolved by ADR-0010 and implementation. Production Chat no
   longer uses local template answers.
2. Capture draft safety: fixed by persistent app-local text drafts.
3. Accessibility semantics: prioritize semantic row/button/source-chip cleanup
   before the next broad simulator QA pass.
4. Long-session gate: schedule a dedicated uninterrupted QA run to finish the
   full long-session plan rather than treating this core smoke as full
   acceptance.
