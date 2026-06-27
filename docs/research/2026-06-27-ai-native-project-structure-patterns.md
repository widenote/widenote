# AI-Native Project Structure Patterns

Status: research synthesis
Date: 2026-06-27
Scope: current public GitHub project structure patterns in representative AI-native, agent framework, AI coding, MCP, memory, browser automation, and LLM infrastructure repositories

## Purpose

This note reviews how well-known AI-native repositories organize code,
examples, docs, SDKs, extension surfaces, evals, and deployment assets. The goal
is to identify project-structure patterns that should inform WideNote while it
is still in the phase-one local-first product stage.

This is research evidence, not a decision record. If the findings lead to
structural changes in WideNote, update `docs/architecture/project-structure.md`,
the nearest `README.md`, and `docs/agent-context/project-map.md`. If a change
affects runtime, schemas, sync, privacy, Agent Packs, licensing, or default UX,
update or create an ADR/RFC.

## Method

- Reviewed 34 public repositories and their current root-level plus selected
  second-level directories.
- Preferred current GitHub structure over old blog posts or README claims.
- Sample date is 2026-06-27 in the local project timezone.
- The sample intentionally mixes products, frameworks, SDKs, coding agents,
  MCP servers, memory systems, browser automation projects, and workflow
  platforms.

## Sample

