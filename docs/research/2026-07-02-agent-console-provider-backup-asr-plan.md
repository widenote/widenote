# Agent Console, Provider Validation, Backup Completeness, And ASR Plan

Date: 2026-07-02

Status: subagent research, Kimi-reviewed design, and implemented slice on
2026-07-02

Scope:

- Log Center / Agent Console detail views and per-agent execution logs.
- Model Provider validation after key/model setup.
- Backup restore "works out of the box" principle and credential boundaries.
- Voice transcription local ASR download, MiMo ASR selection, and settings UI.

No API keys, local databases, raw private records, backup archives, raw audio,
or secret-bearing files were sent to external review.

## Subagent And Review Summary

| Topic | Subagent output | Kimi review result |
| --- | --- | --- |
| Log Center / Agent Console | Current Trace Console already reads local runs, tasks, and trace events, but lacked persisted prompt/tool detail. | Kimi initially recommended avoiding raw prompt persistence; product owner explicitly accepted local raw prompt/tool persistence. Safe export/external review paths remain no-raw/no-secret. |
| Model Provider validation | Existing UI has manual `Test connection` and model-list fetch. Need save-and-test flow plus persistent validation status. | Accepted explicit user-triggered validation. Flagged Gemini query-key redaction, stale result handling, and "declared vs verified capability" wording. |
| Backup completeness | `.widenote` full backup already preserves SQLite-backed model provider keys, but secure-storage AMap/MiMo ASR keys and ASR settings/model files are not included. | Accepted the conflict analysis. Flagged that AMap/MiMo keys require contract/ADR updates before entering full backups. |
| Voice transcription / ASR | Current implementation is local-first remote fallback; user direction requires explicit engine choice. Current SenseVoice HF URL is wrong/unusable. | Accepted engine-choice direction. Flagged silent audio upload after migration as a privacy red line, and required MiMo fixtures, endpoint normalization, and Base64 size guard. |

## Current Implementation Facts

### Log Center / Agent Console

- `apps/mobile/lib/features/traces` owns the mobile Agent Console read model and
  presentation.
- `TraceConsolePage` is currently reached from Settings and Plugins. It reads
  recent `trace_events`, runtime runs, and runtime tasks.
- `packages/dart/agent_runtime` already emits run/task/model/tool/approval
  traces.
- Model traces now store prompt length, context keys, raw prompt, raw model
  response, provider/model usage, duration, and status.
- Tool traces now store tool name, input keys, raw tool input/result/failure,
  risk/permission metadata, status, and error class.
- Pending approvals are currently a scaffold in the UI.
- Kimi and the subagent both found schema drift: public trace schema names
  concrete event types such as model/tool invocation, while local DB/UI often
  use broad categories such as `model`, `tool`, and `approval`.

### Model Provider Validation

- `packages/dart/model_providers` already has offline and adapter connection
  test services.
- `apps/mobile/lib/features/model_providers` already exposes provider add/edit,
  model-list fetch, custom model fallback, row-level `Test connection`, and
  in-memory connection status.
- Live validation only runs when explicitly enabled through the app wiring; CI
  and widget tests use offline/fake services.
- Connection status is not durable today. Restarting the app loses whether a
  provider is connected, failed, untested, or stale.
- The live probe only validates chat completion. Streaming, tool calling, and
  thinking controls are not yet real verified capabilities.

### Backup Completeness

- Default `.widenote` backup is already a secret-bearing full local archive:
  `manifest.properties`, full SQLite snapshot, and local capture media.
- SQLite-backed model provider credentials are restored today, so model
  providers can work immediately after a full restore.
- Safe JSON and Markdown projections still omit credential values.
- AMap settings and key live in Flutter secure storage under the location
  feature. Current contracts and ADR-0014 explicitly say AMap keys must not
  enter `.widenote` backups.
- MiMo ASR key also lives in secure storage. Voice transcription settings JSON
  and local ASR model files are not currently included in `.widenote`.
- Therefore, restored history and provider settings can come back, but location
  reverse geocoding and MiMo ASR are not fully direct-use after restore.

### Voice ASR

- The implemented slice replaces remote fallback with explicit
  `VoiceTranscriptionEngine` selection: Local SenseVoice, MiMo ASR, or Off.
- Old `local_first_remote_auto` settings migrate to Local SenseVoice with
  remote upload consent cleared.
- `TranscriptionService.transcribeAttachment()` routes to exactly the selected
  engine; manual MiMo retry remains an explicit action.
