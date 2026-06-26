# Product and Technical Direction Summary

---
date: 2026-06-26
source: product-owner discussion, Memex/Omi research, industry research, Kimi review
status: summarized
related_decisions:
  - ../decisions/0009-use-object-truth-and-context-packets.md
---

## Key Conclusions

WideNote's phase-one product direction is:

```text
quick capture -> local source truth -> agent-derived cards/Memory/recap/insight
-> source-grounded conversation -> backup/export/control surfaces
```

Home is a daily return surface, not an infinite card feed. It should emphasize
capture, daily recap, recent records, and entry points. Records/cards remain
important, but the full stream can live in a secondary Home page or timeline.

The primary navigation model is:

- Home
- Chat
- Todos
- Plugins
- Settings in the top-right

Capture uses a bottom Compose Sheet. Phase one supports typed text, audio
recording, camera capture, and photo library selection. File picker, share
sheet, bulk import, external vault import, and broad cross-app ingestion are
deferred.

## Accepted Technical Direction

- SQLite/Drift object tables are canonical current object truth.
- Raw source files such as audio, images, and attachments live as files with
  metadata/source refs.
- Markdown is not canonical phase-one storage and is not an ordinary user
  workflow.
- AI gets generated context packets/read models for progressive disclosure.
- Context expansion order is summary/current context, accepted Memory, derived
  summaries/cards/recaps/insights, targeted raw excerpts/transcript/OCR, then
  attachments when allowed.
- FTS/BM25 plus recency/entity signals are phase-one retrieval defaults.
  Embeddings are optional rebuildable indexes.
- Agent runtime is event-driven, with append-only audit/routing events, durable
  tasks, idempotent handlers, permission-gated tools, and traces.
- Accepted Memory is canonical for personalization but remains source-linked
  derived knowledge with provenance.
- Cards, recaps, insights, todos, and chat answers are durable derived objects,
  not original user facts.

## Backup, Export, and Portability

Backup and Owner Export are separate product concepts.

Backup:

- restores the app to a fully usable state
- includes SQLite/object state, source file metadata, provider/model configs,
  selected defaults/routing, installed pack state, app settings, and credentials
  or secrets required for restore
- is secret-bearing user data when it includes credentials
- should be encrypted or require explicit user action and warning

Owner Export:

- helps users move or inspect their data
- includes raw captures, attachments/source materials, JSONL objects, manifest,
  and optional readable projections
- may include provider/model metadata without secrets
- excludes API keys/tokens/secrets by default
- labels derived outputs separately

## Finalized Choices From the Discussion

| Area | Choice |
| --- | --- |
| Raw capture truth | SQLite/Drift object truth; not Markdown canonical storage |
| AI progressive disclosure | Generated context packets/read models |
| Markdown | Optional export/developer/debug/context format |
| Context cache | Persist important packets as rebuildable SQLite caches; invalidate by source/version/policy |
| Phase-one AI | User-configured providers plus local-first storage |
| Retrieval | FTS/BM25 + recency/entity first; embeddings optional |
| Audio/OCR | Provider optional; raw media saved first, transcript/OCR derived |
| Delete | Soft delete by default; working default 30-day recoverable window, then purge |
| Export scope | Raw captures + attachments + manifest + JSONL objects + readable projection |
| Todo | First-level tab with empty/enable-pack state; Todo pack separate from default pack |
| Plugins | Official packs/local catalog first |
| Conversation writes | Chat may propose Memory/cards/todos through the same policy path; no direct mutation |
| RFC/ADR path | Umbrella technical-plan RFC first, then split stable ADRs |

## Evidence / Sources

- `docs/research/2026-06-26-storage-export-selection-options.md`
- `docs/research/2026-06-26-technical-plan-research-synthesis.md`
- `docs/research/2026-06-26-kimi-technical-direction-review.md`
- `docs/research/2026-06-26-mobile-ui-runtime-discussion-notes.md`
- Reference implementation research on Memex and Omi
- Industry references listed in the storage/export research note

## Open Questions

These are no longer blockers for the high-level direction, but they should be
handled in the umbrella RFC or follow-up ADRs:

- Exact context packet schema and invalidation keys.
- Exact backup encryption UX and restore-warning copy.
- Exact purge UX and whether the 30-day window should be user-configurable.
- Which provider/model metadata belongs in public schemas.
- How future cloud sync reconciles tombstones, accepted Memory, and derived
  object versions.

## Candidate ADRs

- Use SQLite/Drift object truth and generated context packets.
- Separate restorable Backup from Owner Export.
- Use source-linked derived objects for Memory/cards/recaps/insights/todos.
- Keep official Agent Packs behind the capability broker.

## Things Explicitly Not Decided

- Full community plugin marketplace.
- Cloud sync and multi-device conflict resolution.
- Markdown vault mode or Obsidian-style bidirectional import.
- Always-on/background capture.
- Full vector/graph memory as canonical storage.
