# Insight Depth Pack

## Purpose

Official model-backed pack for source-linked deep insights over recent local
WideNote state.

## Ownership Boundary

This pack owns generation of `wn.insight.created` events. It reads a bounded
local context packet through `insight.context.read`, calls the configured model,
and emits structured insight claims, metrics, evidence, counter-evidence, and
source refs.

It does not own raw capture records, Memory acceptance, cards, todos, chat
answers, archive/restore lifecycle, or backend execution.

## Runtime Behavior

- Automatic: subscribes to `wn.capture.created` after the default capture loop.
- Manual: subscribes to `wn.insight.requested`, emitted by the mobile Insights
  page when the user taps generate.
- Output: one rolling `wn.insight.created` event with `insight_id`
  `insight.depth.rolling`.
- Failure mode: if model, permission, context, or schema output is unavailable,
  the task fails closed and does not create a local lightweight fallback.

## Permissions

- `model.complete`
- `insight.write`
- `insight.context.read`
- `memory.read`
- `timeline.read`
- `knowledge.read`

## Related Decisions

- `docs/decisions/0020-accept-insight-depth-foundation.md`
- `docs/decisions/0022-drop-insight-archive-actions.md`
- `docs/research/2026-07-03-insight-depth-design.md`
