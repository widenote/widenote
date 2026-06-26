# WideNote Storage and Export Selection Options

Status: research-merged options
Date: 2026-06-26
Scope: module-level storage/export choices before detailed technical planning

## Purpose

This note prepares module-level architecture choices for WideNote's storage,
export, and text-first data design.

The product owner added two guiding principles:

1. Users should be able to move their original inputs out of the app easily.
   Import can be deferred; export and portability matter now.
2. In the large-model era, durable storage should be compatible, loose, and
   mostly natural-language-text-first. Structured fields should support
   lifecycle, provenance, permissions, indexing, sync, and recovery rather than
   replacing readable source text.

This note merges parallel read-only research on Memex, Omi, and industry best
practices.

## Confirmed Direction After Markdown Discussion

The product owner agreed that ordinary users should not need to see or manage
Markdown files if the product experience is strong enough. Markdown has value
for portability, developer trust, and AI readability, but it should not become
the ordinary user-facing data model.

The confirmed direction is:

```text
SQLite / Drift object truth
  + source files for audio, images, and attachments
  + rebuildable FTS / embedding indexes
  + generated context packets for AI progressive disclosure
  + JSONL / optional Markdown export for portability
```

Markdown is not phase-one canonical storage. It can appear in exports,
developer/debug views, or generated context packets, but the app should not
require users to understand a Markdown vault.

### Why OpenClaw-like Projects Use Markdown

OpenClaw-style projects use Markdown because they are agent/workspace-first:
agent memory, instructions, and daily notes can be read by humans, injected into
prompts, edited with standard tools, and versioned easily. This is useful for
developer-facing agent workspaces and advanced PKM users.

That pattern does not map directly to WideNote's default product shape. WideNote
is mobile capture-first: it needs reliable local writes, source refs, privacy
permissions, lifecycle state, attachment management, and future sync/export
semantics. Those concerns are better handled by object storage plus generated
text views.

The WideNote adaptation is:

- AI should receive text-first context packets, not raw private tables.
- Context packets should support progressive disclosure: summary first, then
  source refs, then raw excerpts, then attachments when allowed.
- The context packet is a generated/read model, not source truth.
- Markdown export can exist for portability and ecosystem trust, but ordinary
  users should not need it day to day.

## Research Synthesis

The research converges on one direction:

```text
SQLite / Drift local truth
  + lightweight append-only events for capture/runtime/memory lifecycle
  + text-first bodies in stable envelopes
  + source files stored as files with metadata/source refs
  + JSONL machine-readable export
  + Markdown/YAML human-readable projection
  + optional SQLite snapshot backup
```

Do not make any of these the canonical truth in phase one:

- Markdown vault
- vector database
- knowledge graph
- Parquet/analytics export
- generated card fact
- AI recap or summary

These are useful projections, indexes, or exports, not the source of truth.

## Reference Findings

### Memex

Memex is useful because much of the user's data is visible as files: YAML,
Markdown, JSON/JSONL, and media files. DB state is often queue/cache/index/run
state. This supports portability.

The important caveat is that Memex's `Card.fact` is AI-organized source text,
not the user's raw input. WideNote should not copy that ambiguity. WideNote must
preserve raw capture separately and make cards clearly derived.

Adopt:

- visible media/source files instead of DB blobs
- text-first derived artifacts
- rebuildable DB caches/indexes
- backup manifest with version/checksum
- source-linked cards and insights

Avoid:

- card fact as raw truth
- Memory as one merged Markdown profile without per-item provenance
- multiple media folders acting as competing truth
- private hidden files becoming Agent Pack APIs

### Omi

Omi is useful for object layering. It treats conversation as a source object,
then promotes daily summaries, action items, memories/facts, and apps results
into separate derived collections linked back to conversation ids.

Adopt:

- source object first, derived outputs second
- daily recap as a durable source-linked object
- action items and memories as independent lifecycle objects
- export fields separated into user-visible content versus backend/internal
  processing state
