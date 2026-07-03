# Usage Stats Feature

## Purpose

Owns the host-rendered Settings dashboard for local runtime and input usage
statistics.

The feature summarizes recent local evidence across captures, Memory records,
runtime model traces, runtime tool traces, and context packet cache rows. It
keeps raw user records, raw prompts, tool inputs, and trace payloads out of the
dashboard and renders only aggregate counts, token totals, and reuse ratios.

## Ownership Boundary

- Owns mobile-only aggregation and presentation for `/settings/usage-stats`.
- Reads existing local object truth and trace records through `widenote_local_db`
  DAOs.
- Distinguishes provider-reported cached tokens from local context packet reuse.
- Does not mutate captures, Memory, traces, Pack installations, permissions, or
  context packet caches.
- Does not define public runtime contracts; the Pack manifest declares the
  host-rendered entry point.

## Dependencies

- Flutter Material
- `flutter_riverpod`
- `go_router`
- `apps/mobile/lib/app/local_database.dart`
- `packages/dart/local_db`

## Public Surface

- `application/usage_stats_controller.dart`
- `presentation/usage_stats_page.dart`

## Generated Artifacts

None.

## Related Context

- `packs/official/usage_stats/README.md`
- `docs/architecture/current-contracts.md`
- `docs/rfcs/agent-pack-schema.md`
