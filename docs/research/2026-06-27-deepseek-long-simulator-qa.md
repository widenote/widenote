# DeepSeek Long Simulator QA

Status: completed with one provider bug fixed
Date: 2026-06-27
Scope: Android `Medium_Phone_API_35` emulator and iPhone 17 iOS simulator,
dev flavor, DeepSeek Anthropic-compatible provider, 20 capture inputs per
platform plus chat/todo/Memory/backup checks

## Summary

Both Flutter-launchable simulators passed the same long user journey after a
provider request fix:

```text
20 realistic captures
  -> source-linked runtime outputs
  -> 20 needs-review Memory candidates
  -> cards / insights / todos / traces
  -> 6 source-cited chat turns
  -> todo completion
  -> Memory page navigation
  -> safe backup export
  -> restore into a fresh database
```

No provider key was written to source, docs, screenshots, backups, or reported
logs. The live key was provided only as a transient dart-define in opt-in QA
commands and is redacted below.

## Memex Backup Reference

The attached Memex backup was inspected locally only for structure and usage
shape. No raw private record text was copied into this note or the test corpus.

Observed shape:

- 66 `workspace/Facts/**/*.md` files.
- 34 PKM markdown files across Areas, Resources, Projects, and Archives.
- 897 recorded LLM call JSON files, mostly `input` scene calls.
- LLM call models included MIMO and visual/agent model variants.

The simulator corpus was synthetic but shaped after that usage pattern:
daily facts, Chinese notes, project notes, health/lifestyle notes, errands,
preferences, long multi-paragraph context, symbols, synthetic secret-like text,
contradictory preferences, meeting notes, backup expectations, runtime
expectations, and release-gate notes.

## Bug Fixed

During the Android pass, capture 9 failed with:

```text
ModelProviderErrorKind.missingText
Anthropic-compatible response did not include text.
```

This matched the earlier MIMO reasoning-only issue: DeepSeek `deepseek-v4-flash`
can return no final text block unless thinking is explicitly disabled.

Fix:

- `AnthropicCompatibleModelProvider` now sends
  `thinking: {"type": "disabled"}` for DeepSeek-looking Anthropic-compatible
  configs and for MIMO configs.
- Generic Anthropic-compatible providers do not receive the extra field.
- Unit tests assert DeepSeek and MIMO request bodies include disabled thinking,
  while a generic versioned Anthropic-compatible endpoint does not.

## Android Result

Environment:

- Device: `sdk_gphone64_arm64`, API 35
- Serial: `emulator-5554`
- Emulator: `Medium_Phone_API_35`
- Evidence directory: `/tmp/widenote-deepseek-long-qa-android-20260627-143736`

Result:

- Passed after the provider fix.
- 20 captures persisted as raw records.
- 20 Memory candidates remained in `needs_review`.
- 20 todos existed, and one todo could be completed.
- Cards, insights, and runtime traces were produced.
- 6 chat turns produced 12 persisted messages; assistant messages were non-empty
  and source-linked.
- Safe backup declared `backup_mode=safe`, `includes_secrets=false`, excluded
  the provider key, and restored captures, chat messages, Memory candidates,
  and todos into a fresh database.
- Android crash buffer had 0 lines.
- Log scan for app fatal errors, Flutter fatal errors, SQLite exceptions,
  model provider exceptions, unhandled exceptions, and the live key was clean.

Infrastructure note:

- `flutter emulators --launch Medium_Phone_API_35` exited without leaving a
  booted emulator.
- Launching the SDK binary directly with `-no-snapshot-load -no-snapshot-save`
  booted successfully.
- The emulator logged host `socks5` proxy warnings; they did not block app
  network access after Flutter test commands cleared local proxy vars.

## iOS Result

Environment:

- Simulator: iPhone 17
- Runtime: iOS 26.5
- Simulator id: `AC67CA3B-F4D5-428C-ABBB-08F5AF83DF1D`
- Evidence directory: `/tmp/widenote-deepseek-long-qa-ios-20260627-144106`
- XcodeBuildMCP screenshot:
  `/var/folders/y0/xpyf8lh91_b3djfpxz94znc00000gn/T/screenshot_optimized_4fde8fbd-41de-49b8-84cd-02e03e04242c.jpg`

