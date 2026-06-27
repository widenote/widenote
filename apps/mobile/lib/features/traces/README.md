# Agent Console / Trace Feature

## Purpose

Shows the local Agent Runtime control surface for runs, tasks, approvals, and
trace events.

## Boundary

Owns the mobile Agent Console read model and presentation. It can inspect local
runtime task/run/trace records and render disabled retry/cancel controls when no
live runtime control provider is available. It must not own runtime execution,
task retry, cancellation, approvals persistence, or trace persistence.

Retry/cancel buttons must stay disabled until the mobile app has a real
RuntimeKernel control provider. The page should explain that limitation in UI
copy and never imply that a disabled control queued work successfully.

## Dependencies

- `apps/mobile/lib/app/local_database.dart`
- `packages/dart/local_db`

## Public Surface

- `TraceConsolePage`
- `traceConsoleControllerProvider`

## Generated Artifacts

None.
