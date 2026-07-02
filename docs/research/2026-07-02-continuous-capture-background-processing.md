# Continuous Capture Background Processing

Date: 2026-07-02

Status: implementation evidence

## Problem

The mobile capture UI locked new input while the previous record was still
running transcription, runtime packs, model Memory proposal, cards, insights,
todos, and trace generation. This made slow model processing feel like a block
on basic recording.

## Reference Evidence

- Omi keeps capture separate from later processing. Its public overview frames
  phone, Mac, and wearable capture as hands-free or ambient input while Omi
  handles transcription, Memory, summaries, and tasks in the background. Its
  backend listen/pusher pipeline also buffers pending processing requests while
  the pusher is unavailable and replays them after reconnect.
- Memex keeps the user-facing recording flow non-blocking. Its public product
  writing describes a first card appearing quickly while deeper knowledge filing
  takes longer, and the user can keep recording while the pipeline continues in
  the background. Code inspection showed a global event bus, local task
  executor, queue drain scheduler, background worker, foreground task tracker,
  and activity service boundary.
- Memex PR #281 (`fix: 收敛卡片生成失败状态`) showed a crash-loop edge:
  ordinary handler failures can be caught and retried in Dart, but native
  crashes may bypass handler cleanup. Its queue recovery records execution
  markers, distinguishes graceful exit from crash-like restart, and eventually
  marks repeatedly crashing work failed so UI recovery and downstream state
  converge instead of crashing forever.
- Kimi review recommended a three-layer split: immediate raw persistence,
  local read-model/index update, and asynchronous smart processing. For the
  first WideNote slice, it recommended a Memex-like discrete-record queue
  rather than an Omi-style continuous voice session, per-record status,
  dedupe-by-record-id, per-record retry, and backlog/error visibility.

## Product Decisions

- Users must be able to continue recording while previous records are still
  processing.
- WideNote should maintain a queue for capture processing and use Memex as the
  primary first-slice reference.
- Single-record retry is allowed after processing failure.
- A processing record can appear immediately as the user-visible placeholder.
- Background processing must still run the complete model/runtime pipeline; it
  must not replace model work with a local shortcut.
- Not every capture has to create Memory. If no Memory proposal is produced by
  a legitimate processing path, the raw record and derived cards/insights can
  remain without fabricating Memory.
- Pending records cannot be edited or deleted in this slice. Editing/deletion
  remains a post-processing follow-up.
- Cross-record consistency and reflow are deferred.

## Implemented Slice

- Capture submission now saves the raw local capture row first, updates the
  home read model immediately, and enqueues processing through durable runtime
  tasks.
- The UI no longer disables text input, new record, or background voice actions
  only because capture processing is running.
- Processing rows show a pending status and progress affordance. Failed rows
  expose a per-record retry action.
- Timeline reads local capture rows first, so saved-but-unprocessed records
  appear before the runtime event is created.
- On app/controller rebuild or short background drain, pending captures and
  runtime tasks restore from local DB. Task claim, dependency checks, retry
  due time, lease ownership, stale running recovery, and concurrency limits are
  durable queue behavior.
- The orchestrator treats missing Memory proposals as a valid no-Memory result
  only when the default capture agent did not fail; default model/agent failure
  remains a failed capture that can be retried.
- Completed capture rows persist `memory_generated` so no-Memory completion is
  part of local object truth rather than a transient return value.

## Follow-Ups

- Add cross-record consistency, Memory/card reflow, and backlog controls once
  multiple queued records can influence each other.
- Add edit/delete flows for processed records with source-truth safeguards.