- separate owner export from developer/app source access

Avoid:

- putting transcript, summary, action items, app results, and processing state
  into one mixed canonical object
- broad app permissions like reading all conversations/memories/tasks
- backend/cloud processing as required core

### Industry

Industry practice supports:

- local-first ownership and exportability
- JSONL for appendable/log-like machine-readable export
- Markdown/YAML for human-readable projections
- stable envelopes plus loose text/JSON bodies for schema evolution
- attachments as files with metadata/hash/source refs
- tombstones/revisions rather than blind overwrite/delete
- vector/graph indexes as rebuildable projections
- separate backup and owner export concepts

## Design Principles

- Raw input belongs to the user and must be easy to export.
- AI output is derived and must not overwrite raw input.
- Text-first does not mean unstructured chaos: every durable object still needs
  id, type, version, timestamps, source refs, lifecycle state, and provenance.
- SQLite/Drift can be the app runtime store, but export should not require
  reverse-engineering SQLite tables.
- Natural-language fields should remain readable and useful outside WideNote.
- Indexes, embeddings, thumbnails, caches, and projections must be rebuildable.
- Attachments should be source material with stable references, not hidden blobs
  inside opaque records.
- Agent Packs should consume public source refs and derived objects, not private
  app table internals.
- Progressive AI disclosure should be served by explicit context packets or
  read models generated from canonical objects, not by treating a Markdown vault
  as the app's truth.

## Module Choice Matrix

### 1. Raw Capture Storage

| Option | Shape | Pros | Cons |
| --- | --- | --- | --- |
| A | SQLite rows with text body and metadata | Fast queries, migrations, local runtime friendly | Export needs a separate projection |
| B | Plain Markdown / text files as canonical source | Excellent portability, user-readable | Harder mobile concurrency, indexing, revisions, source refs |
| C | SQLite canonical store + exportable JSONL/Markdown projection | Runtime-safe and portable | Requires export/projection discipline |
| D | SQLite canonical store + generated AI context packets + optional export projections | Keeps runtime reliable while making AI context text-first | Requires a context builder/read-model layer |

Current recommendation: D.

The app should store captures in the local database for reliable mobile runtime,
generate text-first context packets for AI, and maintain a first-class export
format where raw text is easy to read and process.

Decision nuance:

- Raw capture should not be a generated card fact.
- Edits to raw capture should create a revision or correction event, not
  silently overwrite the original.
- User-facing export should make raw input the first and easiest thing to take
  away.
- AI-facing context should be explicit, permission-aware, and progressively
  expandable instead of reading arbitrary app files.

### 2. Event Log

| Option | Shape | Pros | Cons |
| --- | --- | --- | --- |
| A | SQLite event table only | Reliable local processing | Harder to inspect outside app |
| B | Append-only JSONL as canonical log | Portable, streamable, easy backups | Mobile transactional writes and indexing are harder |
| C | SQLite event table + JSONL export / backup stream | Best runtime/export balance | Two representations to keep aligned |

Current recommendation: C.

Events should be transactionally stored in SQLite, but export to JSONL because
JSON Lines is streamable and naturally append-oriented.

Scope nuance:

Use lightweight eventing for capture, Agent runtime, Memory lifecycle, and
audit. Do not force every UI preference or cache mutation into full event
sourcing.

### 3. Attachments and Source Materials

| Option | Shape | Pros | Cons |
| --- | --- | --- | --- |
| A | Store files directly in DB blobs | Atomic and simple backup | Poor portability and large DB growth |
| B | Files on disk with metadata rows and source refs | Portable, efficient, easy user export | Need cleanup and backup manifest |
| C | Content-addressed blob store with metadata rows | Deduplication and robust backup | More implementation complexity |

Current recommendation: B for phase one, C as future-compatible layout.

Decision nuance:

