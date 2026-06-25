# Model Providers Feature

## Purpose

Owns the mobile settings surface for configuring local-first BYOK model
providers.

## Ownership Boundary

This feature owns app-local provider settings state, provider setup forms,
runtime-status presentation, default-provider selection, first-pass model-role
explanation, provider-settings page test status, and the mobile connection-test
service wiring.

It does not own model routing policy, Agent Pack prompts, or durable provider
schemas. Shared provider contracts and compatible adapters live in
`packages/dart/model_providers`.

Connection tests are offline by default for deterministic local and CI runs.
Set `WIDENOTE_LIVE_PROVIDER_TESTS=live` as a Dart define to opt into the
injected Dart IO HTTP client and real compatible adapters. Saved API keys are
never printed; editing a provider keeps the saved key when the key field is
left blank, and the edit dialog can explicitly clear the saved key.

## Public Surface

- `application/model_provider_settings_controller.dart`
- `presentation/model_provider_settings_page.dart`

The settings page is intentionally layered as runtime status, model roles,
capabilities/privacy, then provider management. Per-Agent role overrides remain
deferred; current built-in agents inherit the default provider or the local
deterministic fallback.

## Dependencies

- Flutter Material
- `flutter_riverpod`
- `packages/dart/model_providers`

## Generated Artifacts

None.

## Related Context

- `packages/dart/model_providers/README.md`
- `docs/rfcs/model-provider-settings.md`
- `docs/architecture/engineering-rules.md`
