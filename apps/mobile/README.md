# Mobile App

## Purpose

Flutter mobile client and local runtime host.

Responsibilities:

- Quick capture
- Timeline and cards
- Local event store
- Local memory
- Local search
- Local Agent Runtime Kernel
- Permissions and trace review
- BYOK model provider configuration
- Settings and Privacy hub

## Ownership Boundary

The mobile app owns the immediate user experience, local persistence host, local runtime host, and platform integrations. Shared pure Dart logic should live under `packages/dart`.

The mobile app must not become the only source of truth for public Event, Memory, Agent Pack, Permission, Task, or Sync schemas.

## Public Surface

Initial public surfaces are the Flutter app entrypoint, platform integration boundaries, and local runtime wiring.

Current source layout:

- `lib/main.dart`: app process entrypoint, production bootstrap, and Riverpod scope.
- `lib/app`: app shell, theme, routing, and local database provider wiring.
- `lib/features`: feature-owned UI and app-local controllers.
- `lib/l10n`: Flutter localization resources and generated bindings.

The current client boots a device-local SQLite database at
`local-data/widenote.sqlite` and injects `LocalDbEventStore`,
`LocalDbTraceSink`, `LocalDbRuntimeStore`, `LocalDbPermissionStore`, and
`LocalDbMemoryRepository` into the local runtime by default. Built-in Pack
permissions are default-granted only when no user decision exists; later deny or
revoke decisions are read by the runtime and block future Pack work. Capture,
todo, Memory, card, insight, and trace read models hydrate from SQLite on
restart.

Full backup / restore is the implemented backup path. User-facing exports are
single `.widenote` compressed directory archives that contain a manifest, full
SQLite snapshot, and local capture media files. Import decompresses the archive
through a staging directory before restoring records, runtime evidence, Pack
state, permissions, provider metadata, and provider credential values. Treat
`.widenote` files as secret-bearing local artifacts. Legacy safe JSON and
Markdown projections remain package-level compatibility/export surfaces, not
the default mobile restore source; `encrypted_full` is reserved for a future
encrypted envelope.

## Dependencies

Allowed dependencies:

- `packages/dart/core`
- `packages/dart/local_db`
- `packages/dart/agent_runtime`
- `packages/dart/cards`
- `packages/dart/ui_blocks`
- `packages/dart/model_providers`
- `packages/schemas`

## Android Build Flavors

The Android app uses one release-channel flavor axis:

| Flavor | Android package | App label | Intended use |
| --- | --- | --- | --- |
| `dev` | `app.widenote.dev` | `WideNote Dev` | Local development and QA builds that can coexist with production. |
| `prod` | `app.widenote` | `WideNote` | Formal release builds. |

Run or build with an explicit flavor:

```sh
flutter run --flavor dev
flutter build apk --flavor prod --release
```

China/global market flavors are intentionally deferred. Add a market axis only
after store requirements, provider defaults, compliance, or distribution policy
make the split real.

## iOS Runner and Flavors

The iOS runner lives under `ios/` and is restored from Flutter's app template,
then lightly customized to match ADR-0008's release-channel model.

Source of truth:

- Flutter SDK app template
- `pubspec.yaml`
- `lib/main.dart`

Generation / repair command:

```sh
flutter create --platforms=android,ios --org app.widenote --project-name widenote_mobile --no-pub .
```

Manual customizations after template repair:

- Keep shared `dev` and `prod` schemes under
  `ios/Runner.xcodeproj/xcshareddata/xcschemes`.
- Keep `Debug-dev`, `Profile-dev`, `Release-dev`, `Debug-prod`,
  `Profile-prod`, and `Release-prod` Xcode build configurations.
- Keep `ios/Podfile` custom configuration mappings in sync with those
  configuration names.
- Keep `Runner/Info.plist` display name sourced from `APP_DISPLAY_NAME`.

| Flavor | iOS bundle id | App display name | Intended use |
| --- | --- | --- | --- |
| `dev` | `app.widenote.dev` | `WideNote Dev` | Local development and QA builds that can coexist with production. |
| `prod` | `app.widenote` | `WideNote` | Formal release builds. |

Simulator builds do not require Apple signing:

```sh
flutter build ios --simulator --debug --flavor dev
flutter build ios --simulator --debug --flavor prod
flutter run -d "iPhone 17" --flavor dev
```

The default `Runner` scheme is retained for template familiarity, but app
builds should use explicit `dev` or `prod` flavors.

Flutter plugin dependencies used by the app bootstrap:

- `path_provider`
- `sqlite3_flutter_libs`

Model access:

- The default mobile bootstrap uses saved provider settings when configured and
  otherwise surfaces model-required/model-unavailable states. It must not create
  local template summaries or answers when a model is missing.
- Provider settings use `packages/dart/model_providers` for config models,
  compatible adapter boundaries, and fake connection tests.
- Tests may override model providers with fake clients or opt-in live clients.
  Product app bootstrap must not read QA-only dart-defines as provider state.
- Opt-in live model QA can be run with
  `flutter test test/model_client_live_test.dart --dart-define=WIDENOTE_QA_MIMO_API_KEY=<key>`.
  The live test is skipped when the key is absent or when the remote endpoint
  returns HTTP 429.

## Generated Artifacts

Generated Flutter localization bindings live under `lib/l10n/generated`.

Source of truth:

- `lib/l10n/app_en.arb`
- `lib/l10n/app_zh.arb`
- `l10n.yaml`

Generation command:

```sh
flutter gen-l10n
```

Generated Flutter, Drift, localization, or platform files must document their source of truth and generator command here when introduced.

## Related Context

- `docs/architecture/technology-stack.md`
- `docs/decisions/0002-use-flutter-and-drift-for-client.md`
