# Usage Statistics Plugin And Kimi Review

Date: 2026-07-03

Status: implemented in first mobile slice

## Request

Add a plugin-style usage statistics feature inspired by MemeX runtime
observability. The dashboard should summarize input counts, input characters,
token usage, Memory output, tool calls, and cache behavior by day, week, and
Agent type. The entry should live under Settings for now.

## Review Inputs

- `docs/architecture/current-contracts.md`
- `docs/architecture/operational-principles.md`
- `apps/mobile/lib/features/settings/presentation/settings_page.dart`
- `apps/mobile/lib/app/app_router.dart`
- `packages/dart/agent_runtime/lib/src/kernel.dart`
- `packages/dart/local_db/lib/src/context_packet_builder.dart`
- `packages/dart/local_db/lib/src/daos_trace_events.dart`
- Existing official Pack manifests and mobile embedded manifest bridge

## Kimi Review Conclusions

Kimi agreed with the host-rendered official Pack direction, with three required
corrections before implementation:

1. The Settings Pack contribution could not rely on the existing tap behavior.
   Current settings contributions route to Pack Library, so Usage Statistics
   needed a host-owned route mapping to `/settings/usage-stats`.
2. Tool traces must be identified by `trace.name` or payload fields, not by the
   `trace_type` column alone. Current local DB trace type mapping does not store
   normal `runtime.tool.*` traces as a dedicated `tool` type.
3. Cache reporting must separate provider-reported cached input tokens from
   local context packet reuse. A single generic "cache hit rate" label would be
   misleading.

## Adopted Design

- Add `pack.usage_stats` as an official bundled Pack with no subscriptions,
  agents, tools, permissions, or output events.
- Declare a host-rendered `settings.pack_detail` / `panel` UI contribution.
- Add a Settings child route at `/settings/usage-stats`.
- Keep aggregation read-only and mobile-owned in
  `apps/mobile/lib/features/usage_stats`.
- Aggregate recent local evidence from:
  - captures: input count and input characters from `text` / `raw_text`
  - Memory items and candidates: generated Memory counts
  - model traces: provider/model token usage and estimated cost fields
  - tool traces: `runtime.tool.*` request/completion/failure counts
  - context packet tool results: `reused_cache` when available
  - context packet cache rows: active and invalidated local cache rows

## Non-Goals

- No new raw trace export.
- No model call, remote service, or background agent execution.
- No schema change to trace type mapping in this slice.
- No attempt to infer semantic Agent categories from natural-language content.
- No media transcript or OCR character counting beyond existing capture text
  fields.

## Validation Focus

- Widget coverage for Settings route entry and dashboard rendering.
- Aggregation coverage for token usage, tool calls, Memory counts, local context
  reuse, cache rows, weekly buckets, and the 90-day window.
- Pack manifest bridge and validator coverage for the new official Pack.
