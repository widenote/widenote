# Kimi Review Follow-Up

Date: 2026-06-23

## Context

Kimi CLI login was fixed after an earlier `invalid_authentication_error`. The successful invocation used explicit `--no-thinking`; the prior default configuration pointed at `kimi-code/kimi-for-coding` and had failed before the login/config path was refreshed.

## Architecture Review Takeaways

Kimi agreed with the main direction:

- Memory-first instead of PKM core.
- Local-first Flutter client with pure Dart runtime packages.
- Event-driven Agent Packs.
- Clean-room parity target for MemeX functions except PKM.
- Progressive context disclosure through root, area, module, and file-level docs.

It highlighted missing contracts:

- Memory auto-accept thresholds and sensitivity taxonomy.
- Agent Pack manifest and permission schema.
- Sync placeholders for future device/cloud sync.
- Runner task envelope and output event schema.
- Schema code generation between Dart and TypeScript.

## Code Review Takeaways

Kimi flagged three high-priority implementation risks:

- Flutter capture UI was not connected to the runtime and Memory service.
- `agent_runtime` and `model_providers` had separate model abstractions without a bridge.
- Runtime boundary tests were too narrow.

## Actions Taken

- Added `CaptureOrchestrator` to connect mobile quick capture to `RuntimeKernel` and `MemoryService`.
- Added a mobile orchestration test covering capture event publication, agent output, Memory auto-acceptance, and runtime trace output.
- Added `RuntimeModelClientAdapter` so `ModelProvider` implementations can satisfy the runtime `ModelClient` contract.
- Added runtime tests for handler failure, missing handler, tool permission denial, and empty handler output.
- Added RFC drafts for Memory Model and Agent Pack Schema.
- Updated the project map to include active RFCs, Memory package, and Model Providers package.

## Second Review Actions

Kimi's follow-up review found no P0 issues. It flagged P1 gaps around Memory type policy, missing event defenses, model adapter failure translation, and the imperative-to-manifest Agent Pack transition.

Actions taken:

- Added `MemoryType` to `MemoryProposal` and `MemoryItem`.
- Updated `DefaultMemoryPolicy` so review-only types such as health, finance, location, and credentials cannot be silently auto-accepted.
- Added tests for review-only Memory types.
- Added `CapturePipelineException` and explicit missing-event checks in the mobile capture orchestration path.
- Wrapped provider failures in `RuntimeModelProviderException`.
- Added adapter failure tests.
- Updated Agent Pack Schema RFC with an explicit migration plan from native imperative built-in packs to manifest-first loading.

## Deferred With Rationale

- Splitting `RuntimeKernel`: still under the 800-line hard threshold and currently easier to review as a single vertical slice. Revisit before adding retries, timeouts, parallel dispatch, or persistent queues.
- Sync schemas: cloud sync is explicitly deferred from phase one, but sync object placeholders should be added before implementing local DB migrations.
- Shared Flutter UI components: useful soon, but current UI is still a skeleton and can wait until repeated controls stabilize.
