---
id: ADR-0009
title: Use object truth and generated context packets for phase-one mobile memory
status: accepted
date: 2026-06-26
owners: [core]
tags: [storage, runtime, memory, export, ai-context, mobile]
supersedes: []
superseded_by:
sources:
  - ../research/2026-06-26-product-technical-direction-summary.md
  - ../research/2026-06-26-storage-export-selection-options.md
  - ../research/2026-06-26-technical-plan-research-synthesis.md
  - ../research/2026-06-26-kimi-technical-direction-review.md
---

# Use Object Truth and Generated Context Packets for Phase-One Mobile Memory

## Context

WideNote needs to preserve original user input, support mobile-first capture,
run local Agent Packs, provide source-grounded conversation, and let users back
up or move their data. The product owner considered whether Markdown files
should be the source of truth because Markdown is AI-readable and useful for
progressive disclosure.

Research across Memex, Omi, OpenClaw-like Markdown workspaces, and industry
local-first practices showed a split:

- Markdown is strong for agent workspaces, developer trust, and user-readable
  exports.
- Mobile capture, permissions, revisions, deletion, attachments, Memory
  lifecycle, backup/restore, and future sync need object-level truth.

## Decision

WideNote phase one uses SQLite/Drift object tables as canonical current object
truth. Source media and attachments are stored as files with metadata and source
refs. Markdown is not canonical phase-one storage and is not an ordinary user
workflow.

AI progressive disclosure is served by generated context packets/read models.
These packets are text-first, permission-aware, source-linked, and expandable:

```text
summary/current context
  -> accepted Memory
  -> derived summaries/cards/recaps/insights
  -> targeted raw excerpts/transcript/OCR
  -> attachments only when allowed
```

Important context packets may be cached in SQLite as rebuildable derived state.
They are invalidated by source refs, source versions or content hashes,
permission scope, and generator version. They are not source truth.

Append-only events are used for audit, routing, task idempotency, and future
sync evidence. WideNote does not adopt full event sourcing in phase one:
SQLite/Drift object tables remain the canonical current state.

Backup and Owner Export are separate:

- Safe Backup restores local app data and settings without provider credential
  values. It includes provider/model metadata, selected defaults/routing,
  installed pack state, and settings, then reports which provider keys need
  user re-entry after restore.
- Encrypted full backup is the future path for secret-bearing restore
  portability. It must not be described as implemented until the encryption
  boundary and restore behavior exist.
- Owner Export is portable user data and excludes API keys, tokens, and secrets
  by default. It may include provider/model metadata without secrets.

Deletion is soft by default. The working default is a 30-day recoverable window,
followed by permanent purge that removes content and keeps only minimal
tombstone metadata needed for references, audit, and future sync.

Accepted Memory is canonical for retrieval and personalization, but remains
source-linked derived knowledge. It must preserve provenance from source refs,
candidate/policy events, sensitivity/type, and user review actions.

## Considered Options

- Markdown vault as canonical truth.
- SQLite/Drift object truth with Markdown/export projections.
- SQLite/Drift object truth with generated context packets for AI and optional
  export projections.
- Full event sourcing where object tables are only projections.

## Rationale

This direction preserves local-first ownership without forcing ordinary users
to understand files. It gives AI the text-first context it needs while keeping
the product runtime reliable on mobile.

It also avoids ambiguity seen in file-first systems where raw input, generated
cards, Memory, recaps, and indexes can all start to look like competing truth.

## Consequences

Positive:

- Raw input and source files remain protected from AI overwrites.
- AI context can be progressively disclosed without exposing private tables.
- Owner Export stays portable and safe by default.
- Safe Backup can restore local records, derived state, settings, and provider
  metadata while requiring provider key re-entry.
- Context, FTS, embedding, thumbnails, Markdown, and other projections remain
  rebuildable.

Negative:

- A context-packet builder/read-model layer is required.
- Export/projection discipline is required so object truth remains portable.
- Backup UX must clearly communicate secret-bearing artifacts.
- Future sync must define how tombstones, accepted Memory, and derived object
  versions reconcile.

## Follow-ups

- Draft the umbrella technical-plan RFC from the accepted direction.
- Define context packet schemas, invalidation keys, and permission scopes.
- Define encrypted full-backup UX and restore behavior.
- Keep the Model Provider Settings RFC aligned with the W7 safe-backup default.
- Add tests that official packs still exercise capability declaration,
  permission checks, denial, and revocation paths.

## Amendment: W7 Safe-Backup Boundary

Date: 2026-06-26

The W7 phase-one implementation makes safe backup the default and only
implemented mobile backup path. Safe backup does not include provider API key
values and cannot fully restore provider credentials. It preserves provider
metadata and reports that keys must be re-entered.

Encrypted full backup remains a follow-up capability. It may become the
secret-bearing restore path only after encryption metadata, UX, and restore
behavior are implemented.

## Amendment: Directory-Based Safe Backup

Date: 2026-07-01

The default user-facing `.widenote` backup is a compressed directory archive,
not a Markdown or JSON restore document. The archive stores a safe SQLite
snapshot under `widenote-backup/data/`, local capture media under
`widenote-backup/media/`, and a lightweight `manifest.properties` file with
entry sizes and SHA-256 hashes.

The safe SQLite snapshot preserves provider metadata and `has_api_key` state,
but clears provider credential values and redacts unsafe provider payload
fields before compression. Restore extracts the archive to a staging directory,
verifies entry checksums, then imports the staged SQLite snapshot through the
same replace-all database restore policy.

JSON backup documents and Markdown Owner Export remain package-level
compatibility/projection tools, not the default mobile backup or restore path.

## Amendment: Full Credential-Preserving Directory Backup

Date: 2026-07-01

The default user-facing `.widenote` backup remains a compressed directory
archive, not a Markdown or JSON restore document. The default archive now uses a
full SQLite snapshot and includes provider API key values and provider payload
fields so a restored device can use configured model providers immediately.

This supersedes the W7 safe-backup credential-omission behavior for the default
mobile `.widenote` path. `.widenote` files are secret-bearing local artifacts;
the mobile UI must tell users to save them only to trusted destinations.

Safe JSON backup documents and Markdown Owner Export remain compatibility and
projection surfaces. They must continue to exclude provider API key values and
must not become the default mobile restore path.

`LocalBackupMode.full` represents this user-managed, secret-bearing local
directory backup. `LocalBackupMode.encryptedFull` remains reserved for a future
encrypted envelope and must not be claimed by the current compressed-directory
implementation.

See [ADR-0013](./0013-preserve-provider-credentials-in-widenote-backups.md) for
the dedicated current decision record for provider credentials in `.widenote`
backups.