- Phase one can store files by stable id plus metadata.
- A future content-addressed layout can use hashes for dedupe and integrity.
- Export should include original media files by default for owner export unless
  the user chooses raw-text-only export.
- EXIF/location metadata is sensitive and should have an explicit export
  setting.

### 4. Derived Cards

| Option | Shape | Pros | Cons |
| --- | --- | --- | --- |
| A | Highly structured card schema | Easy rendering and querying | Less flexible for LLM-generated forms |
| B | Natural-language Markdown body + small metadata envelope | Flexible, exportable, model-friendly | Requires renderer constraints |
| C | Template id + text body + loose JSON payload | Balanced rendering and extensibility | Needs clear source refs and versioning |

Current recommendation: C.

Cards should be readable as text, but still have enough typed metadata for UI,
source refs, regeneration, and export.

Decision nuance:

- Cards are durable derived objects, not source truth.
- Deleting or regenerating a card must not delete raw capture.
- Export should mark cards as `AI Derived` or `App Derived`.

### 5. Memory

| Option | Shape | Pros | Cons |
| --- | --- | --- | --- |
| A | Pure natural-language profile document | Very readable | Hard to revise, cite, delete, and sync safely |
| B | Atomic Memory items with body text and lifecycle metadata | Source-linked, editable, tombstone-friendly | Slightly more structure |
| C | Hybrid profile document generated from atomic Memory items | Nice export/projection while preserving lifecycle | Needs projection generation |

Current recommendation: B canonical, C export/projection.

Decision nuance:

- Canonical Memory should be atomic items/candidates, not one profile blob.
- `Memory.md` can be generated as a readable projection.
- Rejected, superseded, or tombstoned Memory should be excluded from default
  readable export but available in full archive/audit export.

### 6. Daily Recap and Insights

| Option | Shape | Pros | Cons |
| --- | --- | --- | --- |
| A | Render-only home summaries | Easy UI | Not portable or reviewable |
| B | Versioned derived text artifact with sections and source refs | Exportable, source-grounded | Needs lifecycle and regeneration rules |
| C | Fully structured analytics object | Queryable | Risks becoming too rigid and less readable |

Current recommendation: B.

Decision nuance:

- Daily Recap should be a versioned derived artifact with source refs.
- Recap sections can be loose modules: overview, highlights, unresolved
  questions, decisions, knowledge nuggets, source stats.
- Location, people, emotion, and photo/audio-derived snippets should be
  configurable or treated as sensitive modules.

### 7. Todo Pack Outputs

| Option | Shape | Pros | Cons |
| --- | --- | --- | --- |
| A | Todo as simple structured task rows | Easy task UI | Less text-first |
| B | Todo item with natural-language title/body plus source refs | Readable and source-linked | Dates/status need typed fields |
| C | Todo suggestions as derived cards only | Lightweight | Weak task management |

Current recommendation: B for enabled Todo pack.

Decision nuance:

- Todo is not emitted by the default pack.
- Recap may show action-like summaries, but true task status belongs to the Todo
  pack's lifecycle object.
- Avoid double authority between recap action text and Todo state.

### 8. Backup and Export

| Option | Shape | Pros | Cons |
| --- | --- | --- | --- |
| A | Database backup only | Exact restore | Not user-friendly or portable |
| B | Markdown folder only | Human-readable | Loses lifecycle and structured metadata |
| C | Portable archive: manifest + JSONL objects/events + attachments + Markdown projections | Best ownership and future import path | More design work |

Current recommendation: C.

Important split:

```text
Backup
  -> restorable app state
  -> includes provider/model config, selected defaults, pack state, and settings
  -> includes credentials/secrets for full restore when the user creates a
     secret-bearing backup
  -> should be encrypted or require explicit user action and warning

Owner Export
  -> portable user data
  -> raw captures and source materials first
  -> JSONL + Markdown + attachments + manifest
  -> derived outputs in clearly labeled folders
  -> may include provider/model metadata but excludes credentials/secrets by
     default

App/Agent Source Access
  -> permissioned runtime access for packs
  -> separate from owner export
  -> least privilege, revocable
```

