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
- `TraceSink`, `RuntimeTrace`, and `InMemoryTraceSink` for audit traces.
- `PermissionBroker` and `InMemoryPermissionBroker` for explicit pack/tool permission checks.
- `ToolRegistry`, `ToolDefinition`, `ToolInvocation`, and `InMemoryToolRegistry` for permissioned local tools.
- `AgentPack`, `Subscription`, `AgentDefinition`, `AgentHandler`, `AgentContext`, `ModelClient`, and `FakeModel` for local pack execution without a real LLM.
- `RuntimeTask`, `RuntimeRun`, `RetryPolicy`, and `RuntimePackStatus` for queued task/run inspection, retry, dependency, cancellation, permission-denied, and pack status surfaces.

Script runtime kinds are represented as manifest/runtime configuration only. The local kernel rejects them with a denied run until a sandbox RFC is accepted and implemented.

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

The main vertical slice test publishes `wn.capture.created`, dispatches a subscribed pack, creates a task/run, emits memory proposal, card, insight, and todo events through a fake handler/model, and verifies trace output. Queue tests also cover dependency ordering, retry, cancellation, permission denial, tool-not-found, failure traces, and script-runtime rejection. No test needs a network connection or real API key.

## Related Context

- `docs/architecture/runtime.md`
- `docs/decisions/0003-build-agent-runtime-kernel.md`