- WideNote local model download URLs now point at the SenseVoice 2024 int8
  mirror used by Memex evidence, with minimum-size verification before ready.
- Memex evidence points to the same SenseVoice 2024 int8 model with the
  domestic mirror used by its `WhisperService`:
  `https://hf-mirror.com/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/model.int8.onnx`
  and `tokens.txt`.
- Memex also keeps a global GitHub release tar source:
  `https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17.tar.bz2`.
- Memex's newer speech-recognition branch uses explicit provider selection
  rather than automatic local-to-MiMo fallback.

## Recommended Product Decisions

These are the decision points that should be answered before implementation
changes the current contracts.

Product-owner clarifications from 2026-07-02:

- Persist raw prompt/tool/model detail in local trace payloads. This is
  accepted because WideNote local data is already sensitive; safe exports,
  external reviews, PRs, logs, fixtures, and screenshots must still avoid raw
  private payloads and credentials.
- Model Provider setup does not need a complex post-save status model in the
  first slice; add a validation entry before save so users can test the key,
  endpoint, and model before committing the form.
- Full `.widenote` backup should include allowlisted secure-storage credentials
  such as AMap and MiMo ASR keys after the contract/privacy docs are updated.
- ASR should move to explicit engine selection instead of local-to-MiMo
  fallback.
- Local ASR model files should not enter backups.

1. Raw prompt persistence for Agent Console:
   Decision: persist raw prompts, model responses, tool inputs, and tool
   results in local trace payloads so Agent Console can explain what happened.
   Treat these payloads as local secret-bearing user data. Safe exports,
   external review prompts, PR descriptions, fixtures, screenshots, and logs
   must not include raw trace payloads or credentials.

2. Agent Console information architecture:
   Recommend one shared route with two entry labels: Settings calls it "Log
   Center"; Plugins/Agent surfaces call it "Agent Console". Mobile IA should be
   `Overview`, `Runs`, and `Agents`; approvals appear as badges/detail panels;
   raw event list belongs inside run detail.

3. Trace schema alignment:
   Recommend first implementation includes schema/adapter alignment or lands it
   immediately before UI claims detailed trace semantics. Keep concrete
   `trace_type`; add or derive `category` and `phase` for UI grouping.

4. Provider validation entry:
   Confirmed simplification: add a validation entry inside the add/edit form
   before save. The first slice should let users test the typed key, endpoint,
   and selected model before committing the form. Avoid a complex durable
   validation-state system until there is a clear runtime need.

5. Backup "out of the box" definition:
   Recommend defining full `.widenote` restore as: app-owned configuration and
   allowlisted BYOK credentials are restored, but OS permissions, network
   availability, provider account validity, and live validation still require
   user/device action. UI should call these `restored-unverified` rather than
   "guaranteed working".

6. AMap and MiMo ASR secrets in backup:
   Current contracts block AMap keys from `.widenote`. To satisfy the user's
   out-of-box restore principle, the product owner should decide whether full
   `.widenote` may include allowlisted secure-storage credentials such as AMap
   and MiMo ASR. Decision: include allowlisted secure-storage credentials in
   full `.widenote` after updating ADR-0014/current contracts/privacy docs and
   adding redacted secret manifest, import confirmation, and tests.
   `encryptedFull` remains a future stronger envelope.

7. Restore secret confirmation:
   Recommend default restore-all for full `.widenote` after the destructive
   import confirmation, with a clear category summary. Later add advanced
   category toggles if users need partial restore.

8. SenseVoice model in backup:
   Decision: exclude local ASR model files from backups. Restore ASR settings
   and settings state, then require local model redownload through the domestic
   mirror.

9. ASR engine relationship:
   Decision: Local SenseVoice and Xiaomi MiMo ASR are mutually selectable
   transcription engines, not fallback stages. This supersedes the old fallback
   wording in ADR-0012/current contracts.

10. Default local ASR model:
    Recommend SenseVoice 2024-07-17 int8 as the first default. A newer
    SenseVoice model can be offered later as a variant, but the 2024 model is
    the safer first slice because existing evidence and Memex paths target it.

11. MiMo ASR configuration:
    Recommend supporting a link to an existing Xiaomi MIMO model provider when
    available, with manual endpoint/key/model fields as fallback. This reduces
    duplicate credential entry while preserving ASR-specific request semantics.

12. Per-record MiMo retry:
    Recommend allowing "retry this transcript with MiMo" only through an
    explicit confirmation that uploads this audio and does not silently change
    global engine selection.

## Implementation Slices

### Slice A: Contract Updates

