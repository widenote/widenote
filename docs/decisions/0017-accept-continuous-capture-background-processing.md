# ADR-0017: Accept Continuous Capture Background Processing

Status: accepted

Date: 2026-07-02

## Context

WideNote's default loop starts with quick capture. If the app blocks the next
record while model-backed processing is still running, the product feels like a
slow AI form rather than a local-first record tool.

Omi and Memex both separate capture from later intelligence work. Omi's capture
surfaces can continue collecting audio or context while transcription and
Memory work happen behind the scenes. Memex's discrete journal flow saves input,
shows early activity, and drains local agent tasks in the background.

WideNote needs the same product boundary while preserving its own contracts:
raw records are source truth, AI outputs are derived, and model-backed capture
processing must not be silently replaced by local heuristics.

## Decision

- Quick capture persists the raw local record before model-backed processing.
- Capture processing runs through a queued background path after persistence.
  The queue is FIFO for the first mobile slice.
- The UI must allow additional text, attachment, or voice records while earlier
  records are still processing.
- Pending records are visible immediately as processing rows/cards in Home and
  Timeline.
- Processing failure preserves the raw record and exposes per-record retry.
- Retry reruns the full capture processing path for that record. It must not
  fabricate Memory, cards, insights, or todos locally.
- A completed capture may have no Memory when no valid Memory proposal is
  produced by the processing path. The app should not invent Memory just to fill
  the section. The local capture payload records whether Memory was generated.
- Default capture-agent or model failure is still a failed capture, not a
  successful no-Memory result.
- Pending records cannot be edited or deleted in this slice; those actions wait
  for a processed or failed state.
- Cross-record consistency and reflow are deferred.

## Consequences

- `CaptureState.isProcessing` is a background activity signal, not a global
  input lock.
- Timeline and Home must read local capture rows, not only processed runtime
  events, so saved pending records remain visible.
- The first implementation can use an in-controller FIFO queue backed by local
  capture status and restore pending work on controller rebuild. ADR-0018
  extends this into durable local runtime task claim, retry, concurrency, and
  short OS background drain semantics.
- Tests must cover continuous input while processing, per-record retry, and
  pending captures appearing before runtime events.
- Memory counts can lag capture counts by design because Memory is a derived
  output, not a mandatory mirror of each source record.

## Alternatives Considered

- Keep the global processing lock. Rejected: it makes slow model work block the
  primary capture loop.
- Mark records processed immediately and fill derived output later. Rejected:
  it hides pending work and makes retry/error handling ambiguous.
- Generate a local fallback Memory when model processing fails or emits no
  proposal. Rejected: WideNote delegates semantic Memory selection to governed
  model/runtime paths.
- Build full OS-level background isolates and durable task claiming in this
  slice. Deferred: the first product fix only needs foreground-session
  continuous recording plus local-status restoration.

## References

- `docs/research/2026-07-02-continuous-capture-background-processing.md`
- `docs/decisions/0018-accept-durable-agent-work-queue.md`
- `docs/architecture/current-contracts.md`
