# RFC: Model Provider Settings

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

- Represent OpenAI-compatible, Anthropic-compatible, MIMO, and Kimi providers
  with shared config models.
- Keep provider adapters testable with fake HTTP.
- Classify auth, rate limit, timeout, server, network, malformed-response, and
  missing-text failures.
- Provide a mobile settings page for add, edit, test connection, and default
  provider selection.
- Keep real credentials out of repository files, fixtures, logs, generated
  docs, and automated review prompts.
- User-initiated local backups intentionally include provider API keys for
  restore portability.

## Non-goals

- Real live-provider tests in CI.
- Per-agent model role routing.
- LLM call log storage.
- Migration away from the current QA-only MIMO bootstrap path.

## Proposed Design

`packages/dart/model_providers` owns provider config models, compatible request
builders, fake HTTP, fake providers, and a shared error taxonomy. Adapters are
constructed with an injected HTTP client so tests can assert request shape
without external network access.

`apps/mobile/lib/features/model_providers` owns the first mobile settings
surface. Providers can be added, edited, tested with a fake connection service,
selected as default, and persisted locally for app restarts and backup/restore.

The plugin control page links to the settings page. A later settings-home
integration can move or duplicate this entry without changing provider package
contracts.

The mobile settings page is organized as:

1. Runtime model access status, showing whether a default provider is active or
   whether the local deterministic fallback is in use.
2. Model roles, showing the default text-model role and making clear that
   per-Agent overrides are deferred.
3. Capabilities and privacy, explaining BYOK local storage, user-initiated
   connection tests, and offline fallback.
4. Provider management, preserving add, edit, default selection, and connection
   test actions.

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
backup exports are separate from safe metadata and include the credential value.

## Privacy and Security Impact

Provider credentials are durable local values in this slice. They must not be
printed by `toString`, included in safe JSON, committed to tests, written to
docs, stored in generated artifacts, or sent to automated review prompts.
User-initiated backup JSON is the explicit exception and must be treated as
secret-bearing user data.

## Local-first and Sync Impact

The feature does not require an account, backend, or live network service. Sync
is unaffected. Local backup/export includes provider API keys so restored
devices can continue using configured providers without manual re-entry.

## Agent / Plugin Impact

This RFC creates the provider settings foundation for Agent Pack model access.
Per-agent role selection and model routing remain follow-up work and should use
public schemas rather than app-private tables.

Until per-agent routing lands, built-in capture, chat, Memory, and Agent Pack
execution inherit the default provider when one is configured and otherwise use
the local deterministic fallback.

## Alternatives

- Keep only the QA MIMO path. This blocks BYOK product use and hides provider
  setup from users.
- Implement real SDK clients immediately. This adds dependency and credential
  risk before the local settings model is stable.
- Exclude provider credentials from backup. This would make provider restore
  incomplete and conflicts with the product portability requirement.

## Migration / Compatibility

The existing QA-only model client remains available for Android QA builds. The
new provider package adapters do not change runtime model semantics yet.
`packages/dart/local_db` stores provider metadata, API keys, and
default-provider state.

## Open Questions

- Whether a future secure-storage abstraction can preserve full
  user-managed backup/restore semantics.
- Which provider metadata belongs in `packages/schemas`?
- How should per-agent model roles choose fallback providers?
- What call-log metadata is safe to persist without leaking prompts or secrets?

## Decision Outcome

Open.
