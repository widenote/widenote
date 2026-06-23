# Dart Local DB

## Purpose

Drift and SQLite data layer for local-first storage.

This package owns local tables, migrations, and query APIs.

## Ownership Boundary

Owns local persistence and migrations. It must not own public protocol semantics or UI rendering.

## Public Surface

Future public surfaces include Drift database classes, DAOs, migration APIs, and local query APIs.

## Dependencies

May depend on `packages/dart/core` and generated schema bindings. Must not depend on Flutter UI.

## Generated Artifacts

Drift-generated files must document their source `.drift` or Dart table definitions and generation command when introduced.

## Related Context

- `docs/decisions/0002-use-flutter-and-drift-for-client.md`
