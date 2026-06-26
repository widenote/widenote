# Cross-Platform Long Conversation Test Plan

Status: active QA plan
Date: 2026-06-27
Scope: current W7 phase-one mobile app on Android emulator and iOS simulator

## Context

This plan extends the existing W7 integration evidence with a user-perspective
long-session pass on both mobile platforms.

Current implementation boundary:

- Core app is Flutter mobile, local-first, and accountless.
- Local truth is hand-written `sqlite3` in `packages/dart/local_db`; Drift is
  still the accepted long-term target, not the current generated layer.
- Raw captures and source media are canonical user records. AI/model/runtime
  output must remain derived and source-linked.
- Safe backup is the implemented restore path and must not include provider
  API key values. Secret-bearing encrypted full backup is intentionally
  unavailable.
- Chat persists local sessions and should answer from Context Packets with
  source citations through a configured model-backed path. Per ADR-0010, Chat
  must not use deterministic local template answers when the model is missing or
  fails; it should show a model-required/model-unavailable retry state.
- Core must not use user-content keyword, regex, substring, or stop-word
  heuristics to infer, classify, mask, rank, route, or answer. In this QA pass,
  do not expect core keyword redaction or local safety classification unless a
  configured model, plugin, or Agent Pack explicitly provides it.

Related decision and QA sources:

- `docs/decisions/index.md`
- `docs/decisions/0002-use-flutter-and-drift-for-client.md`
- `docs/decisions/0003-build-agent-runtime-kernel.md`
- `docs/decisions/0005-use-memory-first-instead-of-pkm-core.md`
- `docs/decisions/0007-defer-cloud-sync-from-core-phase-one.md`
- `docs/decisions/0008-use-dev-and-prod-mobile-flavors.md`
- `docs/decisions/0009-use-object-truth-and-context-packets.md`
- `docs/decisions/0010-delegate-semantic-selection-to-models.md`
- `docs/rfcs/phase-one-product-scope.md`
- `docs/rfcs/phase-one-umbrella-technical-plan.md`
- `docs/rfcs/memory-model.md`
- `docs/rfcs/model-provider-settings.md`
- `docs/rfcs/agent-pack-schema.md`
- `docs/rfcs/mobile-entry-closure.md`
- `docs/rfcs/mobile-visual-style.md`
- `docs/research/2026-06-26-w7-current-integration-state.md`
- `docs/research/2026-06-26-w7-integration-qa.md`
- `docs/research/2026-06-26-phase-one-acceptance-matrix.md`
- `docs/research/2026-06-27-live-llm-long-journey-qa.md`

Automated implementation:

- `apps/mobile/integration_test/live_llm_long_journey_test.dart` implements the
  core live model-backed journey as an opt-in integration test.
- The script is skipped unless
  `--dart-define=WIDENOTE_QA_MIMO_API_KEY=<redacted>` is provided.
- On 2026-06-27 it passed on both the iPhone 17 iOS simulator and
  `Medium_Phone_API_35` Android emulator with real MIMO responses.

## Goals

1. Prove the current app is complete enough for the phase-one local loop from a
   user perspective, not only through unit/widget tests.
2. Re-run simulator/emulator validation on the current checkout for both
   Android and iOS.
3. Exercise a longer conversation and capture session so persistence, source
   context, citation quality, model-required/error behavior, and UI ergonomics
   are visible under repeated use.
4. Fix clear functional bugs found during QA when the fix is bounded and does
   not require a new product decision.
5. Separate product/interaction concerns from code bugs so the product owner
   can decide design follow-ups.

## Non-Goals

- Do not test with real private user records, real personal photos, real audio,
  or local production databases.
- Do not commit, document, screenshot, or log any API key or secret.
- Do not commit or expose live model-provider credentials. A full Chat answer
  pass should use the supplied transient QA model key when available. If the
  remote endpoint rate-limits or fails, the app must recover through a visible
  model-unavailable/retry state and the report must say so.
