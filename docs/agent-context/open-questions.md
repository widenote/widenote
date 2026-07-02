# Open Questions

These are current unresolved architecture topics. Accepted target-state rules
belong in `docs/architecture/current-contracts.md`, ADRs, RFCs, and module
READMEs; do not keep resolved decisions here.

- Context Packet public schema: source refs, progressive disclosure levels,
  cache invalidation keys, permission scopes, generator versioning, and when the
  schema graduates into `packages/schemas`.
- Deletion, purge, and sync-readiness: recoverable window UX, permanent purge
  semantics, minimal tombstone metadata, derived-output invalidation, and future
  sync conflict behavior.
- Backup/export split follow-ups: encrypted-envelope UX, hosted/sync backup
  policy, owner-export archive layout, and restore warnings beyond the default
  local secret-bearing `.widenote` full-backup path.
- Encrypted sync: object model, key management, device pairing, recovery, and
  attachment handling while preserving local-first source truth.
- Community/script runtime: JS/WASM/QuickJS options, sandboxing, store-edition
  limits, high-risk permission gates, and whether scripted packs can enter the
  bundled marketplace.
- Backend minimum version: which optional services belong in the first
  self-hosted bundle without making account, backend, sync, runner, or registry
  access a prerequisite for core use.
- Memory revision/history UX: whether accepted Memory needs a separate
  user-visible history table before sync, and how history interacts with
  tombstones, source refs, and derived-output invalidation.
