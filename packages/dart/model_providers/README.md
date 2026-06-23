# Dart Model Providers

## Purpose

Pure Dart model provider contracts and deterministic fakes for WideNote.

This package gives tests, app wiring, and future provider adapters a shared interface without depending on Flutter UI or real LLM services.

## Ownership Boundary

Owns provider-agnostic request and response models, capability metadata, provider interface, and fake provider behavior.

It must not own credential storage, network clients for real providers, model setup UI, routing policy, or Agent Pack prompts.

## Public Surface

- `ModelProvider`
- `ModelRequest`
- `ModelResponse`
- `ModelUsage`
- `ModelMessage`
- `ModelCapability`
- `FakeModelProvider`
- `RuntimeModelClientAdapter`
- `RuntimeModelProviderException`
- `UnsupportedModelCapabilityException`

## Dependencies

Runtime dependencies:

- `packages/dart/agent_runtime`

This dependency exists only for `RuntimeModelClientAdapter`, which lets apps pass a `ModelProvider` into the runtime `ModelClient` contract without making the runtime depend on provider details.

This package does not depend on Flutter UI, backend services, real provider SDKs, or the Memory package.

## Generated Artifacts

None. Future generated provider configuration contracts should point back to `packages/schemas`.

## Tests

Run:

```sh
dart test
```

Current tests cover fake provider queued responses, request recording, missing capability errors, and the runtime adapter.

## Related Context

- `docs/architecture/phase-one-module-plan.md`
- `docs/architecture/phase-one-technical-plan.md`
- `docs/architecture/engineering-rules.md`
