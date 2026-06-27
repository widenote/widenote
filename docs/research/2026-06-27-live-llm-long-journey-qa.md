# Live LLM Long Journey QA

Status: passed on Android and iOS with live MIMO model
Date: 2026-06-27
Scope: Android emulator and iOS simulator on current W7 mobile checkout, dev
flavor, transient QA MIMO model key passed to the opt-in integration-test
harness by dart define

## Summary

Android and iOS both passed the scripted long-session journey with a real MIMO
model credential after a new credential batch was supplied. The final passing
journey covers eight captures, model-derived Memory/todos/cards/insights, ten
source-linked chat turns, todo completion, Memory navigation, safe backup export,
and restore into an empty in-memory database.

Earlier manual/subagent runs are retained below as historical evidence because
they found useful product and infrastructure issues, but their HTTP 401 provider
blocker is no longer current.

No API key is stored in this document.

## Context

Related sources:

- `docs/research/2026-06-27-cross-platform-long-conversation-test-plan.md`
- `docs/decisions/0010-delegate-semantic-selection-to-models.md`
- `docs/rfcs/model-provider-settings.md`
- `docs/rfcs/memory-model.md`

The required live QA mode used a test-process provider override:

```sh
--dart-define=WIDENOTE_QA_MIMO_API_KEY=<redacted>
```

This define is not product runtime configuration. App bootstrap and Settings
must read saved provider settings only; the live QA script injects
`XiaomiMimoModelClient` through Riverpod overrides.

## Latest Successful Live Rerun

Credential preflight:

- 20 transient candidate credentials were probed with a minimal
  Anthropic-compatible MIMO request.
- 8 candidates authenticated with HTTP 200.
- 12 candidates returned HTTP 429 during the probe window.
- No credential value was written to repository files, reports, screenshots, or
  backup exports.

Live model compatibility issue found and fixed:

- `mimo-v2.5-pro` may return a `thinking` block without a final `text` block
  when reasoning is enabled or when the output cap is consumed by reasoning.
- WideNote still treats a no-text model response as an error; it does not use
  thinking content as a user-visible Memory/chat answer.
- `XiaomiMimoModelClient` now sends
  `thinking: {"type": "disabled"}` on the MIMO Anthropic-compatible request.
  This preserves the existing capture/chat token budgets while avoiding
  reasoning-only responses and reducing avoidable BYOK token usage.

Scripted test added:

```sh
cd apps/mobile
env -u ws_proxy -u wss_proxy \
  NO_PROXY=localhost,127.0.0.1,::1 \
  no_proxy=localhost,127.0.0.1,::1 \
  flutter test integration_test/live_llm_long_journey_test.dart \
  -d <device-id> --flavor dev \
  --dart-define=WIDENOTE_QA_MIMO_API_KEY=<redacted>
```

Assertions covered by the passing script:

- 8 synthetic captures persist as raw records.
- 8 active Memory items are accepted from model review.
- 8 todos exist and one open todo can be completed.
- Cards and insights are generated.
- A runtime trace named `runtime.model.completed` exists.
- 10 chat turns produce 20 persisted chat messages in one session.
- Every assistant message is non-empty and has source refs.
- Memory page opens and active Memory remains visible.
- Safe backup declares `backup_mode=safe`, declares `includes_secrets=false`,
  excludes the transient model key, and restores captures, chat messages, and
  Memory counts into a fresh database.

Platform results:

| Platform | Device | Result | Evidence |
| --- | --- | --- | --- |
| iOS | iPhone 17 simulator, iOS 26.5 | Passed | `02:02 +1: All tests passed!` |
| Android | `sdk_gphone64_arm64`, API 35 emulator | Passed | `01:46 +1: All tests passed!` |

Android infrastructure note:

- `Medium_Phone_API_35` booted successfully when launched directly with emulator
  verbose output. The host environment produced non-fatal emulator warnings about
  an unsupported `socks5` proxy URI, but the app could still reach the live MIMO
  endpoint and complete the journey.

## Earlier Blocked Android Result

Subagent: Android emulator QA

Environment:

- Device: `Medium_Phone_API_35`
- Serial: `emulator-5554`
- Package: `app.widenote.dev`
- Activity: `app.widenote.dev/app.widenote.MainActivity`
- Evidence directory: `/tmp/widenote-android-live-long-qa-20260627-031223-postfix`

