# Dart Model Providers

## Purpose

Pure Dart model provider contracts, compatible adapter request builders, error
taxonomy, connection-test services, and deterministic fakes for WideNote.

This package gives tests, app wiring, and provider setup surfaces a shared
interface without depending on Flutter UI or real LLM services.

## Ownership Boundary

Owns provider-agnostic request and response models, provider configuration
models, capability metadata, compatible request/response adapters, official
model-list request helpers, fake HTTP, provider interface,
offline/adapter connection-test behavior, embedding provider HTTP contracts,
and fake provider behavior.

It must not own credential storage, network clients for real providers, model
setup UI, routing policy, or Agent Pack prompts.

## Public Surface

- `ModelProvider`
- `ModelRequest`
- `ModelResponse`
- `ModelUsage`
- `ModelMessage`
- `ModelCapability`
- `ModelProviderKind`
- `ModelProviderAccessMode`
- `ModelProviderConfig`
- `ModelProviderConfigValidation`
- `ModelProviderHttpClient`
- `FakeModelProviderHttpClient`
- `OpenAiCompatibleModelProvider`
- `OpenAiResponsesModelProvider`
- `AnthropicCompatibleModelProvider`
- `ModelProviderException`
- `ModelProviderConnectionTestService`
- `OfflineModelProviderConnectionTestService`
- `AdapterModelProviderConnectionTestService`
- `ModelProviderConnectionTestResult`
- `ModelProviderModelListService`
- `AdapterModelProviderModelListService`
- `ModelProviderModelListResult`
- `EmbeddingProvider`
- `EmbeddingProviderKind`
- `EmbeddingProviderConfig`
- `EmbeddingRequest`
- `EmbeddingResponse`
- `EmbeddingUsage`
- `OpenAiCompatibleEmbeddingProvider`
- `FakeModelProvider`
- `modelProviderFromConfig`
- `embeddingProviderFromConfig`
- `RuntimeModelClientAdapter`
- `RuntimeModelProviderException`
- `UnsupportedModelCapabilityException`

Provider presets currently cover OpenAI Chat Completions, OpenAI Responses,
Anthropic Claude, Google Gemini, OpenRouter, DeepSeek, Kimi, Alibaba Qwen,
Volcengine Doubao, Zhipu GLM, MiniMax, Xiaomi MIMO, Ollama, and custom
OpenAI-compatible or Anthropic-compatible endpoints. Vendor presets choose the
closest compatible adapter and remain editable in mobile Settings. Configs also
carry an access mode (`api_key`, `token_plan`, `coding_plan`, or `local`) so a
provider's subscription endpoint is not collapsed into a generic API-key
record.

Domestic vendor presets intentionally separate pay-as-you-go API endpoints from
Token Plan or Coding Plan endpoints when official docs describe distinct base
URLs or credentials. MiniMax and Xiaomi MIMO expose both OpenAI-compatible and
Anthropic-compatible Token Plan routes. Zhipu GLM and Volcengine Doubao expose
Coding Plan routes in addition to general API routes. Kimi keeps a general
Moonshot API preset and a Kimi coding endpoint preset. Alibaba Qwen keeps
China and international OpenAI-compatible presets because official base URLs
vary by region and workspace.

Safe provider JSON uses the public schema wire names from `packages/schemas`:
provider kinds such as `openai`, `deepseek`, `minimax`, and
`openai_compatible`, and capabilities such as `chat`, `completion`, and
`tool_use`. Parsers keep accepting the existing Dart enum names as
compatibility aliases while local persistence migrates.

Model-list support derives official provider model endpoints from the editable
base endpoint. OpenAI-compatible and Responses presets use `/models`,
Anthropic-compatible presets use `/v1/models`, and Gemini uses the native
`models` endpoint with the API key query parameter. The service returns model
IDs only; UI surfaces own selection, empty-state, and custom-model fallback
behavior.

The package also exposes an offline model-list service for deterministic
Flutter/widget tests. Production UI wiring uses the adapter service only after a
user taps the model refresh action. Provider-specific authentication differences
are centralized in the adapter helpers: Xiaomi MIMO uses `api-key` for
OpenAI-compatible and Anthropic-compatible requests, DeepSeek and MiniMax use
Bearer authorization for Anthropic-compatible message calls, and MiniMax model
listing keeps its documented `X-Api-Key` header.

Embedding provider contracts are separate from chat/completion provider
contracts. The default preset is OpenRouter with Qwen embedding model
`qwen/qwen3-embedding-0.6b`, but the API key, endpoint, batch size, and model id
are managed by the retrieval feature rather than the model-provider Settings
surface.

## Dependencies

Runtime dependencies:

- `packages/dart/agent_runtime`

This dependency exists only for `RuntimeModelClientAdapter`, which lets apps pass a `ModelProvider` into the runtime `ModelClient` contract without making the runtime depend on provider details.

This package does not depend on Flutter UI, backend services, real provider SDKs,
or the Memory package.

## Generated Artifacts

None. Future generated provider configuration contracts should point back to
`packages/schemas`.

## Tests

Run:

```sh
dart test
```

Current tests cover config validation, provider presets and access modes, fake
provider queued responses, fake HTTP recording, OpenAI-compatible, OpenAI
Responses, and Anthropic-compatible request construction, endpoint
normalization, response parsing, official model-list endpoint derivation and
parsing, connection-test success/failure classification, missing capability
errors, embedding request/response parsing, embedding config validation, and the
runtime adapter.

## Related Context

- `docs/architecture/phase-one-module-plan.md`
- `docs/architecture/phase-one-technical-plan.md`
- `docs/architecture/engineering-rules.md`
- `docs/rfcs/model-provider-settings.md`
