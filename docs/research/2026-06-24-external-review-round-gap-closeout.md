# 2026-06-24 External Review Round Gap Closeout

Status: complete for this implementation slice; full MemeX parity still has
known product gaps.

Scope: second MemeX gap audit, Kimi external review, implementation follow-up,
and test disposition.

## Inputs

- Current WideNote working tree after the first parity branch.
- MemeX public repository structure and the provided `.memex` backup shape,
  inspected only at structure/count/template level.
- Subagent audits for WideNote current feature state and MemeX user/data
  capability shape.
- Kimi CLI review of the narrowed follow-up plan.
- Kimi CLI review of the final uncommitted diff and Android QA report.

The review context excluded API keys, raw private backup contents, and local DB
payloads.

## Implemented This Round

- Provider runtime bridge: capture now prefers the user-selected default model
  provider, keeps the existing QA MIMO override, and falls back to deterministic
  local summary if provider calls fail.
- Provider-backed chat bridge: chat uses the configured runtime model when a
  real provider is available and retains deterministic local fallback.
- Backup Markdown export: full JSON backup remains secret-bearing and
  restorable; Markdown is a readable non-restorable projection that reports API
  key presence without key values.
- Backup copy actions: JSON and Markdown exports have explicit copy controls,
  with UI feedback.
- Real trace console: the old fake Agent Platform queue was removed. Plugins
  now link to a read-only trace console backed by `trace_events`.
- Documentation and map updates for the new trace feature and Markdown export.

## External Review Findings And Disposition

| Finding | Disposition |
| --- | --- |
| Markdown export is safe if it omits API key values. | Accepted. Tests assert API key values do not appear in Markdown. |
| Trace console must be read-only and widget-tested. | Accepted. The console only reads `trace_events`; `agent_platform_widget_test.dart` and `trace_console_page_test.dart` cover UI states. |
| JS/script execution should stay out until sandbox rules exist. | Accepted. No script runtime was added. |
| Companion/character scope remains unclear. | Still open. No companion module is claimed as complete in this slice. |
| Location context must not bypass Memory review. | Still open. No location collection setting was added in this slice. |
| App lock is a major privacy parity gap. | Still open. No app lock/biometric/PIN guard is claimed as complete in this slice. |
| Final review noted low-cost test gaps around trace snapshot logic, empty model replies, and Markdown edge cases. | Accepted. Added focused tests for each before final validation. |
| Final review confirmed backup/API key handling was described accurately. | Accepted. JSON remains restorable and secret-bearing; Markdown remains non-restorable and omits key values. |

## Remaining MemeX-Parity Gaps

These remain real gaps after this patch:

- Companion/character workflows, including character memory and import/export
  semantics.
- Location context settings and place/map card handling, with location Memory
  still requiring review by policy.
- App lock/privacy guard with platform abstraction.
- Rich card renderer families beyond the current Memory-first summaries.
- Facts/entities/tags/cross-links and FTS-backed knowledge search.
- Real camera/microphone/share/OCR/STT integrations beyond the current fake
  media adapters.
- Durable task queue, dependency graph, retry/cancel controls, and redacted LLM
  call logs for custom Agent runs.
- Schedule aggregation beyond source-linked todos.

## Tests Added Or Updated

- `packages/dart/local_db/test/backup_export_test.dart`
- `apps/mobile/test/model_client_test.dart`
- `apps/mobile/test/chat_controller_test.dart`
- `apps/mobile/test/backup_page_test.dart`
- `apps/mobile/test/agent_platform_widget_test.dart`
- `apps/mobile/test/trace_console_page_test.dart`

## Validation

Validated locally:

- `dart analyze && dart test` in `packages/dart/local_db`
- `flutter analyze` in `apps/mobile`
- `flutter test` in `apps/mobile`

Android emulator validation is recorded separately in the Android QA report for
the final app build.
