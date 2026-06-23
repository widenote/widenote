# Dart Core

## Purpose

Core Dart models and pure runtime utilities.

This package should not depend on Flutter UI.

## Ownership Boundary

Owns pure Dart primitives that are shared by local runtime packages. It must not own app wiring, persistence migrations, or UI rendering.

## Public Surface

- `WnClock`, `SystemWnClock`, `FixedWnClock`, and `TickingWnClock` for runtime-neutral time access.
- `WnIdGenerator`, `MonotonicWnIdGenerator`, and `SequenceWnIdGenerator` for injectable ID generation.
- `WnResult` and `WnFailure` for small success/failure APIs without throwing as control flow.
- `JsonMap`, `JsonList`, and `immutableJsonMap` for lightweight JSON-shaped payloads.

## Dependencies

Runtime dependencies: none outside the Dart SDK.

Dev dependencies: `test`.

This package may later depend on generated schema bindings. It must not depend on Flutter packages or app-private code.

## Generated Artifacts

None.

Generated Dart models should normally come from `packages/schemas`, not this package.

## Tests

Run from this directory:

```sh
dart test
```

## Related ADRs or RFCs

- `docs/decisions/0002-use-flutter-and-drift-for-client.md`
- `docs/decisions/0003-build-agent-runtime-kernel.md`