Completed:

- Clean install, `pm clear`, launch, Home, and Settings.
- Transient QA model key passed into the app build.
- Real `XiaomiMimoModelClient` path invoked.
- Raw local capture persistence under provider failure.
- One failed chat turn persisted across force-stop/relaunch with retry UI.
- Timeline capture detail showed raw text, source refs, and event metadata.
- Safe backup JSON/Markdown export succeeded and did not contain the key.
- Camera-denied path created no phantom record or attachment.
- Crash/log scans found no app crash, Flutter fatal, SQLite exception, or key
  leak.

Blocked or incomplete:

- Provider returned HTTP 401, so live capture-derived Memory/cards/insights and
  long source-cited chat answers could not be generated.
- Only 2 records were verified as persisted during the blocked run.
- Todos/Memory/cards/insights stayed at zero because model-backed derivation
  failed as required by ADR-0010.

Final observed counts:

| Object | Count |
| --- | ---: |
| captures | 2 |
| memory items / candidates | 0 / 0 |
| cards / insights / todos | 0 / 0 / 0 |
| chat sessions / messages | 1 / 1 |
| runtime runs / tasks / traces | 6 / 4 / 36 |
| provider configs | 0 |

## Earlier Blocked iOS Result

Subagent: iOS simulator QA

Environment:

- Simulator: iPhone 17, iOS 26.5
- Bundle id: `app.widenote.dev`
- Evidence directory: `/tmp/widenote-ios-live-long-qa-20260627-030842`

Completed:

- Clean install/launch and accountless Home.
- Settings reachable.
- 9 synthetic ASCII captures.
- Empty submit validation.
- 10 chat turns attempted.
- Tab switch and relaunch persistence.
- Timeline, Todos, Memory, Daily Recap, Settings, and Packs surfaces opened.
- Microphone denied and gallery cancel paths created no phantom record.
- App data, runtime/os log, and safe evidence scans found no real key leak.
- No Flutter fatal, app crash, or SQLite exception.

Blocked or incomplete:

- Provider returned HTTP 401 for capture and chat.
- All 10 chat turns failed; no assistant messages or citations were generated.
- Memory edit/delete/restore and todo complete/reopen could not be fully
  exercised because no model-derived Memory or todos existed.
- Deep provider/backup/traces navigation, permission revoke, camera cancel, and
  Chinese input were not fully completed in this run.

Final observed counts:

| Object | Count |
| --- | ---: |
| captures | 9 |
| memory items | 0 |
| cards / insights / todos | 0 / 0 / 0 |
| chat sessions / messages | 1 / 10 |
| trace events | 162 |
| runtime runs | 27 |
| provider configs | 0 |

Runtime evidence:

- `pack.default / agent.capture_loop`: failed with
  `XiaomiMimoModelException` HTTP 401.
- `pack.todo / agent.todo_loop`: succeeded, but produced no todos in this
  provider-failure journey.

## Bugs Fixed In This Follow-Up

### MIMO reasoning-only responses broke live capture/chat

The successful live rerun first exposed intermittent
`MIMO response did not contain text` failures. Direct provider probes showed the
MIMO Anthropic-compatible endpoint could return only `thinking` content under
the previous request shape. WideNote should not treat reasoning content as a
user-visible answer, so the fix is to request final text directly rather than
fallback to thinking.

Fix:

- `XiaomiMimoModelClient` sends `thinking: {"type": "disabled"}`.
- Existing capture and chat token budgets remain at 128 and 512 respectively.
- Unit tests assert the request includes the disabled-thinking directive and
  still rejects responses without final text.

### QA model adapter mixed capture and chat instructions

Before the fix, `XiaomiMimoModelClient` wrapped every request with a QA capture
instruction that asked the model to return one Memory sentence and capped output
at 128 tokens. This made live Chat unable to exercise a realistic source-cited
conversation even when the provider works.

Fix:

- Capture mode keeps a concise Memory-summary instruction and 128 token budget.
- Chat mode is selected from structured request context
  `chat_mode=source_cited_local_context`, keeps the chat prompt intact, asks for
  source citations, and uses a 512 token budget.
- The fix does not inspect user natural-language content and does not add local
  keyword rules.

### iOS smart input could rewrite literal raw text