- Do not implement new UX decisions such as encrypted full backup, companion
  characters, app lock, broad file import, cloud sync, or community script
  packs during this QA pass.

## Secret Handling

The model credential supplied in the conversation may be used only as a
transient runtime value.

Rules:

- Prefer environment variables or `--dart-define` values injected directly at
  build/run time.
- Do not create a key file unless absolutely necessary; if one is used, place it
  under `/tmp`, delete it immediately after use, and do not mention its content.
- Do not paste the key into docs, test fixtures, shell transcripts, issue text,
  PR text, screenshots, exported backup JSON, or log snippets.
- If the key is entered through the mobile UI for provider-settings testing,
  clear app data at the end of the pass and verify safe backup excludes the key.
- Redact endpoint credentials and request headers from all reports.

## Shared Acceptance Gates

Each platform subagent must classify every finding as one of:

- `Bug`: user-visible malfunction, crash, data loss, broken navigation, broken
  persistence, wrong source link, missing permission boundary, key leak, or
  app failure to recover.
- `Experience issue`: confusing copy, awkward navigation, weak feedback, slow
  but recoverable model error, poor hierarchy, hard-to-discover action, or
  visual polish concern.
- `Expected limitation`: behavior explicitly deferred by ADR/RFC/W7 docs.

The app passes only if:

- It launches from a clean install and works without account setup.
- Text capture creates a raw record before derived output.
- Repeated captures create source-linked Memory, cards, insights, todos, trace
  evidence, and timeline entries without overwriting raw input.
- With a configured model, Chat can answer from local records/Memory/todos and
  shows usable source citations. Without a configured/available model, Chat must
  show a clear model-required/model-unavailable state and retry path.
- A long chat session persists across tab switches and app restart/relaunch.
- Source chips/backlinks navigate to the relevant record/detail where
  implemented.
- Todo complete/reopen persists and does not delete source evidence.
- Memory edit/delete/restore preserves provenance and revision/tombstone
  semantics.
- Permission revoke blocks future Pack work while preserving raw capture.
- Settings exposes privacy, permissions, providers, backup, and traces from the
  top-right control hub.
- Safe backup/export succeeds, excludes provider keys, and restore leaves the
  app usable.
- Camera/gallery/voice denied/cancelled paths do not create phantom records or
  attachments.
- Logs contain no app crash, Flutter fatal, SQLite exception, key, or raw secret
  leak.

## Long Session Script

Run this script separately on Android and iOS. Use synthetic data only.

### Round 0: Clean Start

1. Install or launch the dev flavor.
2. Clear app data for a clean-new-user pass.
3. Confirm the first screen is Home with quick capture and no login gate.
4. Open Settings from the Home header and return to Home.
5. Record locale, platform, app package/bundle id, and build command.

### Round 1: Capture Corpus

Create 8 to 12 captures from Home. Wait after each capture until the UI returns
to ready or a clear review/model-error state appears.

Use these themes:

| Case | Input shape | Expected user-visible outcome |
| --- | --- | --- |
| A | Short project note | Record, Memory/card/insight, todo if applicable |
| B | Chinese note | Localized text remains readable; no encoding issue |
| C | English note | Search/chat can cite it later |
| D | Explicit follow-up task | Todo appears with source link |
| E | Long multi-paragraph note | UI remains stable; chat can retrieve summary |
| F | Punctuation/symbols | Capture does not break parser or input field |
| G | Health/finance/location-like note | Core does not locally classify by keywords; any review/safety behavior must come from model/plugin metadata or be recorded as a product gap |
| H | Credential-like synthetic secret such as `sk-demo-secret` | Core does not locally mask/classify by keywords; verify no app crash/key persistence leak, and record any product gap separately |
| I | Contradictory project preference | Conflict/review behavior or clear limitation |
| J | Empty submit attempt | User sees non-destructive validation feedback |

Track:

