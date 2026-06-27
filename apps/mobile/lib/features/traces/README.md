# Log Center Feature

## Purpose

Shows local Agent Runtime log/trace events as a read-only audit surface.

## Boundary

Owns the mobile log-center read model and presentation. It must not own
runtime execution, task retry, cancellation, or trace persistence.

## Dependencies

- `apps/mobile/lib/app/local_database.dart`
- `packages/dart/local_db`

## Public Surface

- `TraceConsolePage`
- `traceConsoleControllerProvider`

## Generated Artifacts

None.
