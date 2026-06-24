# Android Follow-up QA - MemeX Parity Slice

Date: 2026-06-24

Scope: follow-up validation after the provider runtime bridge, provider-backed
chat bridge, Markdown backup projection, and real trace console replaced the
remaining fake/placeholder surfaces found in the second MemeX parity audit.

## Environment

- Device: Android emulator `emulator-5554`
- Package: `app.widenote.widenote_mobile`
- Build: debug APK from `apps/mobile`
- Model path: real Xiaomi MiMo key supplied through a temporary
  `--dart-define-from-file`; the temporary key file was deleted after QA.
- Evidence directory: `/tmp/widenote-android-followup-qa`

## Real Interaction Coverage

All flows below used `adb shell input tap` / text input and UIAutomator dumps
against the running emulator.

### Capture and Agent Runtime

10 capture rounds were executed from the Home tab. Cases covered provider
bridge text, backup Markdown export, trace console, chat citation wording,
urgent todo generation, health/finance/location sensitive notes, a long note,
and symbol/punctuation input.

Observed completion times:

| Case | Result | Seconds |
| --- | --- | ---: |
| 1 | ready | 11.7 |
| 2 | ready | 51.4 |
| 3 | ready | 50.8 |
| 4 | ready | 55.3 |
| 5 | ready | 15.7 |
| 6 | ready | 55.7 |
| 7 | ready | 51.5 |
| 8 | ready | 50.8 |
| 9 | ready | 15.9 |
| 10 | ready | 55.3 |

Database counts after capture and chat:

| Table | Count |
| --- | ---: |
| captures | 10 |
| memory_candidates | 10 |
| cards | 10 |
| insights | 3 |
| todos | 10 |
| trace_events | 110 |
| chat_sessions | 1 |
| chat_messages | 20 |
| model_provider_configs | 0 |

Runtime event log counts:

| Event | Count |
| --- | ---: |
| wn.capture.created | 10 |
| wn.card.created | 10 |
| wn.insight.created | 10 |
| wn.memory.proposed | 10 |
| wn.todo.suggested | 10 |

Trace event counts:

| Trace name | Count |
| --- | ---: |
| runtime.event.appended | 10 |
| runtime.handler.output | 40 |
| runtime.run.completed | 20 |
| runtime.run.started | 20 |
| runtime.task.created | 20 |

Pack / agent attribution:

| Field | Count |
| --- | ---: |
| pack.default | 60 |
| pack.todo | 40 |
| agent.capture_loop | 60 |
| agent.todo_loop | 40 |

Risk surfaced: 9 of 10 `wn.memory.proposed` events recorded
`model_fallback=true`. This means the real model path was exercised and the app
recovered correctly, but the live MiMo request path is still too latency-prone
for a polished default UX without better timeout, retry, and progress design.

### Chat

10 chat rounds were executed from the Chat tab after the capture corpus existed.
All questions returned to the ready state and persisted as one user message plus
one assistant message.

| Case | Prompt focus | Result | Seconds |
| --- | --- | --- | ---: |
| 1 | provider bridge | ready | 10.8 |
| 2 | Markdown backup | ready | 45.8 |
| 3 | trace console record | ready | 7.4 |
| 4 | local todos | ready | 45.7 |
| 5 | urgent release checklist | ready | 11.5 |
| 6 | sensitive notes | ready | 50.7 |
| 7 | memory review | ready | 46.1 |
| 8 | chat citations | ready | 10.9 |
| 9 | long QA09 note | ready | 45.8 |
| 10 | summarize all QA records | ready | 11.5 |

Persisted chat counts:

| Role | Count |
| --- | ---: |
| user | 10 |
| assistant | 10 |

### Trace Console

The Packs tab showed the real trace summary after capture/chat:

- Trace events: 110
- Runs: 20
- Warnings: 0

Opening Trace Console showed the runtime summary and event list with
`pack.default`, `pack.todo`, `agent.capture_loop`, and `agent.todo_loop`
attribution. This validates that the old fake Agent Platform controller has
been removed from the visible plugin surface.

### Backup Export

The Backup page exported JSON after the same 20-round session. The emulator UI
showed:

- `Backup JSON is ready.`
- manifest counts for captures, cards, chat, todos, trace events, and other
  local tables
- `Copy JSON`
- `Copy Markdown`
- `Backup JSON`
- `Readable Markdown`

The manifest count visible in UI included:

| Manifest key | Count |
| --- | ---: |
| captures | 10 |
| cards | 10 |
| chat_messages | 20 |
| chat_sessions | 1 |
| event_log | 50 |
| insights | 3 |
| memory_candidates | 10 |
| memory_items | 0 |
| model_provider_configs | 0 |
| todos | 10 |
| trace_events | 110 |

Both copy buttons were tapped on-device. UIAutomator did not reliably expose the
Snackbar text, so the feedback assertion remains covered by Widget tests rather
than claimed from emulator accessibility output.

## Automated Validation

- `packages/dart/local_db`: `dart analyze && dart test`
- `apps/mobile`: `flutter analyze`
- `apps/mobile`: `flutter test`

The mobile suite covered 83 widget/unit tests after this slice. The local DB
suite covered 31 tests.

## Logs

- `adb logcat -b crash -d`: 0 lines
- WideNote process remained alive after QA.
- Trace table warning/error severity count: 0

The general logcat contains expected install/update and emulator system noise,
including repeated missing network time warnings. No WideNote crash was found in
the crash buffer.

## Findings

- The implemented slice closes the highest-risk fake surfaces found in the
  second audit: provider selection now reaches runtime model calls, chat can use
  the provider-backed assistant bridge, backup has a human-readable projection,
  and the plugin/trace surface reads real trace data.
- Real model latency/fallback behavior is the main runtime risk. The app keeps
  data and returns to ready state, but the UX frequently waits 45-55 seconds
  before fallback.
- Memory candidates correctly stayed in `needs_review`; AI output did not
  overwrite raw capture records.
- Remaining MemeX parity gaps are product scope gaps, not regressions in this
  slice: app lock/privacy gate, companion/location flows, richer card renderers,
  facts/entities/links/FTS, real media adapters, durable background task queue,
  and scheduler-style agent runs.
