# Dart Agent Runtime

## Purpose

Local Agent Runtime Kernel implementation for the Flutter client.

This package owns local event dispatch, task execution, permission checks, tool registration, and trace emission.

## Ownership Boundary

Owns local runtime execution. It must not own app UI, backend execution, or public schema definitions.

## Public Surface

- `WnEvent`, `WnEventDraft`, `SubjectRef`, `WnActor`, `WnPrivacy`, and `WnEventTypes` for append-only runtime events.
- `RuntimeKernel` for local event publication, subscription dispatch, task/run execution, and trace emission.
- `EventStore` and `InMemoryEventStore` for testable event persistence boundaries.
- `RuntimeStore` and `InMemoryRuntimeStore` for durable task, run, and pack-status boundaries.
- `TraceSink`, `RuntimeTrace`, and `InMemoryTraceSink` for audit traces.
- `PermissionBroker`, `PermissionStore`, and `InMemoryPermissionBroker` for explicit durable grant/deny/revoke checks.
- `ToolRegistry`, `ToolDefinition`, `ToolInvocation`, and `InMemoryToolRegistry` for permissioned local tools.
- `AgentPackManifestBridge`, `AgentPack`, `PackRegistry`, `AgentPackManifestSnapshot`, `Subscription`, `AgentDefinition`, `AgentHandler`, `AgentContext`, `ModelClient`, and `FakeModel` for manifest-aligned local pack loading and execution without a real LLM.
- `RuntimeTask`, `RuntimeRun`, `RetryPolicy`, and `RuntimePackStatus` for queued task/run inspection, retry, retry due time, dependency blocking, lease ownership, concurrency keys, cancellation, permission-denied, and pack status surfaces.

Runtime task/run JSON uses public schema run modes `read_only`, `confirm`, and
`auto`; the Dart enum keeps the native `RunMode.readOnly` name and maps it at
serialization boundaries.

Script runtime kinds are represented as manifest/runtime configuration only. The local kernel rejects them with a denied run until a sandbox RFC is accepted and implemented.

`RetryPolicy` defaults to two attempts for transient handler failures. Explicit
pack policies may set one to five attempts. Terminal schema, permission,
approval, unsupported-runtime, and cancellation failures fail closed without
auto-retry. Expired running runs/tasks recovered after an interrupted or
native-crash-like execution consume the same retry budget before becoming
failed.

## Dependencies

Runtime dependencies:

- `packages/dart/core`

Dev dependencies: `test`.

This package may later depend on generated schema bindings. It must not depend on Flutter UI, backend-private code, runner-private code, SQLite, Drift, or `packages/dart/local_db`.

Persistence adapters live below this package. For example, `packages/dart/local_db` may implement `EventStore` and `TraceSink`, but the runtime kernel must only know those interfaces.

## Generated Artifacts

None.

Generated runtime bindings must point back to `packages/schemas`.

## Tests

Run from this directory:

```sh
dart test
```

The main vertical slice test publishes `wn.capture.created`, dispatches a subscribed pack, creates a task/run, emits memory proposal, card, insight, and todo events through a fake handler/model, and verifies trace output. Queue tests also cover dependency ordering, default retry, retry backoff, retry exhaustion, cancellation, permission denial, durable restart-and-drain, stale running lease recovery for native-crash-like execution, dependency failure blocking, output event declaration failures, permission revocation gates, manifest/native pack alignment guardrails, atomic output append, trace redaction, tool-not-found, failure traces, and script-runtime rejection. No test needs a network connection or real API key.

## Related Context

- `docs/architecture/runtime.md`
- `docs/decisions/0003-build-agent-runtime-kernel.md`
