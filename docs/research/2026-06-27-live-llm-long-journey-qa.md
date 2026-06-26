# Live LLM Long Journey QA

Status: blocked by live provider authentication
Date: 2026-06-27
Scope: Android emulator and iOS simulator on current W7 mobile checkout, dev
flavor, transient QA MIMO model key passed by build-time dart define

## Summary

Android and iOS were both rebuilt after the QA model adapter fix that separates
capture and chat model modes. Both platform agents confirmed the app invoked the
real MIMO model client path, but the remote endpoint returned HTTP 401 on model
requests. The iOS pass also verified the same endpoint/key pair with a minimal
curl probe and received HTTP 401.

Result: the live LLM success journey did not pass. WideNote preserved raw local
captures, persisted failed chat state, avoided local template answers, and did
not leak the transient key in logs or safe backups, but Memory/cards/insights
and grounded source-cited chat answers could not be generated while the provider
rejected authentication.

No API key is stored in this document.

## Context

Related sources:

- `docs/research/2026-06-27-cross-platform-long-conversation-test-plan.md`
- `docs/decisions/0010-delegate-semantic-selection-to-models.md`
- `docs/rfcs/model-provider-settings.md`
- `docs/rfcs/memory-model.md`

The required live QA mode used:

```sh
--dart-define=WIDENOTE_QA_MIMO_API_KEY=<redacted>
```

## Android Result

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

## iOS Result

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

## Blocking Issue Not Fixed In Code

| Severity | Issue | Evidence | Next step |
| --- | --- | --- | --- |
| Blocker | Live MIMO endpoint returned HTTP 401 for the supplied transient credential on both Android and iOS. | Android and iOS evidence directories above; iOS minimal curl probe also returned HTTP 401. | Re-run the long journey with a working credential or updated endpoint/header contract. |

This is currently treated as an external provider/authentication blocker rather
than a local fallback trigger. Per ADR-0010, WideNote should surface failure and
retry/unavailable state instead of generating local model-like answers.

## Product Decision Items

The following were not changed in this PR because they are interaction/product
choices rather than narrow correctness fixes:

| ID | Area | Finding | Decision needed |
| --- | --- | --- | --- |
| UX-1 | Chat errors | Repeated provider failures produce dense retryable failure UI and can expose provider-specific exception naming. | Decide how much provider diagnostic detail should be user-visible versus tucked into traces. |
| UX-2 | QA provider status | Settings says model access is not configured even when a transient QA dart-define key is active. | Decide whether QA/dev builds should surface compile-time provider status in Settings. |
| UX-3 | Accessibility/actionability | Settings, Packs, and Timeline rows were visually actionable but not consistently exposed as tappable accessibility targets in simulator snapshots. | Decide whether to prioritize accessibility semantics before the next broad QA pass. |
| UX-4 | Media mode after gallery cancel | Counts stayed correct after gallery cancel, but iOS automation no longer saw all media controls in the snapshot. | Decide whether this needs a UX polish pass or a targeted simulator repro first. |

## Expected Limitations Confirmed

- No local template answer or smart summary is generated when the model fails.
- No local keyword/substring sensitivity classification or redaction happens in
  core for health, finance, location, or credential-like synthetic text.
- Safe backup excludes provider keys; encrypted full backup remains deferred.
- Model-derived Memory, cards, insights, todos, and chat citations are absent
  when the model provider rejects requests.

## Follow-Up Gate

Before calling the live journey accepted, rerun the full long-session script
with a credential/endpoint that returns successful model responses:

- 8-12 captures on Android and iOS.
- 10+ grounded chat turns with source citations on Android and iOS.
- Memory edit/delete/restore and todo complete/reopen after model-derived
  objects exist.
- Safe backup export and restore into an empty app state.
- Provider/key leak scan after the successful pass.
