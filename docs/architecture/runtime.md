# Agent Runtime

WideNote needs its own runtime semantics, but not a heavy standalone agent engine in the first phase.

The product kernel owns:

- Event protocol
- Task protocol
- Agent Pack manifest
- Permission model
- Memory model
- Tool registry
- Trace and audit log
- Local runtime

External frameworks such as LangGraph, OpenAI Agents SDK, Mastra, Dify, n8n, Flowise, Inngest, Hatchet, Trigger.dev, and Temporal should be adapters or integration targets, not the product kernel.

## MVP Runtime

```text
SQLite / Drift event store
local task queue
Agent Pack registry
permission broker
tool registry
memory store
trace / audit log
local Dart agent executor
model provider adapters
```

## Event Semantics

- Events are append-only.
- Delivery is at least once.
- Handlers must be idempotent.
- External side effects require explicit permission.
- Raw captures must not be overwritten by AI output.
- Agent outputs are written as new events.

## Draft Event Shape

```yaml
Event:
  id: ulid
  type: wn.capture.created
  schema_version: 1
  actor: user | agent | plugin | system
  pack_id: optional
  agent_id: optional
  subject_ref: { kind, id }
  payload: json
  privacy: local_only | encrypted_sync | remote_allowed
  causation_id: optional
  correlation_id: optional
  device_id: string
  created_at: timestamp
```
