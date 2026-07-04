# Agent Status

## Purpose

Shows the current local Agent execution status as a lightweight mobile surface.
The in-app floating layer is intentionally transient: active Agent work stays
visible, terminal work appears only for a short completion window, and idle
state does not reserve screen space.

## Ownership Boundary

This feature reads local runtime task and run rows and projects them into:

- a global in-app floating status layer
- a detail sheet for current and recent task state
- a privacy-safe platform status payload for iOS notifications and Live
  Activities

It does not execute, retry, cancel, enqueue, or mutate runtime work. Durable
runtime truth stays in `packages/dart/agent_runtime` and
`packages/dart/local_db`; raw traces stay in the Log Center.

Platform status payloads must not include user record text, model output, raw
trace payloads, media bytes, local file paths, provider credentials, or secret
values. Native payloads include only aggregate counts, localized status text,
coarse status names, and timestamps. Dart-only sync keys may consider task
identity to avoid duplicate platform updates, but those IDs must not be sent
over the platform channel.

## Dependencies

- `apps/mobile/lib/app/local_database.dart`
- `packages/dart/local_db`
- Flutter Material and `flutter_riverpod`

## Public Surface

- `application/agent_execution_status_controller.dart`
- `application/agent_status_platform.dart`
- `presentation/agent_execution_status_overlay.dart`

## Generated Artifacts

None.

## Related Context

- `docs/architecture/current-contracts.md`
- `docs/architecture/operational-principles.md`
- `apps/mobile/lib/features/traces/README.md`
