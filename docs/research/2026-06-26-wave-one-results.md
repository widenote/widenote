# Wave One Results

Date: 2026-06-26
Status: complete

This records the first implementation wave after the phase-one umbrella plan
was accepted. The wave focused on contracts, runtime foundations, and local DB
durability before broad mobile UI changes.

## Coordinator Outcome

Wave one is ready for the next implementation wave.

- Shared schemas now cover runtime task runs, Context Packets, model providers,
  backup/export manifests, events, Memory, trace, and Agent Pack manifests.
- Agent Runtime now has durable-store ports, a pack registry, task idempotency,
  permission grant/deny/revoke behavior, output event validation, restart
  recovery, stale lease handling, and safer traces.
- Local DB now has schema v8 foundations for runtime tasks/runs, pack
  installations, permission grants, Context Packet cache, safe backup, encrypted
  full backup mode metadata, and Markdown projection boundaries.
- Mobile backup UI and widget tests now match the accepted backup decision:
  default export is safe and omits provider API keys. Encrypted full backup must
  not be exposed as plaintext UI.

## Worker Results

| Worker | Scope | Result |
| --- | --- | --- |
| Worker A | `packages/schemas/**`, `tools/pack_validator/**` | Contract schemas, fixtures, fixture runner, pack validator tests |
| Worker B | `packages/dart/agent_runtime/**` | Runtime ports, pack registry, permission store, idempotent task execution |
| Worker C | `packages/dart/local_db/**` | Durable runtime tables/DAOs, backup/export behavior, context cache, migrations |
| Coordinator patch | `apps/mobile/lib/features/backup/**`, l10n, widget tests | Aligned mobile safe backup UI with accepted product/security decision |

Each worker completed a sanitized Kimi review. Kimi found no hard blockers after
follow-up fixes. Remaining findings were carried into the next-wave risks below.

## Review Coverage

| Reviewer | Focus | Gate Applied |
| --- | --- | --- |
| Review A | Schemas/contracts edge cases | Fixtures, compatibility, drift, validation, redaction-safe Kimi input |
| Review B | Runtime/pack registry edge cases | Idempotency, permissions, output events, trace, restart and stale lease behavior |
| Review C | Local DB durable state edge cases | Migration, backup/import, permission state, context cache, secret boundary |

## Validation Run

Schema and pack validation:

```sh
node packages/schemas/validate_fixtures.mjs
node tools/pack_validator/validate_test.mjs
node tools/pack_validator/validate.mjs packs/official/default/manifest.json packs/official/todo/manifest.json
```

Dart package validation:

```sh
cd packages/dart/agent_runtime && dart analyze && dart test
cd packages/dart/local_db && dart analyze && dart test
cd packages/dart/memory && dart test
cd packages/dart/model_providers && dart test
```

Mobile validation:

```sh
cd apps/mobile && flutter analyze
cd apps/mobile && env -u ws_proxy -u wss_proxy NO_PROXY=localhost,127.0.0.1,::1 no_proxy=localhost,127.0.0.1,::1 flutter test test/backup_page_test.dart test/i18n_widget_test.dart
cd apps/mobile && env -u ws_proxy -u wss_proxy NO_PROXY=localhost,127.0.0.1,::1 no_proxy=localhost,127.0.0.1,::1 flutter test test/capture_orchestrator_test.dart test/plugins_page_test.dart test/trace_console_page_test.dart test/backup_page_test.dart test/model_provider_settings_test.dart
```

Repository whitespace validation:

```sh
git diff --check
```

All commands above passed in this wave.

## Environment Note

Flutter widget tests initially failed with:

```text
Unable to connect to flutter_tester process: WebSocketException: Invalid WebSocket upgrade request
```

The failure was caused by `ws_proxy` / `wss_proxy` proxy environment variables.
Mobile Flutter tests should unset those variables and set localhost `NO_PROXY`
until the local shell environment is cleaned up.

## Remaining Risks

- Runtime kernel has ports for durable stores, but mobile/local_db adapters still
  need to connect those ports to SQLite DAOs.
- Official Agent Pack manifests validate, but mobile capture still needs a
  manifest-driven registry bridge before hardcoded pack behavior can be retired.
- Context Packet schema and local cache exist, but the builder, cache key policy,
  and progressive disclosure integration still need implementation.
- Encrypted full backup is represented at the local DB contract layer, but
  mobile must not expose full secret backup until encryption and restore UX are
  wired.
- Soft delete defaults are documented as a 30-day recoverable window, but purge
  scheduling and user-visible recovery flows need the next implementation wave.

## Next Wave Candidates

1. Runtime/local_db adapter worker: implement durable `RuntimeStore` and
   `PermissionStore` adapters over local DB DAOs.
2. Pack registry/mobile bridge worker: load official manifests into runtime and
   align mobile pack catalog with manifest metadata.
3. Context Packet worker: build the first source-linked packet builder and
   cache invalidation flow.
4. Backup encryption worker: add encrypted full backup UX and restore behavior,
   keeping safe backup as the default.
