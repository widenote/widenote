---
id: ADR-0013
title: Preserve provider credentials in WideNote backup archives
status: accepted
date: 2026-07-01
owners: [core, mobile, privacy]
tags: [backup, restore, privacy, credentials, mobile, local-first]
supersedes: []
superseded_by:
sources:
  - ./0009-use-object-truth-and-context-packets.md
  - ../rfcs/model-provider-settings.md
  - ../rfcs/phase-one-product-scope.md
  - ../research/2026-07-01-android-backup-restore-interaction-plan.md
---

# Preserve Provider Credentials in WideNote Backup Archives

## Context

The backup requirement changed several times during W7:

- Safe backup omitted provider API keys and required key re-entry after restore.
- The default backup then moved from JSON/Markdown documents to a compressed
  `.widenote` directory archive.
- The final product requirement is that API keys must be preserved exactly in
  backups so restore can be used immediately.

This affects privacy, default UX, local-first restore behavior, and future
backup compatibility, so the decision needs a dedicated record rather than only
inline implementation comments.

## Decision

The default user-facing `.widenote` backup is a full, secret-bearing,
user-managed local archive. It preserves provider API key values and provider
payload fields exactly as stored in the local SQLite database.

Restore from a `.widenote` archive must restore provider credentials so model
providers are usable immediately after import. The UI must clearly communicate
that `.widenote` files contain provider API keys and should be saved only to
trusted locations.

The archive shape is a compressed directory:

```text
widenote-backup/
  manifest.properties
  data/widenote.sqlite
  media/capture_media/**
```

The mobile implementation must run compression, SQLite snapshotting, extraction,
and archive inspection off the UI isolate where the work may be expensive.

Legacy JSON and Markdown projections remain no-secret compatibility/export
surfaces. They must not include provider API key values and must not become the
default mobile restore source.

`LocalBackupMode.full` represents this current full local restore artifact.
`LocalBackupMode.encryptedFull` remains reserved for a future encrypted envelope
and must not be used to describe the current compressed-directory backup.

## Considered Options

- Keep safe backup as the default and require provider key re-entry.
- Add an encrypted full backup before allowing credential-preserving restore.
- Preserve credentials in the default `.widenote` local archive and make the
  user-facing secret boundary explicit.

## Rationale

WideNote is local-first and accountless by default. A backup that restores all
records but silently breaks configured model providers is incomplete for the
core user flow. Preserving credentials makes backup/restore match user
expectations: after restore, the app should work.

The `.widenote` archive is user-managed local data rather than a cloud sync
payload. That makes it acceptable for the default backup to be secret-bearing as
long as the UI and docs are explicit, tests cover the behavior, and safer
JSON/Markdown projections remain available for non-secret export needs.

## Consequences

Positive:

- Restored devices can use configured model providers immediately.
- Backup semantics are simpler for users: `.widenote` means full local restore.
- Tests can assert the exact provider credential round-trip.

Negative:

- `.widenote` files are sensitive artifacts and must be handled like secrets.
- Users need clear save/share warnings because a copied backup contains API
  keys.
- Future sync or hosted backup must not reuse this artifact without an accepted
  encryption and permission design.

## Follow-ups

- Keep JSON/Markdown projections secret-free and covered by tests.
- Add an encrypted backup envelope only through a future ADR/RFC that defines
  key management, restore UX, and migration behavior.
- Avoid logging, indexing, previewing, or sending `.widenote` contents to
  external review tools.
