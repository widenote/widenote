# ADR-0018: Accept Durable Agent Work Queue

Status: accepted

Date: 2026-07-02

## Context

ADR-0017 accepted continuous capture: saving a record must not block the next
record while model-backed processing runs. The first implementation used a
mobile-controller FIFO to prove the UX, but that shape is not enough for
Memex-style agent work:

- multiple saved records should process concurrently when safe;
- dependent agents must wait for prerequisite agents and block when a
  prerequisite terminally fails;
- retry and backoff must survive app rebuilds and short OS background runs;
- interrupted or native-crash-like runs must not re-crash forever on startup;
- old workers must not overwrite newer task claims or duplicate derived output.

## Decision

- Runtime task execution is backed by durable local task rows, not only an
  in-controller FIFO.
- Task claim is the local database's scheduling boundary. Claim checks status,
  retry due time, dependency success, active lease capacity, and concurrency
  key conflicts in one transaction.
- Running tasks carry a lease owner and expiry. Completion writes use the
  current lease owner; output append is skipped if the lease is gone.
- Handler failures default to two attempts. Packs may explicitly set
  `retry_policy.max_attempts` from 1 to 5. Terminal schema, permission,
  approval, unsupported-runtime, and cancellation failures are not auto-retried.
- Stale running runs or tasks recovered after lease expiry use the same retry
  budget as handler failures. If retry budget remains, the task returns to the
  queue with backoff; if it is exhausted, the task becomes failed so dependent
  work blocks instead of entering a startup crash loop.
- The default capture queue allows four concurrent work slots. Agent-level
  `concurrency_key` can serialize shared-resource work inside that global cap.
- `depends_on` may point to a subscription in the same pack or to a fully
  qualified external subscription such as
  `pack.default::sub.capture_created`.
- Official todo and PKM capture projections depend on the default capture
  loop. If the default capture task terminally fails, those downstream tasks
  block instead of producing partial independent output.
- Capture retry first retries the failed default capture task for that record.
  Republish of a new `wn.capture.created` is fallback for old or pre-runtime
  records that do not have a task mapping.
- OS background processing uses short drains of already-persisted pending
  captures and runtime tasks. It does not introduce background recording,
  background location, or long-lived runner semantics.

## Consequences

- UI activity is an aggregate over saved records and runtime work, not a global
  input lock.
- Capture event and trace attribution must be by capture subject, causation,
  source references, task ids, and run ids. Global "events since last count"
  slicing is not valid under concurrent processing.
- Retry backoff may leave a failed task queued for a future due time. Downstream
  tasks remain waiting until the prerequisite succeeds or terminally fails.
- A native crash before Dart cleanup increments the attempt at claim time, so
  repeated crash recovery is bounded by the task's max attempts.
- Workmanager/BGTask execution is best-effort. The durable local queue is the
  correctness boundary; OS scheduling is only a drain trigger.
- Background drains process only already-saved, ready inputs. Voice ASR and
  other microphone-bound work remain foreground/resume work until a separate
  permission and platform ADR accepts it.

## Alternatives Considered

- Keep the controller FIFO as the execution source. Rejected: it cannot model
  dependencies, durable retry, or multi-worker claim safety.
- Let each pack process capture events independently. Rejected for default
  capture-derived packs because partial output after core capture failure is
  misleading.
- Build a hosted runner now. Rejected: phase-one local-first usage must not
  require an account or official backend.

## References

- `docs/decisions/0017-accept-continuous-capture-background-processing.md`
- `docs/research/2026-07-02-continuous-capture-background-processing.md`
- `docs/architecture/current-contracts.md`
