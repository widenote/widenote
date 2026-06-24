# Mobile Features

## Purpose

Feature-owned mobile UI slices for the WideNote skeleton.

## Ownership Boundary

Features may own presentation and temporary app-local controllers. Durable runtime contracts, persistence, model providers, permissions, and Agent Pack execution belong in shared packages or explicit integration layers.

## Dependencies

- Flutter Material
- `flutter_riverpod` where feature state is required

## Public Surface

- `capture`: home/records tab, quick capture state, Memory review surface, and
  source-linked card/insight previews.
- `chat`: local sessions, messages, deterministic assistant, source-linked
  context, and retry UI.
- `todos`: source-linked todo list.
- `backup`: local JSON backup export/import surface backed by local DB.
- `plugins`: pack, permission, model, backup, and trace control entries.
- `model_providers`: provider setup, fake connection tests, and default-provider
  local state.

## Generated Artifacts

None.
