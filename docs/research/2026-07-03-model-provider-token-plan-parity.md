# Model Provider Token Plan Parity

Date: 2026-07-03

Status: implementation note for the provider-settings phase-one slice

## Goal

Align WideNote's local-first model provider settings with MemeX's current BYOK
provider coverage while preserving WideNote-owned contracts, storage, labels,
and tests. The main addition is making domestic provider plan shape explicit:
users must be able to choose whether a provider entry uses a normal API key,
Token Plan, Coding Plan, or a local server.

## Clean-Room Reference

Reviewed MemeX as a product-flow and provider-shape reference only:

- `lib/domain/models/llm_config.dart`: provider list, default URLs, and adapter
  type grouping.
- `lib/data/services/model_list_service.dart`: model-list endpoint shapes and
  provider-specific filtering.
- `lib/ui/settings/widgets/model_config_edit_page.dart`: grouped provider
  picker, model fetch/test affordances, and custom endpoint handling.

WideNote keeps its own provider enum, local-db records, localization strings,
adapter code, widget structure, and tests. MemeX-only account flows such as
OAuth, Bedrock, and a hosted MemeX provider remain outside this BYOK slice
because they introduce account or cloud dependencies that are not part of
WideNote's default local-first product loop.

## Official Source Matrix

| Provider | WideNote preset shape | Official source |
| --- | --- | --- |
| OpenAI | Chat Completions and Responses presets share the OpenAI API key but route through different request builders. | [Responses API overview](https://developers.openai.com/api/reference/overview/), [Create response](https://developers.openai.com/api/reference/resources/responses/methods/create/) |
| DeepSeek | Separate OpenAI-compatible and Anthropic-compatible presets; Anthropic-compatible calls use `https://api.deepseek.com/anthropic` and bearer auth. | [DeepSeek Anthropic API](https://api-docs.deepseek.com/guides/anthropic_api), [DeepSeek first API call](https://api-docs.deepseek.com/) |
| Kimi | General OpenAI-compatible preset uses Moonshot Kimi API; coding preset uses the Kimi coding endpoint. | [Kimi API overview](https://platform.kimi.ai/docs/api/overview), [Kimi Code provider config](https://moonshotai.github.io/kimi-cli/en/configuration/providers.html) |
| Qwen | China and international OpenAI-compatible presets because Alibaba Cloud base URLs vary by region/workspace. | [Qwen OpenAI-compatible Chat](https://help.aliyun.com/en/model-studio/qwen-api-via-openai-chat-completions), [sub-workspace model calling](https://help.aliyun.com/zh/model-studio/model-calling-in-sub-workspace) |
| Doubao / Volcengine | General OpenAI-compatible Ark route plus Coding Plan route. | [Volcengine OpenAI compatibility](https://www.volcengine.com/docs/82379/1330626), [Volcengine tool integration](https://www.volcengine.com/docs/82379/2160841) |
| Zhipu / Z.AI | General API route plus GLM Coding Plan route. | [Z.AI API introduction](https://docs.z.ai/api-reference/introduction), [Z.AI Coding Plan quick start](https://docs.z.ai/devpack/quick-start), [Z.AI tool integration](https://docs.z.ai/devpack/tool/others) |
| MiniMax | Token Plan exposes OpenAI-compatible and Anthropic-compatible routes; message calls use bearer auth and Anthropic-compatible model listing keeps the documented `X-Api-Key` header. | [MiniMax Token Plan other tools](https://platform.minimax.io/docs/token-plan/other-tools), [MiniMax OpenAI API](https://platform.minimax.io/docs/api-reference/text-openai-api), [MiniMax Anthropic API](https://platform.minimax.io/docs/api-reference/text-anthropic-api), [MiniMax Anthropic List Models](https://platform.minimax.io/docs/api-reference/models/anthropic/list-models) |
| Xiaomi MIMO | Pay-as-you-go API and Token Plan are separate presets; official examples use the CN Token Plan base URL while the endpoint remains editable for account-specific values shown in the console. OpenAI-compatible and Anthropic-compatible routes use the `api-key` header. | [MIMO Token Plan tools overview](https://mimo.mi.com/docs/en-US/tokenplan/integration/tools-overview), [MIMO Token Plan FAQ](https://mimo.mi.com/docs/en-US/quick-start/faq/api-integration), [MIMO Anthropic API](https://mimo.mi.com/docs/en-US/api/chat/anthropic-api), [MIMO OpenAI API](https://mimo.mi.com/docs/en-US/api/chat/openai-api) |
| OpenRouter | OpenAI-compatible unified endpoint. | [OpenRouter quickstart](https://openrouter.ai/docs/quickstart) |
| Ollama | Local OpenAI-compatible server preset; API key optional. | [Ollama OpenAI compatibility](https://docs.ollama.com/api/openai-compatibility) |

## WideNote Decisions

- Add `ModelProviderAccessMode` with `api_key`, `token_plan`,
  `coding_plan`, and `local` wire names.
- Add `openai_responses` as a first-class provider kind so OpenAI Responses
  request and response shapes do not overload Chat Completions.
- Keep endpoints editable because official docs describe region, workspace, and
  plan-specific base URLs.
- Centralize header differences in model provider adapters instead of leaking
  them into UI code.
- Persist `access_mode` in local provider metadata payload and safe provider
  JSON without exposing raw credentials.
- Keep model-list fetch user-triggered; tests use injected fake/offline
  services.

## Validation Added

- Dart provider tests for access-mode serialization, Responses request parsing,
  MIMO `api-key` headers, DeepSeek/MiniMax Anthropic bearer handling, and MIMO
  Token Plan model-list derivation.
- Mobile widget tests for expanded provider preset picker coverage, token-plan
  persistence, no-key Ollama save, model fetch, connection tests, and dialog
  validation.

## Kimi Review

Kimi reviewed the implementation diff, this research note, the user request,
and the local validation summary in read-only mode. No secrets, credentials,
local databases, backup archives, or private records were included.

Findings and resolution:

- MIMO Token Plan presets should use the official, currently verifiable
  `token-plan-cn.xiaomimimo.com` examples instead of an SGP host. Resolved by
  changing the Settings presets, provider package tests, and the legacy
  `XiaomiMimoModelClient` default endpoint to the CN host. Endpoints remain
  editable for account-specific Token Plan values shown in the MiMo console.
- MiniMax Anthropic-compatible model listing uses `X-Api-Key`, which Kimi asked
  to re-check. Resolved by adding the official Anthropic List Models source to
  this matrix and keeping the adapter split: Bearer for message calls,
  `X-Api-Key` for that model-list endpoint.
- DeepSeek Anthropic Bearer auth, OpenAI Responses request/response mapping,
  and `access_mode` safe JSON were accepted as correct.
- Kimi flagged positional custom-preset fallback and CJK slug risks. Resolved
  by using explicit custom preset key lookup and falling back to the preset key
  when localized labels collapse to weak ASCII slugs such as `api`.

Remaining non-blocking follow-up:

- The provider dropdown is now long, and some protocol/plan differences appear
  late in the label. A later UX pass can split provider family and access mode
  into separate controls if narrow-screen usability becomes noisy.

Follow-up review:

- Kimi re-reviewed the MIMO CN endpoint change, MIMO/MiniMax header split,
  deterministic custom preset fallback, localized provider id fallback,
  `access_mode` persistence, localization keys, and added tests. It reported no
  remaining P0/P1 blockers.