| Project | Structure signal |
| --- | --- |
| [OpenAI Codex](https://github.com/openai/codex) | Rust core plus CLI, docs, SDKs, scripts, and tools. |
| [OpenAI Agents Python](https://github.com/openai/openai-agents-python) | Python library with `src/`, `docs/`, `examples/`, and `tests/`. |
| [Pydantic AI](https://github.com/pydantic/pydantic-ai) | Multi-package Python repo: agent docs, examples, evals, graph package, scripts, tests. |
| [LangChain](https://github.com/langchain-ai/langchain) | `libs/` monorepo with core, main package, partners, standard tests, and text splitters. |
| [LangGraph](https://github.com/langchain-ai/langgraph) | `libs/` monorepo plus examples and docs; separate checkpoint, SDK, CLI, and prebuilt packages. |
| [Dify](https://github.com/langgenius/dify) | Product monorepo: `api/`, `web/`, `packages/`, `sdks/`, `docker/`, docs, e2e, scripts. |
| [LlamaIndex](https://github.com/run-llama/llama_index) | Core package, integrations package, instrumentation, docs, scripts. |
| [Microsoft AutoGen](https://github.com/microsoft/autogen) | Language-family split: docs, dotnet, protos, python packages, samples, templates. |
| [Semantic Kernel](https://github.com/microsoft/semantic-kernel) | Multi-language SDK repo: dotnet, java, python, docs, prompt samples. |
| [Google ADK Python](https://github.com/google/adk-python) | Python package with docs, scripts, source, and tests. |
| [Agno](https://github.com/agno-agi/agno) | `libs/` plus a large `cookbook/` organized by agents, workflows, storage, knowledge, evals, memory, context, models, tools. |
| [CrewAI](https://github.com/crewAIInc/crewAI) | `lib/` packages plus docs and scripts. |
| [Mastra](https://github.com/mastra-ai/mastra) | Very broad TypeScript monorepo: packages, agent/client SDKs, integrations, deployers, observability, examples, templates, docs, e2e. |
| [MCP Servers](https://github.com/modelcontextprotocol/servers) | Reference server collection under `src/`, including filesystem, git, memory, time, and fetch servers. |
| [MCP Python SDK](https://github.com/modelcontextprotocol/python-sdk) | SDK repo with docs, examples, schema, scripts, source, and tests. |
| [MCP TypeScript SDK](https://github.com/modelcontextprotocol/typescript-sdk) | Package monorepo with docs, examples, packages, scripts, and conformance/e2e tests. |
| [OpenHands](https://github.com/OpenHands/OpenHands) | AI coding product: Python backend, frontend, containers, enterprise area, skills, scripts, tests. |
| [Roo Code](https://github.com/RooCodeInc/Roo-Code) | VS Code product monorepo: `apps/`, `packages/`, `schemas/`, `src/`, webview UI, releases, scripts. |
| [Cline](https://github.com/cline/cline) | AI coding product with `apps/`, docs, evals, SDK, assets, and multiple agent-tool config dirs. |
| [Continue](https://github.com/continuedev/continue) | Core engine, GUI, IDE extensions, packages, eval, docs, scripts, sync. |
| [Goose](https://github.com/aaif-goose/goose) | Rust crates plus UI, services, examples, evals, documentation, scripts, workflow recipes. |
| [Aider](https://github.com/aider-ai/aider) | Python application with core package, benchmark, docker, scripts, tests. |
| [browser-use](https://github.com/browser-use/browser-use) | Python library with core package, examples, skills, docker, static assets, tests. |
| [Stagehand](https://github.com/browserbase/stagehand) | TypeScript packages for CLI, core, docs, evals, and server. |
| [Firecrawl](https://github.com/firecrawl/firecrawl) | `apps/` monorepo with API, many SDKs, services, UI, examples, and CLI/skills/workflows. |
| [E2B](https://github.com/e2b-dev/E2B) | `packages/` for CLI and SDKs, plus spec, skills, and templates. |
| [Supermemory](https://github.com/supermemoryai/supermemory) | `apps/` and `packages/` monorepo for web, MCP, browser extension, memory graph, tools, UI, SDKs. |
| [Graphiti](https://github.com/getzep/graphiti) | Core graph package plus MCP server, server app, examples, spec, signatures, tests. |
| [Mem0](https://github.com/mem0ai/mem0) | Memory system with core package, TS package, docs, examples, integrations, server, tests, plugin config dirs. |
| [LiteLLM](https://github.com/BerriAI/litellm) | Provider/gateway repo with Python package, Rust code, backend, gateway, UI, deploy, helm, terraform, cookbook, tests. |
| [Flowise](https://github.com/FlowiseAI/Flowise) | Node monorepo: packages for agentflow, components, server, UI, observe, API docs, plus docker. |
| [n8n](https://github.com/n8n-io/n8n) | Automation monorepo with packages, docker, docs, scripts, security, and generated docs. |
| [Open WebUI](https://github.com/open-webui/open-webui) | Product repo with backend, Svelte frontend under `src/`, docs, scripts, static assets, tests. |
| [Lobe Chat](https://github.com/lobehub/lobe-chat) | Product monorepo with apps, packages, plugins, docs, locales, e2e, tests, scripts, public assets. |

## Quantitative Patterns

Across the 34 sampled repositories:

- 21 include a clear `docs/` or documentation site surface.
- 21 include `scripts/` or `tools/`.
- 21 expose shared/core code through `packages/`, `libs/`, `crates/`, `src/`,
  or similar package boundaries.
- 14 include `examples/`, `cookbook/`, `samples/`, or `templates/`.
- 13 include root-level `tests/` or `test/`.
- 12 expose explicit app/service surfaces such as `apps/`, `api/`, `web/`,
  `frontend/`, `backend/`, or `server/`.
- 6 include deployment surfaces such as `docker/`, `deploy/`, `helm/`, or
  Terraform.
- 4 expose plugin/integration surfaces at the root.
- 3 expose explicit root-level eval or benchmark surfaces.

The most frequent root directory names in the sample were `.github`, `scripts`,
`docs`, `examples`, `tests`, `packages`, `.devcontainer`, `.agents`, and
`.claude`.

## Structural Archetypes

### 1. Product Monorepo

Examples: Dify, OpenHands, Roo Code, Firecrawl, Supermemory, Open WebUI, Lobe
Chat.

Common shape:

```text
apps/ or api/ + web/
packages/
docs/
tests/ or e2e/
docker/ or deploy/
scripts/
```

This shape fits a product with multiple runnable surfaces, shared packages,
deployment assets, and user-facing documentation. It is the closest match for
WideNote's long-term shape.

### 2. Framework / SDK Monorepo

Examples: LangChain, LangGraph, Mastra, MCP TypeScript SDK, Flowise, n8n,
CrewAI.

Common shape:

```text
libs/ or packages/
examples/ or templates/
docs/
scripts/
tests/ or conformance/
```

This shape optimizes for reusable packages, integrations, adapters, and public
developer contracts. It is useful for WideNote's `packages/`, `packs/`, and
future SDK surfaces, but it should not dominate the product too early.

### 3. Single Core Library With Strong Examples

Examples: OpenAI Agents Python, Google ADK Python, MCP Python SDK, browser-use.

Common shape:

```text
src/ or package_name/
docs/
examples/
tests/
scripts/
```

This shape is effective when one library is the product. WideNote is not only a
library, but individual packages like `packages/dart/agent_runtime` and
`packages/ts/agent_sdk` can learn from it: keep package boundaries small, test
them directly, and provide runnable examples only after the contract is stable.

### 4. Multi-Language SDK Family

Examples: Semantic Kernel, AutoGen, Firecrawl, E2B, LiteLLM.

Common shape:

```text
python/
dotnet/
java/
packages/*-sdk/
sdks/
docs/
examples/
```

This shape works when the ecosystem already needs many language clients. It is
premature for WideNote phase one. WideNote should keep schemas and one runner
SDK close first, then split language SDKs only after external Agent Pack
authors exist.

### 5. Evaluation / Benchmark-Aware Agent Projects

Examples: Cline, Goose, Aider, Stagehand, Pydantic AI, Agno.

Common shape:

```text
evals/ or benchmark/
examples/
tests/
scripts/
```

These projects treat agent behavior as something that must be measured, not
only unit-tested. WideNote will need a similar surface once Memory extraction,
source-grounded chat, recaps, and Agent Pack outputs become core quality
claims.

## Strong Patterns

### 1. Keep Product Surfaces Separate From Reusable Contracts

Mature AI products separate runnable apps/services from shared packages. Dify,
Roo Code, Supermemory, Firecrawl, and Lobe Chat all distinguish product
surfaces from reusable contracts and packages.

WideNote already does this:

```text
apps/
packages/
packs/
docs/
infra/
tools/
```

The main recommendation is to keep the boundary strict: `apps/mobile` may own
immediate UX and local state, but public runtime contracts belong in
`packages/schemas`, reusable Dart logic belongs under `packages/dart`, and pack
behavior should depend on schemas/SDKs rather than app-private tables.

### 2. Examples And Cookbooks Are Ecosystem Assets, Not Core Product Truth

Agent frameworks often have large example/cookbook trees. Agno, LangGraph,
OpenAI Agents Python, browser-use, Firecrawl, Mem0, Mastra, and MCP SDKs all
use examples to teach patterns.

For WideNote, examples should wait until the public Agent Pack and SDK boundary
is stable enough to teach. Before that, examples risk becoming accidental
architecture. The current `packs/official/*` plus docs/RFCs are a better source
of truth than a broad root `examples/` directory.

### 3. Evals Become First-Class When AI Output Is A Product Claim

Several agent/coding projects include `evals/`, `benchmark/`, conformance, or
example test suites. This is especially visible in Cline, Goose, Aider,
Stagehand, Pydantic AI, Agno, and MCP TypeScript.

WideNote should eventually add a top-level `evals/` or clearly documented
evaluation package for:

- Memory candidate quality
- source-grounded conversation answers
- recap stability
- todo suggestion precision
- permission and privacy regression cases
- Agent Pack output conformance

Do not add this just as an empty directory. Add it when there is a repeatable
dataset, runner command, and README.

### 4. Deployment Surfaces Should Follow Real Product Need

Many product repos include `docker/`, `deploy/`, `helm/`, or Terraform because
they run hosted services. WideNote has `infra/` but the accepted product
boundary says core usage must work without an official backend.

For WideNote, `infra/` should stay minimal until optional sync, hosted runner,
registry, or backup services have real implementation. Backend/deployment
assets should enhance local-first usage, not become the path of least
resistance for core features.

### 5. Extension Ecosystems Need Three Distinct Places

Mature extensible projects tend to separate:

- runtime/package code
- examples/templates
- docs/reference

WideNote should make the same separation as Agent Packs mature:

```text
packs/official/        installable first-party manifests and native handlers
packages/schemas/      public contracts
packages/ts/agent_sdk/ runner-side SDK
docs/                  pack authoring reference and decisions
future examples/       non-authoritative examples after contracts stabilize
```

Avoid putting user-installable behavior directly in docs or examples. Packs are
runtime artifacts; docs and examples explain them.

### 6. Tooling Is Usually A First-Class Directory

Most sampled projects include `scripts/` or `tools/`. WideNote already has
`tools/pack_validator`, which is good because generated/validated contracts
need a stable command surface.

WideNote should continue using `tools/` for maintained repository automation.
If one-off scripts appear, either retire them or document them clearly; do not
let script sprawl become hidden architecture.

## Less Useful Patterns To Avoid

- Do not copy every AI-tool config directory (`.agents`, `.claude`, `.cursor`,
  `.codex`, `.gemini`, `skills`) unless the repo truly needs that tool-specific
  state.
- Do not create a giant examples/cookbook tree before public schemas and SDKs
  are stable.
- Do not split SDKs into many languages before there are real external users.
- Do not let deployment directories imply that the backend is required for core
  local-first usage.
- Do not let docs become a parallel source of runtime truth. Runtime contracts
  belong in schemas, manifests, and package APIs.
- Do not add empty future-facing directories without a README and command.

## Implications For WideNote

WideNote's current project structure is directionally strong. It already
resembles the better product monorepos rather than a single tangled app:

```text
apps/       runnable surfaces
packages/   shared contracts and logic
packs/      installable capabilities
docs/       project memory and decisions
infra/      optional deployment and self-hosting
tools/      validation and automation
```

The most important improvements are about timing and sharpness, not adding many
new folders.

Recommended next steps:

1. Keep the product monorepo. Do not split `agent-packs`, `registry`, `docs`,
   or `evals` into separate repositories until contracts stabilize.
2. Keep `apps/mobile` as the concrete phase-one product center. Backend and
   runner directories should remain optional/enhancing until sync, hosted
   runner, registry, or backup become real.
3. Make `packages/schemas` the only public contract source for runtime events,
   Memory, Agent Packs, permissions, traces, backup/export manifests, and UI
   blocks unless an ADR says otherwise.
4. Keep `packs/official/*` small and manifest-aligned. A pack should not reach
   into mobile-private tables or UI internals.
5. Add a top-level `evals/` only when WideNote has repeatable fixtures and a
   documented command for Memory/chat/recap/pack quality.
6. Add root `examples/` or `templates/` only after Agent Pack authoring and SDK
   contracts are stable; until then, use `docs/research`, RFCs, and official
   packs as the source of truth.
7. Continue requiring README coverage for every durable module. This matches
   the best external pattern while preserving WideNote's progressive context
   architecture.
8. Keep `infra/` honest: optional backend/self-hosting only, never a hidden
   prerequisite for capture, local data, Memory, or immediate UX.
9. Keep `tools/` curated. Promote repeated validation into documented tools;
   delete or archive throwaway scripts rather than letting them accumulate.
10. Consider future area-local `AGENTS.md` files only when an area has genuinely
    different rules, such as schema generation, mobile UI QA, or Agent Pack
    validation.

## Candidate Future Shape

Near term, WideNote should remain close to the current structure:

```text
apps/
  mobile/
  api/          optional, thin until sync/backup/registry lands
  runner-ts/    optional, thin until remote/self-hosted execution lands

packages/
  schemas/      public runtime contracts
  dart/         mobile-local reusable logic
  ts/           runner/API/pack SDK logic

packs/
  official/     first-party pack manifests and docs

docs/
infra/
tools/
```

Later, after contracts and behavior stabilize, the likely additions are:

```text
evals/          Memory/chat/recap/pack quality fixtures and runners
examples/       non-authoritative pack and SDK examples
templates/      starter Agent Pack templates, if not nested under examples
```

These should be added only with README ownership boundaries and commands.
