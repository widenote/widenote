# RFC: Model Provider Settings

Status: Accepted phase-one slice; amended by W7 safe-backup and QA-injection boundaries

## Summary

WideNote phase one needs user-facing model provider setup instead of a QA-only
model client path. The first product slice adds local provider configuration,
compatible adapter contracts, fake connection tests, and default-provider
selection without requiring an official backend or real service keys.

## Motivation

Model access is a phase-one product surface because Agent Packs, chat, Memory,
and custom agents need a clear BYOK boundary. The app must remain usable offline
and must not treat live provider credentials as a CI or default runtime
requirement.

## Goals

- Represent OpenAI-compatible, Anthropic-compatible, and common provider
  presets with shared config models. Current presets cover OpenAI, Anthropic
  Claude, Google Gemini, OpenRouter, DeepSeek, Kimi, Alibaba Qwen, Volcengine
  Doubao, Zhipu GLM, MiniMax, Xiaomi MIMO, Ollama, and custom compatible
  endpoints.
- Keep provider adapters testable with fake HTTP.
- Classify auth, rate limit, timeout, server, network, malformed-response, and
  missing-text failures.
- Provide a mobile settings page for add, edit, test connection, and default
  provider selection.
- Preserve local model-call trace metadata for BYOK users, including
  provider/model ids, token usage when providers expose it, retry/failure state,
  and future cost fields without persisting API keys or raw private prompts.
- Keep real credentials out of repository files, fixtures, logs, generated
  docs, and automated review prompts.
- Safe local backups exclude provider API key values by default. Encrypted full
  backup is the future path for secret-bearing restore portability and is not
  implemented in the W7 phase-one state.

## Non-goals

- Real live-provider tests in CI.
- Per-agent model role routing.
- A full billing ledger or provider-pricing engine. Runtime trace metadata may
  store provider-exposed token/cost fields when available.
- Runtime model bootstrap from QA-only dart-define values. Live QA may inject a
  model client through test overrides, but product runtime reads saved provider
  settings only.

## Proposed Design

`packages/dart/model_providers` owns provider config models, preset defaults,
compatible request builders, fake HTTP, fake providers, and a shared error
taxonomy. Adapters are constructed with an injected HTTP client so tests can
assert request shape without external network access. Provider presets are
thin defaults over the compatible adapters; endpoint and model fields remain
editable because accounts can differ by region, gateway, plan, or enabled
model id.

`apps/mobile/lib/features/model_providers` owns the first mobile settings
surface. Providers can be added, edited, tested with a fake connection service,
selected as default, and persisted locally for app restarts and backup/restore.

The plugin control page links to the settings page. A later settings-home
integration can move or duplicate this entry without changing provider package
contracts.

The mobile settings page is organized as:

1. Runtime model access status, showing whether a default provider is active or
   whether model-backed work currently requires configuration.
2. Model roles, showing the default text-model role and making clear that
   per-Agent overrides are deferred.
3. Capabilities and privacy, explaining BYOK local storage, user-initiated
   connection tests, and local raw-capture availability.
4. Provider management, preserving add, edit, default selection, preset
   selection, and connection test actions.

This hierarchy is based on clean-room product-flow review of public model setup
patterns, including `memex-lab/memex`, but the implementation, labels, storage
model, and runtime semantics remain WideNote-owned.

## Data Model / API / UX

The package-level config includes:

- stable provider id
- provider kind
- display name
- endpoint URI
- model id
- max output tokens
- capability set
- runtime credential value

Safe metadata exports expose only whether a credential is present. User-managed
safe backup exports preserve provider metadata and default-provider state, but
exclude credential values. Encrypted full backup may include credentials only
after a real encryption boundary exists.

## Privacy and Security Impact

Provider credentials are durable local values in this slice. They must not be
printed by `toString`, included in safe JSON, committed to tests, written to
docs, stored in generated artifacts, or sent to automated review prompts.
Encrypted full backup is the explicit future exception and must be treated as
secret-bearing user data once implemented.

## Local-first and Sync Impact

The feature does not require an account, backend, or live network service. Sync
is unaffected. Current safe backup/export restores provider metadata without
API key values, so restored devices must ask the user to re-enter provider keys.
Encrypted full backup is the later path for restoring credentials.

## Agent / Plugin Impact

This RFC creates the provider settings foundation for Agent Pack model access.
Per-agent role selection and model routing remain follow-up work and should use
public schemas rather than app-private tables.

Until per-agent routing lands, Chat and model-backed Agent Pack work inherit
the default provider when one is configured. Without a configured provider,
model-backed work must surface a model-required/model-unavailable state instead
of a local template answer. Core capture still preserves raw records locally.
Runtime traces should make model calls inspectable for BYOK users without
recording prompt text or credential values.

Transient live-model QA is a test harness concern. A dart-define such as
`WIDENOTE_QA_MIMO_API_KEY` may be read by opt-in tests and used to override the
Riverpod model providers in that test process. Settings and app bootstrap must
not interpret that define as a configured user provider, display it as provider
state, or route product model calls through it.

## Alternatives

- Keep only the QA MIMO path. This blocks BYOK product use and hides provider
  setup from users.
- Implement real SDK clients immediately. This adds dependency and credential
  risk before the local settings model is stable.
- Exclude provider credentials from backup. This would make provider restore
  incomplete, but W7 accepts that tradeoff for safe backup until encrypted full
  backup exists.

## Migration / Compatibility

The existing MIMO test client remains available for opt-in live tests through
test-time provider overrides. Dev and production app bootstrap do not read
QA-only model dart-defines. `packages/dart/local_db` stores provider metadata,
API keys, and default-provider state locally. Safe backup omits API key values
and reports that keys need re-entry after restore.

## Open Questions

- Whether a future secure-storage abstraction can preserve full
  user-managed backup/restore semantics.
- Which provider metadata belongs in `packages/schemas`?
- How should per-agent model roles choose secondary model providers, retries,
  or visible unavailable states?
- What call-log metadata is safe to persist without leaking prompts or secrets?

## Decision Outcome

Accepted for phase-one provider settings, with the W7 amendment that safe
backup is the implemented default and encrypted full backup remains deferred.
