# Mobile Features

## Purpose

Feature-owned mobile UI slices for the WideNote skeleton.

## Ownership Boundary

Features may own presentation and temporary app-local controllers. Durable runtime contracts, persistence, model providers, permissions, and Agent Pack execution belong in shared packages or explicit integration layers.

## Dependencies

- Flutter Material
- `flutter_riverpod` where feature state is required

## Public Surface

- `capture`: home/records tab and fake capture state.
- `chat`: conversation list and input placeholder.
- `todos`: source-linked todo list placeholder.
- `plugins`: pack, permission, model, backup, and trace control entries.

## Generated Artifacts

None.
