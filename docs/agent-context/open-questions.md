# Open Questions

These are the next architecture topics that need deeper design.

- Umbrella technical-plan RFC: object boundaries, lifecycle diagrams, schema
  proposals, Agent Pack boundaries, UI read models, and validation gates.
- Context packet schema: source refs, progressive disclosure levels, cache
  invalidation keys, permission scopes, and generator versioning.
- Backup/export split: encryption UX, restore warnings, provider/model config
  metadata, secret-bearing backup handling, and owner export archive layout.
- Deletion and purge: 30-day recoverable window UX, permanent purge semantics,
  minimal tombstone metadata, and future sync conflict handling.
- Memory data model: types, provenance, confidence, editing, deletion, and invalidation.
- Encrypted sync: object model, key management, device pairing, recovery, and attachment handling.
- Agent Pack schema: manifest shape, versioning, permissions, subscriptions, tools, UI blocks, and compatibility.
- Script plugin runtime: JS/WASM/QuickJS options, sandboxing, store edition limits, and community edition behavior.
- Backend minimum version: which services belong in the first self-hosted bundle.
- Store and community edition split: high-risk inputs, dynamic UI, scripting, and distribution.
