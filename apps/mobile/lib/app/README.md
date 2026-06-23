# App Shell

## Purpose

Owns the Flutter application root, Material theme, and top-level tab routing.

## Ownership Boundary

This module composes feature pages but does not own feature state, persistence, schemas, or runtime behavior.

## Dependencies

- Flutter Material
- `go_router`

## Public Surface

- `WideNoteApp`
- `appRouter`
- `WideNoteShell`

## Generated Artifacts

None.