The iOS pass observed a credential-like synthetic token being altered by input
smart punctuation/autocorrect before persistence. Raw capture fidelity is a
durable product constraint, so capture and chat text fields now disable
autocorrect, suggestions, smart dashes, and smart quotes.

Fix:

- `quick-capture-field` disables autocorrect, suggestions, smart dashes, and
  smart quotes.
- `chat-input-field` disables the same smart rewriting behavior.
- Widget tests assert these input settings.

## Resolved Authentication Blocker

Earlier Android and iOS runs returned HTTP 401 for the first supplied transient
credential. That was treated as an external provider/authentication blocker, not
as a reason to generate local fallback answers. Per ADR-0010, WideNote surfaced
failure/retry state instead of producing local model-like output.

The later credential batch resolved this blocker: multiple candidates
authenticated, and both Android and iOS completed the live model-backed journey.

### Follow-Up Authentication Probe

A post-PR probe retried a minimal Anthropic-compatible request without writing
the credential to repository files. The probe varied endpoint path, model id,
and auth header shape:

| Endpoint | Model | Auth header shape | Result |
| --- | --- | --- | --- |
| `/anthropic/v1/messages` | `mimo-v2.5-pro` | `x-api-key` | HTTP 401 |
| `/anthropic/v1/messages` | `mimo-v2.5-pro` | `Authorization: Bearer` | HTTP 401 |
| `/anthropic/v1/messages` | `mimo-v2.5-pro` | both headers | HTTP 401 |
| `/anthropic/v1/messages` | `claude-3-5-sonnet-20241022` | `x-api-key` | HTTP 401 |
| `/anthropic/v1/messages` | `claude-3-5-sonnet-20241022` | `Authorization: Bearer` | HTTP 401 |
| `/anthropic/v1/messages` | `claude-3-5-sonnet-20241022` | both headers | HTTP 401 |
| `/v1/messages` | both tested models | all tested header shapes | HTTP 404 |

This reduced the likelihood that the earlier blocker was caused by the adapter's
header choice or default model id. The later successful rerun confirmed the
adapter works with authenticated credentials after the MIMO thinking directive
fix.

## Product Decision Updates

The following follow-ups were decided after the QA report and are now reflected
in code/tests/docs:

| ID | Area | Finding | Decision / implementation |
| --- | --- | --- | --- |
| UX-1 | Chat errors and diagnostics | Repeated provider failures produced dense retryable failure UI and could expose provider-specific exception naming. | User-visible errors stay concise by default. Provider detail is recorded as local log-center trace metadata for troubleshooting. |
| UX-2 | QA provider status | Settings said model access was not configured even when a transient QA dart-define key was active. | Correct behavior: QA dart-defines are test-only injection inputs, not product provider state. Settings displays saved provider configuration only. |
| UX-3 | Accessibility/actionability | Settings, Packs, and Timeline rows were visually actionable but not consistently exposed as tappable accessibility targets in simulator snapshots. | Implement tappable button semantics for these rows and cover them with widget tests. |
| UX-4 | Media mode after gallery cancel | Counts stayed correct after gallery cancel, but iOS automation no longer saw all media controls in the snapshot. | Keep the user in Media mode after cancel and cover visible Camera/Gallery controls with a widget test. |

## Expected Limitations Confirmed

- No local template answer or smart summary is generated when the model fails.
- No local keyword/substring sensitivity classification or redaction happens in
  core for health, finance, location, or credential-like synthetic text.
- Safe backup excludes provider keys; encrypted full backup remains deferred.
- Model-derived Memory, cards, insights, todos, and chat citations are absent
  when the model provider rejects requests.

## Follow-Up Regression Gate

The live journey is accepted for this PR. Routine UI/product PRs do not require
real-LLM reruns every time. Keep the scripted long-session test as an opt-in
regression gate for Agent/runtime/model-provider changes or when a change could
alter model-derived objects, retrieval context, traces, or source provenance.
When a working transient credential is available, the gate should cover:

- 8-12 captures on Android and iOS.
- 10+ grounded chat turns with source citations on Android and iOS.
- Memory edit/delete/restore and todo complete/reopen after model-derived
  objects exist. The current scripted pass covers Memory visibility and todo
  completion; edit/delete/restore remain useful manual follow-ups.
- Safe backup export and restore into an empty app state.
- Provider/key leak scan after the successful pass.
