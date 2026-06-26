# W7 Current Integration State

Status: current phase-one integration state
Date: 2026-06-26
Supersedes-for-current-status:
`docs/research/2026-06-26-current-implementation-baseline.md`

## Current State

W7 is the current phase-one usable-state boundary. The mobile app has the
accountless local-first loop wired through the phase-one runtime host:

```text
capture
  -> local SQLite object truth and event evidence
  -> native Agent Pack/runtime outputs
  -> Memory, cards, insights, todos, recaps, chat context, traces
  -> Settings, safe backup/export, timeline/search/detail, and audit surfaces
```

The current implementation uses hand-written `sqlite3` DAOs for phase-one local
truth. Drift remains the long-term client data-layer target from ADR-0002, but
generated Drift tables are not the current implementation.

## Current Runtime Boundary

The mobile runtime now reads built-in Pack permissions from
`LocalDbPermissionStore` and writes task/run state through `LocalDbRuntimeStore`.
Default built-in permissions are seeded only when no user decision exists. A
later deny or revoke decision is not overwritten by capture startup and blocks
future Pack work while preserving the raw capture record.

Memory edits, deletes, and restores update object state and append lifecycle
event / trace evidence. Timeline Todo rows are rendered from the Todo object
state; `wn.todo.suggested` events remain provenance, not duplicate user-visible
Todo cards.

## Current Backup Boundary

Safe backup is the default implemented path. It restores local data and
provider metadata, but it does not export provider credential values. Safe
restore reports when provider keys must be re-entered.

Encrypted full backup is a follow-up capability. It may include provider
credentials only after a real encryption boundary exists. Do not describe W7 or
phase one as already supporting full provider-key restore.

Current restore rejects any `includes_secrets` or `encrypted_full` backup. Older
legacy backups that decode as secret-bearing are inspectable but not importable
in this build.

Owner Export is readable and secret-free by default. It is not the restore
source.

## Current Evidence

- `docs/research/2026-06-26-w7-integration-qa.md` is the current GO/NO-GO
  record for W7 integration.
- `docs/research/2026-06-26-w7-settings-privacy-qa.md` covers Settings and
  Privacy.
- `docs/research/2026-06-26-w7-backup-restore-qa.md` covers safe backup,
  restore reporting, and the encrypted-full-backup deferral.
- `docs/research/2026-06-26-w7-real-media-capture-qa.md` covers real media
  capture permission/cancel/error behavior.
