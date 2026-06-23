# Dart Agent Runtime

## Purpose

Local Agent Runtime Kernel implementation for the Flutter client.

This package owns local event dispatch, task execution, permission checks, tool registration, and trace emission.

## Ownership Boundary

Owns local runtime execution. It must not own app UI, backend execution, or public schema definitions.

## Public Surface

Future public surfaces include event dispatch APIs, task queue APIs, permission broker interfaces, tool registry APIs, and trace emission APIs.

## Dependencies

May depend on `packages/dart/core`, `packages/dart/local_db`, and generated schema bindings. Must not depend on backend or runner-private code.

## Generated Artifacts

Generated runtime bindings must point back to `packages/schemas`.

## Related Context

- `docs/architecture/runtime.md`
- `docs/decisions/0003-build-agent-runtime-kernel.md`
