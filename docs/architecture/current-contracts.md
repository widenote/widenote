# Current Architecture Contracts

Status: active

Date: 2026-07-01

Scope: current target-state contracts for day-to-day WideNote development

This file is the current-state layer between the historical decision log and
implementation work. Coding agents and humans should read the task-relevant
contracts here before changing a module. ADRs and RFCs remain authoritative for
decision history, tradeoffs, and rationale, but this file states what the
project is currently maintaining.

## How To Use

1. Start with this file for the current target state.
2. Use the nearest module README for local ownership and implementation
   boundaries.
3. Open the linked ADRs or RFCs when the contract is unclear, the change would
   alter the contract, or history and rationale matter.
4. Encode important contracts in tests, validators, or documented review gates
   whenever practical.

Do not treat current implementation behavior as authoritative when it conflicts
with a current contract. Fix the implementation or update the contract through
the decision process.

## Maintenance Rules

- When an accepted ADR or RFC changes the target state of a product,
  architecture, runtime, schema, privacy, sync, Agent Pack, plugin-permission,
  technology, or default-UX boundary, update this file in the same change.
- When a module starts implementing a contract listed here, link this file from
  that module README.
- When a contract changes, update or add executable proof: tests, schema
  validation, pack validation, docs lint, integration QA, or an explicit skipped
  check with risk.
- Keep this file short and operational. Put history, rejected alternatives, and
  detailed evidence in ADRs, RFCs, or research notes.
- Do not rewrite ADRs to hide history. Supersede them with new ADRs, then
  update this file to the new current state.

## Contract Index

