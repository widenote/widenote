# Agent Orchestration Parity Against Omi And Memex

Status: implementation follow-up evidence
Date: 2026-06-27
Scope: compare the WideNote capture-to-Memory Agent loop with BasedHardware Omi,
memex-lab Memex, and the Memex memory-primary scale-evidence branch.

## Inputs

- WideNote branch: `codex/widenote-agent-orchestration-parity`
- BasedHardware Omi snapshot:
  <https://github.com/BasedHardware/omi/tree/6ee684572>
- memex-lab Memex snapshot:
  <https://github.com/memex-lab/memex/tree/b6ad6e0>
- Memex memory-primary scale-evidence snapshot:
  <https://github.com/utopiafar/memex/tree/codex/memory-primary-scale-evidence-20260622>,
  local short SHA `8eff771`
- WideNote runtime and boundary docs:
  - `docs/architecture/runtime.md`
  - `docs/architecture/privacy.md`
  - `docs/rfcs/agent-runtime-capability-boundaries.md`
  - `docs/decisions/0010-delegate-semantic-selection-to-models.md`
  - `docs/decisions/0011-adopt-agent-runtime-roadmap.md`

## Comparable Scenario

The common scenario is:

```text
raw capture -> event -> agent orchestration -> Memory candidate -> card/insight/todo -> trace/eval evidence
```

This is not a request to copy implementation. Omi is a service-heavy lifelog
platform, while Memex is a local workspace Agent system. WideNote keeps the
mobile client as the first local runtime host, with backend runners and richer
tooling treated as optional roadmap surfaces.

## Event And Queue Shape

| Project | Trigger | Queue/run boundary | Derived outputs |
| --- | --- | --- | --- |
| Omi | Conversation completion, realtime transcript/app triggers, chat tool calls | Backend worker/executor tasks and post-processing futures | Structured conversation, apps, memories, action items, vectors, webhooks |
| Memex | `submitInput` and `GlobalEventBus` system events | `LocalTaskExecutor` durable tasks plus SuperAgent/child-agent runs | Cards, PKM notes, insights, schedule items, memories, comments |
| Memex scale-evidence | Full-chain replay through `MemexRouter.submitInput` | Persistent task drain, metrics, judge/audit/report commands | Memory-primary metrics, card completion, answer quality, badcase reports |
| WideNote before this change | `wn.capture.created` | `RuntimeKernel` task identity, pack subscriptions, run traces | `wn.memory.proposed`, `wn.card.created`, `wn.insight.created`, `wn.todo.suggested` |
| WideNote after this change | Same | Same, with `prompt_ref = capture.memory_summary.v1` in model context | Same, with a stronger source-truth capture prompt |

WideNote already had the core event/queue shape needed for the first product
loop. The missing parity item was not the event bus; it was that the built-in
capture Agent's prompt was too thin to document the same source-truth,
privacy, and output-shape contract that Omi and Memex encode in their
specialized prompts.

## Prompt Shape

| Project | Prompt pattern | WideNote takeaway |
| --- | --- | --- |
| Omi | Task-specific prompts for conversation discard, structuring, action items, memory extraction, and conflict resolution | Prompts should state workflow, source context, output shape, and safety filters per task |
| Memex | Long role prompts for SuperAgent, card, PKM, schedule, insight, and memory workers | Capture orchestration needs explicit source ids, bounded side effects, and child/output contracts |
| Memex scale-evidence | Real full-chain replay plus judge reports, not only unit-level prompt checks | Live provider QA should remain opt-in, key-based, and artifact-redacted |
| WideNote before this change | `Summarize capture for Memory: ...` | Too vague for source-linked Memory and privacy constraints |
| WideNote after this change | `capture.memory_summary.v1` | The capture Agent now requires source truth, one-sentence Memory candidate output, no invented facts, no secret echo, capture-language preservation, and no JSON/commentary |

The new prompt lives in
`apps/mobile/lib/features/capture/application/capture_agent_prompts.dart` and
is referenced by `packs/official/default/manifest.json`.

