# Log Center / Trace Feature

## Purpose

Shows the local Agent Runtime log center for raw logs, runs, tasks, approvals,
and trace review.

## Boundary

Owns the mobile Log Center read model and presentation. It can inspect local
runtime task/run/trace records, including raw prompt/model/tool details stored
in local trace payloads, and render disabled retry/cancel controls when no live
runtime control provider is available. It must not own runtime execution, task
retry, cancellation, approvals persistence, or trace persistence.

Raw prompt and tool details are local user data. Console rendering may show
them, but credentials, media bytes, attachment paths, and safe export/external
review paths must still be redacted.

Retry/cancel buttons must stay disabled until the mobile app has a real
RuntimeKernel control provider. The page should explain that limitation in UI
copy and never imply that a disabled control queued work successfully.

## Dependencies

- `apps/mobile/lib/app/local_database.dart`
- `packages/dart/local_db`

## Public Surface

- `TraceConsolePage`
- `TraceRawLogsPage`
- `TraceEventsPage` legacy route compatibility alias
- `TraceAgentsPage`
- `TraceRawPage`
- `traceConsoleControllerProvider`
- `rawTraceViewModelProvider`

## Generated Artifacts

None.

## Related Context

- `docs/architecture/current-contracts.md`
- `docs/decisions/0016-restore-ready-logs-backups-and-asr.md`