Recommended portable archive shape:

```text
manifest.yaml
events.jsonl
records.jsonl
memory.jsonl
derived/cards.jsonl
derived/recaps.jsonl
derived/insights.jsonl
attachments/
  <stable-id-or-sha256>/
readable/
  YYYY/
    MM/
      DD.md
checksums.sha256
```

Export does not need to be importable in phase one, but it should not paint the
future import design into a corner.

### 9. App / Agent Source Access

| Option | Shape | Pros | Cons |
| --- | --- | --- | --- |
| A | Packs can read all local data after install | Simple for developers | Unsafe and hard to explain |
| B | Capability-scoped source access | Least privilege, auditable | More permission design |
| C | No source access for packs in phase one | Safest | Weak plugin ecosystem |

Current recommendation: B for official packs, C for community/script packs until
the sandbox RFC lands.

Suggested permission vocabulary:

- `source.read.metadata`
- `source.read.text`
- `source.read.transcript`
- `attachment.read`
- `location.read`
- `memory.read`
- `memory.propose`
- `recap.read`
- `card.write`
- `insight.write`
- `todo.write`

High-risk permissions:

- raw transcript
- audio
- image/photo
- location
- health
- credentials/secrets
- broad filesystem
- arbitrary network
- background/continuous capture

## Decision Shortlist For User

These are the first choices likely worth product-owner confirmation:

1. Raw capture canonical store:
   - Recommendation: SQLite/Drift canonical rows plus revision/correction events;
     Markdown/JSONL export projection.
2. Event scope:
   - Recommendation: capture, raw edit/delete, agent outputs, Memory lifecycle,
     and audit events enter the append-only log; ordinary UI/cache state does
     not need full event sourcing.
3. Attachments:
   - Recommendation: files outside DB with stable ids, metadata, source refs,
     and hashes; EXIF/location export controlled.
4. Memory:
   - Recommendation: atomic Memory items/candidates are canonical; generated
     `Memory.md` is projection.
5. Derived artifacts:
   - Recommendation: cards/recaps/insights are text-first derived objects with
     small typed envelopes and source refs.
6. Backup vs export:
   - Recommendation: separate `Backup this device` from `Export my data`.
7. Owner export default:
   - Recommendation: default owner export includes raw captures, source
     materials, and readable records; derived outputs are included in labeled
     `derived/` folders or behind an option.
8. Provider secrets:
   - Recommendation: not included in Owner Export; included in full restorable
     Backup as secret-bearing user data with encryption or explicit warning.
9. Deleted/rejected data:
   - Recommendation: default readable export excludes rejected candidates and
     deleted/tombstoned objects; full archive/audit export can include them.
10. Plugin/source permissions:
   - Recommendation: capability-scoped access; raw transcript/audio/image/location
     are high-risk permissions.

## Confirmed Answers So Far

- Raw capture truth: SQLite/Drift object truth, not Markdown canonical storage.
- AI progressive disclosure: generated context packets/read models, not a
  user-visible Markdown vault.
- Markdown: optional export/developer/debug format; not ordinary user workflow.
- Embeddings/vector indexes: rebuildable indexes, not source truth.
- Attachments: source files on disk plus metadata/source refs.
- Derived cards, recaps, insights, and app outputs: durable derived objects with
  source refs, not original user facts.
- Backup: full restorable backup includes provider/model configs, selected
  defaults, pack state, settings, and credentials/secrets needed to restore a
  usable app.
- Owner Export: portable and safe by default; may include provider/model
  metadata, but excludes credentials/secrets.
- Context packets: important packets may be cached in SQLite as rebuildable
  derived state and invalidated by source/version/policy/generator inputs.
