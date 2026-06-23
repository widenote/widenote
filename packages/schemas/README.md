# Schemas

## Purpose

Shared schema package for cross-runtime contracts.

Initial schema families:

- Event
- Memory
- Agent Pack manifest
- Permission
- Task
- Tool
- UI Block
- Sync object
- Trace

Generated Dart and TypeScript types should come from this package.

## Ownership Boundary

This package owns public runtime contracts. It should not own app-specific persistence tables, UI rendering details, or runner implementation logic.

## Public Surface

Future public surfaces include schema files, generated Dart types, generated TypeScript types, validation fixtures, and compatibility metadata.

## Dependencies

Schemas should remain implementation-light. Runtime packages may depend on schemas; schemas should not depend on runtime packages.

## Generated Artifacts

Generated outputs must point back to schema sources in this package. Humans should edit schema sources, not generated bindings.

When generation is introduced, document:

- Source schema path
- Generator command
- Dart output path
- TypeScript output path
- Validation command

## Related Context

- `docs/architecture/context-structure.md`
- `docs/architecture/runtime.md`
- `docs/decisions/0004-use-progressive-context-structure.md`