- Supersede the ASR fallback wording in ADR-0012/current contracts.
- Decide and document whether AMap/MiMo ASR keys are allowed in full
  `.widenote`.
- If allowed, update ADR-0014/current contracts/privacy/location README and add
  a small secret-classification ADR/RFC for backup.

Validation:

- `git diff --check`
- Link/terminology check with `rg` for fallback/AMap/key wording.

### Slice B: Agent Console Detail Logs

- Align trace schema/local DB/adapter terminology.
- Build read-only run detail timeline: trigger, task, prompt prepared, model
  call, tool call/approval/result, output, completion/failure.
- Add agent grouping and per-agent run list.
- Keep retry/cancel/approve disabled until live RuntimeKernel controls exist.
- Use one shared redacted trace projection for UI and trace-read tools.

Validation:

- `node packages/schemas/validate_fixtures.mjs`
- `cd packages/dart/agent_runtime && dart test`
- `cd packages/dart/local_db && dart test`
- `cd apps/mobile && flutter analyze && flutter test test/trace_console_page_test.dart test/settings_page_test.dart test/plugins_page_test.dart`

### Slice C: Provider Validation

- Add a form-level validation entry before save. It should test the currently
  typed endpoint, API key, and selected model without requiring the provider to
  be saved first.
- Keep row-level `Test connection` as a convenience for existing saved
  providers, but do not build a complex persisted validation-state workflow in
  the first slice.
- Redact URI query strings before logging/tracing provider model-list requests,
  especially Gemini key-in-query endpoints.
- Distinguish declared capabilities from verified capabilities.

Validation:

- `cd packages/dart/model_providers && dart analyze && dart test`
- `cd packages/dart/local_db && dart analyze && dart test`
- `cd apps/mobile && flutter analyze && flutter test test/model_provider_settings_test.dart test/model_client_test.dart`

### Slice D: Backup V2 Completeness

- Add archive v2 metadata for config and secret manifest.
- Add config snapshots for location and voice transcription settings.
- Add redacted `secret-manifest.json` and import report states:
  `ready`, `restoredUnverified`, `needsCredential`, `needsOSPermission`,
  `needsDownload`, `credentialInvalid`, `unsupportedLegacy`.
- Restore allowlisted secure-storage credentials such as AMap and MiMo ASR keys
  in full `.widenote` after contract/privacy docs are updated.
- Do not include local ASR model files in backups.

Validation:

- `cd packages/dart/local_db && dart analyze && dart test`
- `cd apps/mobile && flutter analyze`
- `cd apps/mobile && flutter test test/backup_page_test.dart test/location_context_test.dart test/voice_transcription_settings_test.dart test/model_provider_settings_test.dart`

### Slice E: Voice ASR Engine Redesign

- Replace fallback mode with `VoiceTranscriptionEngine`:
  `localSenseVoice`, `xiaomiMimo`, `disabled`.
- Migrate old settings without silently enabling remote upload.
- Route transcription directly by selected engine.
- Replace fallback UI copy with engine selection cards/segmented control.
- Fix model sources to domestic mirror + GitHub release fallback and add model
  manifest, expected-size/checksum/init-probe verification.
- Guard MiMo Base64 size and normalize endpoint/request fixtures.
- Disable or honestly label live preview until it produces real text.

Validation:

- `cd apps/mobile && flutter analyze`
- `cd apps/mobile && flutter test test/voice_transcription_settings_test.dart test/transcription_download_manager_test.dart test/transcription_service_test.dart test/capture_console_widget_test.dart`
- `node packages/schemas/validate_fixtures.mjs` if transcript events change.

## Recommended Order

1. Update contracts/ADRs for the confirmed backup and ASR decisions.
2. Implement Slice E for the user-visible broken ASR experience.
3. Implement Slice C so model setup has a pre-save validation path.
4. Implement Slice D with allowlisted secure-storage credential restore.
5. Implement Slice B in parallel or next, because it improves all later agent
   and provider debugging.

## Follow-up Risks

- Full `.widenote` without encryption is already secret-bearing. Expanding it
  to secure-storage keys raises the importance of backup warnings and future
  encrypted-full design.
- Local ASR model hashes should be pinned before marking downloads ready.
- MiMo live response shape must be frozen with fixtures and opt-in live tests
  before relying on streaming or chunk metadata.
- Provider validation should never send user records; only synthetic probes.
- Log Center detail must not accidentally expose prompt bodies, source excerpts,
  tool inputs, tool outputs, local file paths, audio bytes, or credentials.
