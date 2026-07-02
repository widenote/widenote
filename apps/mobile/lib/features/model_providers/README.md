# Model Providers Feature

## Purpose

Owns the mobile settings surface for configuring local-first BYOK model
providers.

## Ownership Boundary

This feature owns app-local provider settings state, provider setup forms,
runtime-status presentation, default-provider selection, first-pass model-role
explanation, provider-settings page test status, the provider model picker, and
the mobile connection-test/model-list service wiring.

It does not own model routing policy, Agent Pack prompts, or durable provider
schemas. Shared provider contracts and compatible adapters live in
`packages/dart/model_providers`.

Connection tests are offline by default for deterministic local and CI runs.
Set `WIDENOTE_LIVE_PROVIDER_TESTS=live` as a Dart define to opt into the
injected Dart IO HTTP client and real compatible adapters. Saved API keys are
never printed; editing a provider keeps the saved key when the key field is
left blank, and the edit dialog can explicitly clear the saved key.

The add/edit dialog exposes common provider presets so most users can choose a
service, pick the right account plan, paste a key, and save. Presets include
OpenAI Chat Completions, OpenAI Responses, Anthropic Claude, Google Gemini,
OpenRouter, DeepSeek, Kimi, Qwen, Doubao, Zhipu GLM, MiniMax, MIMO, Ollama,
and custom compatible endpoints. Domestic providers with plan-specific
endpoints show separate pay-as-you-go API key, Token Plan, Coding Plan, or
local access tags. Endpoint fields remain editable for account-specific
regions, workspaces, and gateways.

The model field is a dropdown: users can fetch official provider model lists,
choose an available model, or fall back to a custom model id when a
gateway/account does not return the desired model. The same dialog also exposes
a user-triggered draft connection test before save; draft test status is
UI-only and is not persisted as provider configuration. Widget tests override
the model-list service with a deterministic offline/fake implementation; real
model-list requests are user-triggered only.

## Public Surface

- `application/model_provider_settings_controller.dart`
- `presentation/model_provider_settings_page.dart`

The settings page is intentionally layered as runtime status, model roles,
capabilities/privacy, then provider management. Per-Agent role overrides remain
deferred. Chat and model-backed runtime work require a configured provider;
local code should surface model-required/error states rather than
template-answer fallback. Opt-in live QA may override model providers with fake
or live test clients, but app bootstrap and Settings must not read QA-only
dart-defines as product provider state.

## Dependencies

- Flutter Material
- `flutter_riverpod`
- `packages/dart/model_providers`

## Generated Artifacts

None.

## Related Context

- `packages/dart/model_providers/README.md`
- `docs/rfcs/model-provider-settings.md`
- `docs/decisions/0016-restore-ready-logs-backups-and-asr.md`
- `docs/architecture/engineering-rules.md`
