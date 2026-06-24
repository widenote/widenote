# Trace Console Feature

## Purpose

Shows local Agent Runtime trace events as a read-only audit surface.

## Boundary

Owns the mobile trace-console read model and presentation. It must not own
runtime execution, task retry, cancellation, or trace persistence.

## Dependencies

- `apps/mobile/lib/app/local_database.dart`
- `packages/dart/local_db`

## Public Surface

- `TraceConsolePage`
- `traceConsoleControllerProvider`

## Generated Artifacts

None.
