---
id: ADR-0016
title: Make logs, backups, provider validation, and ASR restore-ready
status: accepted
date: 2026-07-02
owners: [core, mobile, privacy]
tags: [trace, backup, restore, asr, model-providers, privacy, local-first]
supersedes:
  - ./0012-accept-voice-transcription-and-correction-boundaries.md
superseded_by:
sources:
  - ./0012-accept-voice-transcription-and-correction-boundaries.md
  - ./0013-preserve-provider-credentials-in-widenote-backups.md
  - ./0014-accept-location-capture-boundaries.md
  - ../research/2026-07-02-agent-console-provider-backup-asr-plan.md
---

# Make Logs, Backups, Provider Validation, And ASR Restore-Ready

## Context

The product owner clarified four related restore and operations expectations:

- Agent Console needs detailed per-agent execution logs, including prompts,
  progress, tool inputs, and tool results.
- Provider setup should offer a validation entry before saving, using the
  current form values.
- Full `.widenote` backup should restore configured functions ready for direct
  use, including allowlisted secure-storage credentials such as AMap and MiMo
  ASR keys. Local ASR model files are explicitly excluded.
- Local SenseVoice and MiMo ASR are alternatives selected by the user, not an
  automatic fallback chain.

These choices intentionally make local artifacts more complete and more
sensitive. They need a single accepted record so future agents preserve the
secret boundary while keeping the product usable after restore.

Supersession note: this ADR partially supersedes ADR-0012's automatic remote
ASR fallback behavior. It does not replace ADR-0012's source-truth, WAV,
transcript artifact, backup media, correction Pack, or runtime-tool boundaries.

## Decision

Runtime traces may persist raw model prompts, model responses, tool inputs, and
tool results in the local trace payload. These logs are part of the local-first
user data set. Safe export, external review, PR descriptions, fixtures,
screenshots, and logs outside the app must still avoid raw private content and
credentials.

The default full `.widenote` directory backup remains the secret-bearing
`LocalBackupMode.full` artifact. It may include allowlisted app-owned
secure-storage settings and credentials needed for direct-use restore:

- location settings, including the AMap API key;
- voice transcription settings, excluding local model files;
- MiMo ASR API key.

A full backup that restores metadata but drops an enabled feature's saved key is
not restore-ready. After import, key-backed local features such as AMap reverse
geocoding and MiMo ASR should run from the restored configuration without a
hidden re-entry step. Local ASR model binaries remain excluded and may require a
redownload before local transcription is usable.

The archive must continue to use `manifest.properties`, entry hashes, and
`includes_secrets=true`. Legacy JSON/Markdown projections remain secret-free.
Non-formal mobile builds append diagnostic log copies under
`diagnostics/*.log` plus export metadata under `diagnostics/export-info.txt`.
That includes debug/profile builds and release builds with explicit non-formal
flavors such as `dev` or internal QA channels. These files are part of the local
secret-bearing backup artifact for support review, are checksum-verified by the
archive manifest, and are ignored by restore so they do not become canonical
user data. Formal release flavors and unflavored release builds omit these extra
diagnostics.

Model Provider Settings must expose an explicit, user-initiated connection test
from the add/edit form before save. Draft tests use synthetic provider probes
and keep the result in UI state only. They must not write draft validation state
to durable settings.

Voice transcription settings use one selected engine at a time:

- Local SenseVoice;
- MiMo ASR;
- Off.

Old `local_first_remote_auto` settings migrate to Local SenseVoice with remote
consent cleared, so upgrades never silently upload audio. Manual MiMo retry is
still available as an explicit user action. The bundled SenseVoice download
source should use a reachable mirror and validate downloaded file size before
marking the local model ready.

## Consequences

Positive:

- Users and agents can inspect what happened in local runtime execution.
- Restored backups can use model providers, AMap reverse geocoding, and MiMo
  ASR without hidden re-entry steps, except for local ASR model redownload.
- ASR behavior is more predictable because local and MiMo are explicit choices.
- Provider setup gets a simple validation path before save.

Negative:

- `.widenote` files and local trace payloads are more sensitive and must be
  treated as secret-bearing user data.
- Backup and trace features need stronger tests for redaction boundaries and
  restore ordering.
- Future sync or hosted backup must not reuse the full local artifact without
  an accepted encryption and permission design.

## Follow-ups

- Keep public trace schema and local trace categories aligned as the trace
  export surface matures.
- Consider a user-level raw trace persistence toggle if users ask for a stricter
  privacy mode.
- Add checksum metadata for the local ASR model when the upstream distribution
  publishes stable hashes.