- Time from submit to ready/review/model-error state.
- Home counters.
- Number of captures, Memory items/candidates, cards, insights, todos, traces.
- Whether raw input remains visible in Timeline/detail.
- Any copy that is confusing or too developer-facing.

### Round 2: Long Conversation

After the capture corpus exists, ask at least 10 chat turns in one session:

1. "What did I say about the project note?"
2. "Summarize today's records in three bullets."
3. "What follow-up tasks should I do?"
4. "Which source mentioned Lin or the project collaborator?"
5. "Do I have anything sensitive that should not become Memory?"
6. "Compare the Chinese and English notes."
7. "What changed between the first and latest project preference?"
8. "Open or inspect the source for your answer." Then tap a citation chip.
9. "What do you not know from my local records?"
10. "Summarize the entire conversation so far."

Track:

- Whether the assistant cites local sources.
- Whether answers are grounded or hallucinated.
- Whether the assistant exposes sensitive synthetic content in a surprising
  place.
- Whether session title/history remains usable with many turns.
- Whether the composer stays reachable with keyboard, long messages, and
  scrolling.
- Whether tab switching and app relaunch preserve messages.
- Whether live provider was used, fell back, or was not configured.

### Round 3: Navigation and Object Surfaces

1. Open Timeline and use search for at least two corpus terms.
2. Open one raw record detail and one card detail.
3. Open Todos, complete a generated todo, verify it hides by default, then
   reopen or verify completed state where available.
4. Open Memory, edit one low-risk Memory, tombstone delete it, then restore it.
5. Open Daily Recap and verify counts/source labels match the local corpus.
6. Open Pack Library and Permission Gate.
7. Revoke `pack.default / model.complete`, submit one new capture, and verify
   raw capture persists while future derived Pack output is blocked.
8. Restore the permission if needed for later checks.

### Round 4: Provider and Backup

1. Open Model Providers.
2. If using transient QA model define, record that runtime model access is
   active through the QA path; do not enter the key in UI unless needed.
3. If UI provider setup is tested, add a Xiaomi MIMO or Anthropic-compatible
   provider with the supplied endpoint/key, set it as default, and run the
   connection test only in live-provider mode.
4. Confirm provider rows mask/avoid key display.
5. Export safe backup JSON.
6. Confirm backup UI says provider keys are omitted and encrypted full backup
   is unavailable.
7. Search the visible/exported backup text for obvious secret leakage without
   printing the key.
8. Restore safe backup into an empty app state if practical for the platform
   pass; verify records, chat, todos, Memory, provider metadata, permissions,
   and trace evidence are usable.

### Round 5: Media Permission Boundaries

1. Switch to voice mode, deny or cancel microphone permission, and verify no
   phantom record/attachment is created.
2. Switch to media mode, deny or cancel camera/gallery, and verify no phantom
   record/attachment is created.
3. If permission has already been granted on the simulator, use platform
   settings reset or document that only the already-granted path was observed.

## Android Subagent Assignment

Use `test-android-apps:android-emulator-qa`.

Primary environment:

- Emulator: `Medium_Phone_API_35` when available.
- Serial: discover with `adb devices`.
- Package: `app.widenote.dev`.
- Activity: resolve with `adb shell cmd package resolve-activity --brief`.

Suggested commands:

```sh
cd apps/mobile
env -u ws_proxy -u wss_proxy \
  NO_PROXY=localhost,127.0.0.1,::1 \
  no_proxy=localhost,127.0.0.1,::1 \
  flutter build apk --debug --flavor dev \
  --dart-define=WIDENOTE_QA_MIMO_API_KEY="$WIDENOTE_QA_MIMO_API_KEY"

adb -s <serial> install -r build/app/outputs/flutter-apk/app-dev-debug.apk
adb -s <serial> shell pm clear app.widenote.dev
adb -s <serial> shell logcat -c
adb -s <serial> shell am start -n app.widenote.dev/<resolved-activity>
```

Interaction rules:

- Use UIAutomator XML to compute tap coordinates. Do not rely on screenshots for
  click targets.
