# Transcription Feature

## Purpose

Owns mobile voice transcription, real-time transcript preview, local ASR model
state, explicit ASR engine selection, MiMo ASR configuration, and transcript
correction orchestration.

## Ownership Boundary

Capture owns raw media capture and attachment metadata. Transcription consumes
durable voice attachments and produces source-linked derived transcript
artifacts, events, traces, and correction evidence. It must not mutate or delete
raw audio, and transcript correction must not write Memory directly.

Transcript correction review routing follows the Pack/model
`requires_review` signal. Mobile code may validate schema-shaped output,
required fields, confidence/reason enums, and source text spans, but it must not
use local keyword or regular-expression heuristics over transcript text to infer
meaning sensitivity. Missing, malformed, or span-mismatched correction output is
review-only and must not auto-apply.

Local SenseVoice and MiMo ASR are user-selected alternatives, not fallback
layers. Old remote-fallback settings migrate to Local SenseVoice with remote
upload consent cleared. MiMo ASR credentials live in platform secure storage.
Full secret-bearing `.widenote` backups preserve MiMo settings and keys, but
local SenseVoice model files are excluded and must be redownloaded after
restore. Settings JSON may store safe provider metadata and consent state, but
never raw audio bytes.

## Dependencies

- Flutter/Riverpod for app state
- `record` for PCM/WAV capture support in the media adapter
- `sherpa_onnx` for gated local SenseVoice runtime integration
- `flutter_secure_storage` for remote ASR credentials
- `packages/dart/local_db` for source-linked transcript artifacts
- `packages/dart/agent_runtime` for model-backed correction prompts
- `packages/dart/model_providers` for fake/test HTTP transport patterns

## Public Surface

- `transcription_types.dart`
- `transcription_settings.dart`
- `transcription_download_manager.dart`
- `transcription_service.dart`
- `local_sensevoice_provider.dart`
- `mimo_asr_provider.dart`
- `transcript_correction_controller.dart`
- `presentation/voice_transcription_settings_page.dart`

## Generated Artifacts

None.

## Related Context

- `docs/architecture/current-contracts.md`
- `docs/decisions/0012-accept-voice-transcription-and-correction-boundaries.md`
- `docs/decisions/0016-restore-ready-logs-backups-and-asr.md`
- `docs/research/2026-06-30-voice-input-asr-correction-plan.md`
