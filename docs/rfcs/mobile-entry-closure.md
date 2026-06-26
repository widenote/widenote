# RFC: Mobile Entry Closure

Status: Implemented phase-one slice; current status superseded by W7 integration state

Date: 2026-06-25

## Context

The mobile app now has a useful local-first foundation, but several visible
entries are still incomplete: timeline rows only open cards, todos cannot be
completed, Memory has no dedicated management surface, pack and permission
entries are status-only rows, and backup export/import is still mostly
copy/paste shaped.

This RFC turns the gap audit into a phase-one implementation slice. It keeps
WideNote's own local-first design and uses MemeX only as a public capability
reference under ADR-0006.

## Goals

- Make every visible phase-one entry complete a user outcome.
- Preserve raw captures and source links when derived objects are opened,
  edited, completed, deleted, exported, or restored.
- Keep core usage accountless, local-first, and deterministic in tests.
- Keep custom script agents, companion characters, and broad permission grants
  out of this slice until sandbox and permission rules are accepted.

## This Slice Implements

| Module | Outcome |
| --- | --- |
| Timeline | Every timeline kind can open a detail surface. Card detail keeps richer related sections, and source references can be followed. |
| Todos | Todo rows are actionable with complete/reopen behavior and source metadata. |
| Memory | A dedicated Memory page supports list, edit, tombstone delete, restore visibility, and source metadata. |
| Packs | Built-in official packs have an inspectable library page based on WideNote-owned manifest concepts. |
| Permissions | Pack permission requests have a review page that distinguishes default granted, explicit-review, and deferred high-risk capabilities. |
| Backup | Backup keeps safe JSON/Markdown export and local import paths. Safe backup does not contain provider secrets; encrypted full backup stays unavailable until an encryption boundary exists. |
| Settings/Packs tab | The tab becomes a real control hub for Memory, packs, permissions, providers, backup, and traces. |

## Deferred

- Real camera/gallery picker, microphone recording, ASR, Android share intent,
  clipboard preview, and external file import. They need platform permission
  ports and Android/iOS QA in a media-entry slice.
- Companion characters, Tavern import, custom script Agent Packs, JavaScript
  tool execution, broad filesystem access, arbitrary network tools, location
  context, and app lock. These need explicit privacy and sandbox decisions.
- Full FTS/vector search. The current timeline search remains a local browse
  index until search indexing is accepted.

## Implementation Rules

- UI state must use existing local SQLite DAOs or feature controllers; do not
  create app-private public contracts.
- Memory edit and delete must increment revision and keep tombstone state
  instead of deleting rows.
- Todo completion must update the durable todo row, not just widget state.
- Pack and permission screens are inspectable phase-one views, not a dynamic
  community pack installer.
- Backup file operations write/read user-visible local files through an
  injectable file boundary so tests avoid platform channels.
- All new user-visible flows need widget tests, and persistence changes need
  unit tests.

## Acceptance Gates

- Unit tests for Memory operations, todo status changes, and backup file
  export/import helpers.
- Widget tests for timeline detail navigation, Memory edit/delete/restore,
  Todo complete/reopen, pack library, permission gate, and backup file actions.
- An orchestration test proves capture -> Memory/card/insight/todo -> timeline
  detail/source reference remains linked.
- External review may be run with Kimi when credentials work. Inputs must omit
  API keys, raw private backups, local database contents, and unpublished user
  records.
- Android emulator validation should cover the main user path: capture, open
  timeline detail, complete/reopen todo, edit/delete Memory, inspect packs and
  permissions, export/import backup.

## Open Questions

- Whether the Packs tab should be renamed Settings before phase-one release.
- Whether Memory revisions need a separate history table before sync starts.
- Whether backup files should move from app support storage to a user-selected
  directory once a file picker is accepted.
