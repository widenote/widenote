# Mobile Features

## Purpose

Feature-owned mobile UI slices for the WideNote phase-one mobile runtime.

## Ownership Boundary

Features may own presentation and temporary app-local controllers. Durable runtime contracts, persistence, model providers, permissions, and Agent Pack execution belong in shared packages or explicit integration layers.

## Dependencies

- Flutter Material
- `flutter_riverpod` where feature state is required

## Public Surface

- `capture`: home/records tab, quick capture state, Memory review surface, and
  source-linked card/insight previews.
- `timeline`: local browse, search, card detail, item detail, and source-ref
  inspection for captures, cards, insights, Memory, and todos.
- `recap`: Daily Recap second-level page built from local object truth.
- `memory`: accepted Memory list, edit, tombstone delete, restore, and source
  metadata.
- `chat`: local sessions, messages, provider-backed assistant bridge,
  source-linked context, model-required failure states, and retry UI.
- `todos`: source-linked todo list.
- `settings`: Settings / Privacy hub for permissions, model providers,
  backup/restore, trace console, and display status.
- `backup`: safe local JSON backup export/import and human-readable Markdown
  export surface backed by local DB.
- `plugins`: pack, permission, model, backup, and trace control entries.
- `model_providers`: provider setup, fake connection tests, and default-provider
  local state.
- `traces`: read-only local Agent Runtime trace console.

## Generated Artifacts

None.