- Delete: default soft delete uses a 30-day recoverable window before purge;
  purge removes content and leaves minimal tombstone metadata.
- Events: SQLite object tables are canonical current state; append-only events
  are audit/routing/idempotency evidence, not full event-sourced truth.

## Remaining Decisions Before Detailed Technical Plan

These are the remaining product-owner decisions before moving from research
notes into a concrete technical plan.

1. Phase-one AI execution:
   - A. Local/on-device only
   - B. User-configured providers plus local-first storage
   - C. Official backend provider path
   - Recommendation: B for phase one; C later as optional service.
2. Phase-one retrieval:
   - A. FTS/BM25 and recency/entity signals first; embeddings optional
   - B. Embeddings required from day one
   - C. Pure raw chronological search
   - Recommendation: A.
3. Context packet persistence:
   - A. Generate on demand only
   - B. Cache generated packets and invalidate on source changes
   - C. Maintain a live Markdown vault
   - Recommendation: B for important surfaces, A for long tail, not C.
4. Audio/OCR processing:
   - A. On-device only
   - B. Provider optional; raw media saved first and provider output is derived
   - C. Cloud/provider required
   - Recommendation: B.
5. Deletion model:
   - A. Soft delete/tombstone by default; separate permanent purge
   - B. Immediate hard delete
   - C. User chooses every time
   - Recommendation: A.
6. Export phase-one scope:
   - A. Raw captures + attachments + manifest only
   - B. A plus JSONL objects and readable projection
   - C. Full archive including traces/prompts/internal logs
   - Recommendation: B; C only as advanced audit export later.
7. Todo tab phase-one behavior:
   - A. Visible tab with empty/enable-pack state
   - B. Hidden until Todo pack is enabled
   - C. Ship no Todo tab in phase one
   - Recommendation: A if product positioning needs Todo as a major tab; B if
     default app should feel record/memory-first.
8. Plugin marketplace phase one:
   - A. Official packs only, local catalog
   - B. Community/script packs allowed with capability warnings
   - C. Full marketplace
   - Recommendation: A.
9. Conversation write permissions:
   - A. Chat answers only; no writes
   - B. Chat can propose Memory/cards/todos through the same policy path
   - C. Chat can directly mutate data
   - Recommendation: B.
10. ADR scope:
   - A. One umbrella technical-plan RFC first
   - B. Separate ADRs now for storage, runtime, memory, packs, export
   - C. Start implementation first and backfill ADRs
   - Recommendation: A first, then split ADRs for decisions that become stable.

## Research Sources

Local reference snapshots:

- Memex: `/tmp/memex-main.xJjtdp`
- Omi: `/tmp/omi-main.NnJkl3`

External sources consulted:

- Local-first software: https://www.inkandswitch.com/essay/local-first/
- JSON Lines: https://jsonlines.org/
- SQLite JSON1: https://sqlite.org/json1.html
- W3C Activity Streams: https://www.w3.org/TR/activitystreams-core/
- W3C Web Annotation Data Model: https://www.w3.org/TR/annotation-model/
- Obsidian local Markdown positioning: https://obsidian.md/
- BagIt RFC: https://www.rfc-editor.org/rfc/rfc8493
- SQLite backup API: https://sqlite.org/backup.html
- SQLite VACUUM INTO: https://sqlite.org/lang_vacuum.html
- CouchDB tombstone/deletion model: https://docs.couchdb.org/
- Automerge: https://automerge.org/
- GraphRAG: https://arxiv.org/abs/2404.16130
- RAPTOR: https://arxiv.org/html/2401.18059v1
- OpenClaw Memory docs: https://docs.openclaw.ai/concepts/memory
- Reor local AI note app: https://github.com/reorproject/reor
- Memos Markdown-native notes: https://github.com/usememos/memos
- Logseq DB version: https://github.com/logseq/docs/blob/master/db-version.md
