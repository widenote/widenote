# Provider Presets Kimi Review

Date: 2026-07-01

## Scope

Kimi reviewed the model provider preset implementation with the current
WideNote worktree, repository docs, the active user request, and the local diff.
The review was read-only and excluded API keys, tokens, local databases, backup
archives, and private user records.

The implementation under review adds editable provider presets for OpenAI,
Anthropic Claude, Google Gemini, OpenRouter, DeepSeek, Kimi, Alibaba Qwen,
Volcengine Doubao, Zhipu GLM, MiniMax, Xiaomi MIMO, Ollama, and custom
compatible endpoints.

## External Documentation Checked

- OpenRouter documents `https://openrouter.ai/api/v1/chat/completions` as an
  OpenAI-compatible chat completions endpoint.
- DeepSeek documents OpenAI-format chat calls at
  `https://api.deepseek.com/chat/completions`.
- Kimi documents OpenAI-compatible calls with base URL
  `https://api.moonshot.ai/v1` and examples using `kimi-k2.6`.
- Alibaba Cloud Model Studio documents OpenAI-compatible Qwen access through
  compatible-mode base URLs.
- Google Gemini documents OpenAI-compatible chat completions at
  `https://generativelanguage.googleapis.com/v1beta/openai/chat/completions`
  and examples using `gemini-3.5-flash`.
- Volcengine Ark documents OpenAI SDK compatibility and
  `https://ark.cn-beijing.volces.com/api/v3` style base URLs.
- Z.AI documents OpenAI-compatible GLM access through
  `https://api.z.ai/api/paas/v4`.
- MiniMax documents Anthropic-compatible Messages at
  `https://api.minimax.io/anthropic/v1/messages` with bearer authorization.
- Anthropic's current model overview lists `claude-sonnet-5` as a Claude API
  model id.

## Kimi Findings And Resolution

Kimi agreed with the overall direction: provider presets are a thin product
layer over compatible adapters, and endpoint/model fields remain editable for
region, gateway, plan, and enabled-model differences.

Kimi flagged Gemini `gemini-3.5-flash` and Anthropic `claude-sonnet-5` as P0
invalid model ids. These were resolved as false positives after checking the
current official Gemini and Anthropic documentation. To reduce future drift
risk, the widget test now asserts Gemini, Anthropic, OpenRouter, DeepSeek, and
Kimi preset endpoint/model autofill values.

Kimi also flagged Kimi `.ai` versus `.cn` endpoint risk. The current official
Kimi docs use `https://api.moonshot.ai/v1`, so the default remains `.ai`.
The Settings helper text already tells users the endpoint is editable for other
regions or gateways.

Kimi's non-blocking follow-ups:

- Consider optional OpenRouter attribution headers in a later provider metadata
  pass.
- Consider provider-specific thinking controls for DeepSeek/Kimi in a later
  request-parameter design.
- Consider a real-device or simulator Settings pass before release-grade QA.

## Validation After Review

- `cd packages/dart/model_providers && dart analyze`
- `cd packages/dart/model_providers && dart test`
- `cd apps/mobile && NO_PROXY=localhost,127.0.0.1,::1 no_proxy=localhost,127.0.0.1,::1 ws_proxy= wss_proxy= flutter analyze`
- `cd apps/mobile && NO_PROXY=localhost,127.0.0.1,::1 no_proxy=localhost,127.0.0.1,::1 ws_proxy= wss_proxy= flutter test test/model_provider_settings_test.dart`
- `git diff --check`

Live-provider tests remain opt-in and are not required for this preset-only
slice.