- Save per-step UI dumps, compact summaries, screenshots, and logcat under a
  platform-specific `/tmp/widenote-android-long-qa-*` directory.
- Android emulator ownership is serialized. Do not run another Android QA lane
  at the same time.
- At the end, run `adb logcat -b crash -d` and a targeted app log scan for
  `FATAL`, `Unhandled`, `SQLiteException`, `E/flutter`, `CapturePipeline`,
  `ContextPacket`, and the secret-leak sentinel without printing the key.

## iOS Subagent Assignment

Use `build-ios-apps:ios-debugger-agent` and XcodeBuildMCP where possible.

Primary environment:

- Workspace: `apps/mobile/ios/Runner.xcworkspace`
- Scheme: `dev`
- Configuration: `Debug-dev`
- Bundle id: `app.widenote.dev`
- Simulator: booted iPhone simulator, preferably the same family used in recent
  W7 QA if available.

Required first steps:

1. Call XcodeBuildMCP `session_show_defaults`.
2. If defaults are missing or wrong, discover/set:
   - `workspacePath`: absolute `apps/mobile/ios/Runner.xcworkspace`
   - `scheme`: `dev`
   - `configuration`: `Debug-dev`
   - booted simulator id
   - `bundleId`: `app.widenote.dev`
3. Build/run, then verify launch with screenshot or UI snapshot.

Live model note:

- If XcodeBuildMCP cannot inject Flutter `--dart-define` cleanly, configure the
  provider through the mobile UI or record the Chat portion as
  model-required/model-unavailable. Do not substitute a local template answer.
- If using UI provider setup instead, clear app data after the pass so the key
  does not remain in simulator storage.

Interaction rules:

- Use XcodeBuildMCP UI snapshots and element refs when available.
- Capture screenshots and log paths.
- Verify app stop/relaunch preserves local state.
- Scan app/runtime logs for crash, SQLite, Flutter, Context Packet, and
  secret-leak indicators without printing the key.

## Functional Bug Fix Policy

Fix immediately when all are true:

- The issue is reproducible in the current checkout.
- The expected behavior is already covered by ADR/RFC/W7 docs.
- The fix is local and does not need a new product decision.
- A focused unit/widget/integration test can be added or updated.

Examples:

- Broken navigation/back behavior.
- Chat not persisting after restart.
- Todo source backlink opens the wrong object.
- Safe backup exposing a provider key.
- Permission revoke not blocking future Pack work.
- Phantom capture after denied permission.
- Crash or uncaught exception in normal flow.

Do not fix without product decision:

- Renaming primary tabs or moving major navigation.
- Changing the default Memory auto-accept policy.
- Introducing encrypted full backup.
- Changing whether sensitive raw captures should be hidden by default.
- Adding onboarding, account, cloud sync, companion, or app-lock behavior.
- Redesigning the capture surface beyond obvious bug-level layout fixes.

## Report Template

Each subagent must report:

```text
Platform:
Build/install/run commands:
Device/simulator:
Live model mode: used / model-required / failed with redacted reason
Evidence directory:

Functional status:
- Passed flows:
- Failed flows:
- Logs/crashes:

Long conversation summary:
- Capture rounds:
- Chat turns:
- Grounding/citation quality:
- Persistence/relaunch result:
- Latency/model-error observations:

Bugs:
| ID | Severity | Repro | Evidence | Fixed? | Test added |

Experience issues for product decision:
| ID | Area | Observation | User impact | Suggested decision |

Expected limitations:
| Area | Why expected |

Changed files, if any:
Tests run:
Skipped checks and residual risk:
```

## Coordinator Final Gate

After both subagents report, the coordinator should:

1. Review any patches they produced.
2. Re-run focused tests for changed files.
3. Re-run `git diff --check`.
4. Update the relevant QA report or create a follow-up issue list.
5. Present confirmed bugs, fixed bugs, residual risks, and product/experience
   decisions separately.