## Capability Shape

| Project | Agent capabilities | WideNote status |
| --- | --- | --- |
| Omi | Large core tool catalog, dynamic app tools, MCP/HTTP app tools, webhook delivery, calendar/email/health/file/web access | Roadmap fit for optional external capability, not phase-one default |
| Memex | SuperAgent delegation, scoped file tools, fixed child presets, run modes, approval gates, activity logs | WideNote has run modes, approval brokers, Pack permissions, tool registry, traces, and delegation planning; persisted child-run execution remains roadmap |
| Memex scale-evidence | Scenario fixtures, provider preflight, replay metrics, badcase audits, redacted reports | WideNote has opt-in DeepSeek live QA for the capture loop; broader replay metrics remain roadmap |
| WideNote | Local core tools for Context Packet, Memory read/propose, todo suggest, trace read; native official packs; source-linked events | Fits the local-first default loop and should expand through Pack/tool contracts before broad external access |

## Gap Closed In This Change

- Added `capture.memory_summary.v1` as the built-in capture Agent prompt
  contract.
- Updated the default official Agent Pack manifest and embedded mobile manifest
  snapshot to reference that prompt.
- Passed `prompt_ref` into the runtime model request context, so traces and
  provider adapters can attribute future live runs without inspecting prompt
  text.
- Updated widget/orchestrator tests to validate the stronger prompt while
  keeping fake model behavior independent from exact prompt wording.

## Remaining Gaps

- WideNote does not yet run a model-driven iterative tool loop like Omi's
  Anthropic tool-use chat loop.
- WideNote does not yet execute persisted child Agent runs like Memex
  SuperAgent delegation. The existing `DelegationPlanner` only validates child
  budgets and boundaries.
- WideNote does not yet have a Memex-scale replay harness with judge reports,
  badcase buckets, and run-history metrics for capture-to-Memory scenarios.
- WideNote intentionally does not enable broad file, email, calendar, health,
  web, or external app tools by default.

## Validation Results

Ran on 2026-06-27:

- `flutter test test/capture_orchestrator_test.dart`
- `flutter test test/widget_test.dart test/chat_page_test.dart test/capture_console_widget_test.dart`
- DeepSeek live QA:
  `flutter test test/agent_orchestration_live_test.dart`
  with `WIDENOTE_QA_DEEPSEEK_API_KEY`,
  `WIDENOTE_QA_DEEPSEEK_ENDPOINT=https://api.deepseek.com/anthropic`, and
  `WIDENOTE_QA_DEEPSEEK_MODEL=deepseek-v4-flash`
- DeepSeek simulator smoke on iPhone 17 / iOS 26.5:
  `flutter test integration_test/deepseek_agent_orchestration_test.dart -d <simulator>`
  with the same DeepSeek dart-defines. This used the real app route,
  in-memory local DB, real provider adapter, `agent.capture_loop`, and
  `agent.todo_loop`, then asserted capture persistence, Memory review
  candidate, todo projection, expected runtime events, `runtime.model.completed`,
  and no API key in trace payloads.
- iOS simulator phase-one journey:
  `flutter test integration_test/phase_one_journey_test.dart -d <simulator>`
- `flutter analyze` for touched capture, widget, and integration files.
- `dart test test/pack_manifest_bridge_test.dart` from
  `packages/dart/agent_runtime`.
- `node tools/pack_validator/validate_test.mjs`
- `node tools/pack_validator/validate.mjs packs/official/default/manifest.json packs/official/todo/manifest.json`
- `git diff --check`
- Targeted secret scan for the provided DeepSeek key fragments.

The Android `Medium_Phone_API_35` AVD was available in `flutter emulators`, but
`flutter emulators --launch Medium_Phone_API_35` did not leave a booted adb
device or emulator process. The simulator validation therefore used iPhone 17 /
iOS 26.5.

Live provider keys must stay in process environment or dart-defines only and
must not be committed, printed, copied into docs, or stored in artifacts.