Result:

- Passed after the provider fix.
- Same 20-capture, 6-chat, todo, Memory page, safe-backup, and restore checks
  passed.
- Simulator app log scan for fatal errors, Flutter errors, SQLite exceptions,
  model provider exceptions, authorization headers, API-key headers, and the
  live key was clean.

Infrastructure note:

- XcodeBuildMCP `build_run_sim` initially failed because `ios/Pods` was absent.
- `pod install` regenerated Pods successfully; Flutter's iOS integration-test
  build then passed.
- CocoaPods emitted base-configuration warnings for the customized flavor setup,
  but they did not block the simulator build or test.

## Product Findings

### Confirmed Bug

| ID | Severity | Finding | Resolution |
| --- | --- | --- | --- |
| DS-BUG-1 | High | DeepSeek-compatible model calls could fail with `missingText` during long capture runs because the provider returned no final text block. | Fixed by disabling thinking for DeepSeek-looking and MIMO Anthropic-compatible configs. |

### Needs Product Decision

| ID | Area | Observation | User impact | Suggested decision |
| --- | --- | --- | --- | --- |
| DS-UX-1 | Memory review | DeepSeek capture output creates `needs_review` Memory candidates. Home intentionally does not show sensitive review candidates, and the current Memory page only shows active/deleted Memory. There is no visible user path in this long journey to accept or reject the review queue. | The local loop generates the right intermediate objects, but a user cannot finish the Memory acceptance step from the visible UI when model output requires review. | Add a dedicated review queue, likely on Memory page or a guarded Review page, instead of exposing sensitive candidates on Home. |
| DS-UX-2 | Long generated todo list | With 20 captures, the Todos page becomes long enough that automation needs careful scrolling to complete the first todo. | Repeated capture sessions can make triage feel heavy if every capture produces a todo. | Decide whether todo generation should be more selective, grouped, or batch-reviewable. |

## Memex Parity Read

WideNote now matches the core Memex-like loop at the phase-one boundary:

```text
raw input -> local event/runtime -> Memory candidate -> card/insight/todo
-> source-linked chat -> traces -> safe backup
```

Where WideNote is stronger for the intended local-first mobile loop:

- Raw records remain source truth and are preserved before derived output.
- Safe backup excludes provider credential values.
- Provider failures are visible instead of producing fake local AI output.
- Traces are stored and can be inspected without needing a backend.

Where Memex remains ahead or broader:

- Memex has a richer visible workspace for generated artifacts and review.
- Memex-style replay/eval evidence is broader than this single long-journey
  harness.
- Agent delegation/tool loops and broad workspace actions remain roadmap
  surfaces for WideNote.

## Validation Commands

Commands ran with proxy vars cleared and provider key redacted:

```sh
cd packages/dart/model_providers
dart test test/compatible_model_provider_test.dart
dart analyze lib/src/compatible_model_provider.dart test/compatible_model_provider_test.dart

cd apps/mobile
flutter test test/model_client_test.dart
flutter analyze integration_test/deepseek_long_user_journey_test.dart test/model_client_test.dart
flutter test integration_test/deepseek_long_user_journey_test.dart -d emulator-5554 --flavor dev --dart-define=WIDENOTE_QA_DEEPSEEK_API_KEY=<redacted> --dart-define=WIDENOTE_QA_DEEPSEEK_ENDPOINT=https://api.deepseek.com/anthropic --dart-define=WIDENOTE_QA_DEEPSEEK_MODEL=deepseek-v4-flash
flutter test integration_test/deepseek_long_user_journey_test.dart -d AC67CA3B-F4D5-428C-ABBB-08F5AF83DF1D --flavor dev --dart-define=WIDENOTE_QA_DEEPSEEK_API_KEY=<redacted> --dart-define=WIDENOTE_QA_DEEPSEEK_ENDPOINT=https://api.deepseek.com/anthropic --dart-define=WIDENOTE_QA_DEEPSEEK_MODEL=deepseek-v4-flash
```