| Area | Current contract | Applies first to | Enforced by | Provenance |
| --- | --- | --- | --- | --- |
| Product loop | The default loop is quick capture -> timeline/cards -> Memory -> insight. Backend services, advanced exports, broad imports, hosted runners, registries, and community packs enhance the loop; they must not become prerequisites for first use. | `apps/mobile/**`, `packs/official/**`, `docs/product/**` | Mobile journey tests, module README review, product docs review | [ADR-0005](../decisions/0005-use-memory-first-instead-of-pkm-core.md), [ADR-0007](../decisions/0007-defer-cloud-sync-from-core-phase-one.md), [Phase-One Product Scope](../rfcs/phase-one-product-scope.md) |
| Local-first ownership | The mobile client owns immediate capture, local persistence, local runtime hosting, permissions, and first-use UX. Optional backend and runner services may sync, schedule, back up, or execute longer work, but they are not the canonical brain. | `apps/mobile/**`, `apps/api/**`, `apps/runner-ts/**`, `packages/dart/**`, `packages/ts/**` | Architecture review, package tests, integration QA | [ADR-0003](../decisions/0003-build-agent-runtime-kernel.md), [ADR-0007](../decisions/0007-defer-cloud-sync-from-core-phase-one.md), [Architecture Overview](./overview.md) |
| Source truth | Original user records and source material are source truth. AI outputs are derived objects and must not overwrite raw input. Derived outputs must preserve source references when they depend on user records. | `apps/mobile/lib/features/capture/**`, `packages/dart/local_db/**`, `packages/dart/agent_runtime/**`, `packages/dart/cards/**`, `packages/dart/memory/**` | Orchestration tests, backup/restore tests, source-ref assertions | [ADR-0009](../decisions/0009-use-object-truth-and-context-packets.md), [Phase-One Umbrella Technical Plan](../rfcs/phase-one-umbrella-technical-plan.md) |
| Voice transcription | Voice capture saves raw audio before ASR. New first-slice recordings use WAV. Real-time preview ships with the first transcription slice when stable and degrades to final ASR after stop. Transcripts are `audio_transcript` derived artifacts and downstream outputs must cite capture, attachment, transcript, and event refs. Local ASR is default; remote ASR can automatically fall back after local failure only after explicit opt-in, with manual retry still available. Existing `.m4a` recordings are not first-slice local-ASR compatibility targets. `audio.transcribe` Runtime exposure waits until it can wrap the mobile transcription engine. | `apps/mobile/lib/features/capture/**`, future `apps/mobile/lib/features/transcription/**`, `packages/schemas/**`, `packages/dart/agent_runtime/**` | Transcript schema fixtures, mobile transcription tests, backup media tests, runtime wrapper tests when added | [ADR-0012](../decisions/0012-accept-voice-transcription-and-correction-boundaries.md), [Voice ASR Plan](../research/2026-06-30-voice-input-asr-correction-plan.md) |
| Memory write policy | Durable, low-risk, source-linked, non-conflicting Memory is auto-accepted by default. Low-confidence, conflicting, highly sensitive, credential-like, or policy-unclear Memory goes to review. Review is the exception path, not the default capture path. | `packages/dart/memory/**`, `apps/mobile/lib/features/capture/**`, `apps/mobile/lib/features/memory/**`, `packs/official/**` | Memory unit tests, capture orchestration tests, long-journey QA | [ADR-0005](../decisions/0005-use-memory-first-instead-of-pkm-core.md), [Memory Model RFC](../rfcs/memory-model.md), [Engineering Rules](./engineering-rules.md#memory-write-policy) |
| Memory visibility and correction | Accepted Memory is visible, editable, deletable through tombstone or revision, source-linked, and reversible enough that auto-accept remains safe. Review surfaces are for exceptions and correction, not confirmation of every capture. | `apps/mobile/lib/features/memory/**`, `packages/dart/memory/**`, `packages/dart/local_db/**` | Memory service tests, Memory page tests, backup/restore tests | [ADR-0005](../decisions/0005-use-memory-first-instead-of-pkm-core.md), [Memory Model RFC](../rfcs/memory-model.md) |
| Object truth and context packets | SQLite/Drift object tables remain the canonical local object truth. Context packets, projections, FTS, vector indexes, recaps, cards, and other read models are derived and rebuildable unless a future ADR says otherwise. User-facing backup exports use a compressed `.widenote` directory archive with staged restore and entry hash verification. The default archive carries a full SQLite snapshot plus local capture media files, not JSON or Markdown restore documents, and preserves provider API keys so restore can immediately use configured model providers. Treat `.widenote` files as secret-bearing local artifacts. | `packages/dart/local_db/**`, `apps/mobile/lib/app/local_database.dart`, `packages/dart/agent_runtime/**`, future context modules | Local DB tests, backup/restore tests, context-packet tests when added | [ADR-0009](../decisions/0009-use-object-truth-and-context-packets.md), [ADR-0012](../decisions/0012-accept-voice-transcription-and-correction-boundaries.md), [ADR-0013](../decisions/0013-preserve-provider-credentials-in-widenote-backups.md), [Phase-One Umbrella Technical Plan](../rfcs/phase-one-umbrella-technical-plan.md) |
| Public contracts | Public Event, Transcript, Memory, Agent Pack, Marketplace Index, Permission, Trace, Backup, Sync, Tool, Task, and UI Block contracts belong in `packages/schemas` unless an accepted ADR says otherwise. Feature modules must not define private copies of public contracts. | `packages/schemas/**`, `apps/mobile/**`, `packages/dart/**`, `packages/ts/**`, `packs/**` | Schema fixture validation, pack validator, module README review | [Agent Pack Schema RFC](../rfcs/agent-pack-schema.md), [ADR-0012](../decisions/0012-accept-voice-transcription-and-correction-boundaries.md), [Phase-One Umbrella Technical Plan](../rfcs/phase-one-umbrella-technical-plan.md) |
| Agent Packs, marketplace, and permissions | Agent Packs depend on public schemas and SDK boundaries. The phase-one marketplace is GitHub-first: manifests carry marketplace metadata, `packs/marketplace/index.json` is the bundled catalog, and mobile Pack Library displays installed/bundled metadata before remote install exists. Additive slots may extend flows; replacement slots are reserved for `official` or `local_dev` packs until permission, rollback, and review gates are accepted. Sensitive or high-risk tools need explicit permissions, reviewable traces, and local-dev or community-edition gates where needed. Packs must not write mobile-private tables directly. | `packs/**`, `packages/dart/agent_runtime/**`, `packages/ts/agent_sdk/**`, `apps/mobile/**` | Pack validator, runtime permission tests, Pack Library widget tests, trace tests | [ADR-0011](../decisions/0011-adopt-agent-runtime-roadmap.md), [Agent Pack Schema RFC](../rfcs/agent-pack-schema.md), [Agent Runtime Capability Boundaries](../rfcs/agent-runtime-capability-boundaries.md), [Marketplace PKM Plan](../research/2026-06-28-marketplace-pkm-plan.md) |
| Model provider access | Model access is local-first BYOK configuration. Mobile Settings provides editable presets for mainstream OpenAI-compatible and Anthropic-compatible services, including OpenAI, Anthropic Claude, Google Gemini, OpenRouter, DeepSeek, Kimi, Qwen, Doubao, Zhipu GLM, MiniMax, MIMO, Ollama, and custom compatible endpoints. The model picker fetches official provider model lists on demand, uses a dropdown for selection, and keeps a custom model-id fallback. Product runtime reads saved settings only; QA dart-defines remain test harness overrides. Default `.widenote` backups preserve provider credential values for direct-use restore; legacy JSON/Markdown projections remain no-secret surfaces. | `packages/dart/model_providers/**`, `apps/mobile/lib/features/model_providers/**`, `packages/dart/local_db/**` | Model provider package tests, provider settings widget tests, backup secret-boundary tests | [ADR-0013](../decisions/0013-preserve-provider-credentials-in-widenote-backups.md), [Model Provider Settings RFC](../rfcs/model-provider-settings.md), [Phase-One Product Scope](../rfcs/phase-one-product-scope.md) |
| Transcript correction Pack | Transcript correction is an additive Agent Pack capability. The official correction pack reads transcript text plus permissioned Memory or glossary context, emits `wn.transcript.corrected`, and writes source-linked transcript correction revisions. It must not read raw audio or write Memory directly. High-confidence exact term/name corrections auto-apply by default; medium/low confidence or meaning-, number-, date-, credential-, medical-, legal-, or financial-affecting patches route to review. | `packs/official/transcript_correction/**`, `packages/schemas/src/transcript/**`, `packages/dart/agent_runtime/**`, future mobile transcription/correction UI | Pack validator, transcript schema fixtures, correction pack runtime tests when native handler lands | [ADR-0012](../decisions/0012-accept-voice-transcription-and-correction-boundaries.md), [Agent Pack Schema RFC](../rfcs/agent-pack-schema.md) |
| Semantic selection | Core semantic decisions use governed model/context boundaries, not local keyword heuristics. Local deterministic checks are allowed for safety, permissions, schema validation, and exact technical parsing. | `apps/mobile/**`, `packages/dart/**`, `packs/**` | Targeted tests for model/context routing, audits for keyword heuristics | [ADR-0010](../decisions/0010-delegate-semantic-selection-to-models.md) |
| Documentation context | Agents should load context progressively: root instructions, task-relevant current contracts, project map when routing is unclear, nearest README, then decision index and related ADR/RFC only when changing a contract or needing rationale. `START_HERE.md` is for orientation, not required pre-work for every task. Module READMEs and this file are current-state context; ADRs are decision history. | `AGENTS.md`, `docs/agent-context/**`, `docs/architecture/**`, module READMEs | Docs-only link checks, project-map review | [ADR-0000](../decisions/0000-use-decision-records.md), [ADR-0004](../decisions/0004-use-progressive-context-structure.md) |

## Module Routing Hints

| If touching | Read these current contracts first | Then read |
| --- | --- | --- |
| `apps/mobile/lib/features/capture/**` | Product loop, source truth, Memory write policy, semantic selection | Capture README, Memory Model RFC, ADR-0005, ADR-0009 |
| voice transcription or transcript correction paths | Source truth, voice transcription, transcript correction Pack, public contracts, object truth and context packets | ADR-0012, Voice ASR Plan, Schemas README, Agent Pack Schema RFC |
| `apps/mobile/lib/features/memory/**` | Memory write policy, Memory visibility and correction, source truth | Memory feature README, Memory package README, Memory Model RFC |
| `packages/dart/memory/**` | Memory write policy, Memory visibility and correction, source truth | Memory package README, ADR-0005, Memory Model RFC |
| `packages/dart/local_db/**` or backup/restore paths | Source truth, object truth and context packets, Memory visibility and correction | Local DB README, ADR-0009, backup RFC/research |
| `packages/dart/agent_runtime/**` or `packs/**` | Local-first ownership, Agent Packs, marketplace, and permissions, public contracts, source truth | Runtime README, pack README, ADR-0011, Agent Pack Schema RFC |
| `packages/dart/model_providers/**` or `apps/mobile/lib/features/model_providers/**` | Model provider access, local-first ownership, source truth | Model Providers README, Mobile model providers README, Model Provider Settings RFC |
| `packages/schemas/**` | Public contracts, source truth, Agent Packs and permissions | Schemas README, schema fixtures, Agent Pack Schema RFC |
| `docs/decisions/**`, `docs/rfcs/**`, `docs/architecture/**`, `docs/agent-context/**` | Documentation context and any contract area being changed | Decision update protocol, docs README, relevant ADR/RFC |
