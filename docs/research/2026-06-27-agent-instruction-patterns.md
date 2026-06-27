# AI-Native Agent Instruction File Patterns

Status: research synthesis
Date: 2026-06-27
Scope: current public GitHub `AGENTS.md` / `CLAUDE.md` patterns in representative AI-native and agent-oriented repositories

## Purpose

This note reviews how well-known AI-native, agent framework, AI coding, MCP,
memory, browser automation, and LLM infrastructure repositories write their
agent instruction entrypoints. The goal is to identify patterns that should
inform WideNote's own repository instructions.

This is research evidence, not a decision record. If these findings lead to
changes in WideNote's repository-level agent rules, add the concrete rule
changes to `AGENTS.md`; if they affect runtime, schema, privacy, Agent Pack, or
default UX behavior, update or create an ADR/RFC.

## Method

- Reviewed 31 public repositories and 50 root-level instruction files.
- Preferred root-level files because these are what coding agents naturally
  discover first.
- Sample date is 2026-06-27 in the local project timezone.
- Some famous AI repositories do not currently expose root `AGENTS.md` or
  `CLAUDE.md`; they are not counted in the pattern statistics below.

## Sample

| Project | Files reviewed | Pattern note |
| --- | --- | --- |
| OpenAI Codex | [AGENTS](https://github.com/openai/codex/blob/main/AGENTS.md) | Long, precise engineering guide with review, API, context, and test rules. |
| OpenAI Agents Python | [AGENTS](https://github.com/openai/openai-agents-python/blob/main/AGENTS.md), [CLAUDE](https://github.com/openai/openai-agents-python/blob/main/CLAUDE.md) | `AGENTS.md` is canonical; `CLAUDE.md` is a pointer. |
| Pydantic AI | [AGENTS](https://github.com/pydantic/pydantic-ai/blob/main/AGENTS.md), [CLAUDE](https://github.com/pydantic/pydantic-ai/blob/main/CLAUDE.md) | Strong philosophy, task-readiness, contribution, and verification guidance; `CLAUDE.md` points to `AGENTS.md`. |
| LangChain | [AGENTS](https://github.com/langchain-ai/langchain/blob/master/AGENTS.md), [CLAUDE](https://github.com/langchain-ai/langchain/blob/master/CLAUDE.md) | Both files are substantial and currently identical. |
| LangGraph | [AGENTS](https://github.com/langchain-ai/langgraph/blob/main/AGENTS.md), [CLAUDE](https://github.com/langchain-ai/langgraph/blob/main/CLAUDE.md) | Compact monorepo dependency map and per-library validation commands. |
| Dify | [AGENTS](https://github.com/langgenius/dify/blob/main/AGENTS.md), [CLAUDE](https://github.com/langgenius/dify/blob/main/CLAUDE.md) | Backend/frontend workflows, test practices, language style; `CLAUDE.md` points to `AGENTS.md`. |
| Agno | [AGENTS](https://github.com/agno-agi/agno/blob/main/AGENTS.md), [CLAUDE](https://github.com/agno-agi/agno/blob/main/CLAUDE.md) | Repository map, conductor notes, virtualenv, cookbook testing, generated API checks. |
| CrewAI | [AGENTS](https://github.com/crewAIInc/crewAI/blob/main/AGENTS.md) | Docs-specific contributor guide with versioning and local preview rules. |
| Google ADK Python | [AGENTS](https://github.com/google/adk-python/blob/main/AGENTS.md) | Short project overview plus architecture/style/setup pointers. |
| Mastra | [AGENTS](https://github.com/mastra-ai/mastra/blob/main/AGENTS.md), [CLAUDE](https://github.com/mastra-ai/mastra/blob/main/CLAUDE.md) | Very compact workspace rules; `CLAUDE.md` points to `AGENTS.md`. |
| MCP Servers | [CLAUDE](https://github.com/modelcontextprotocol/servers/blob/main/CLAUDE.md) | Monorepo structure and TypeScript/Python server build/test commands. |
| MCP Python SDK | [AGENTS](https://github.com/modelcontextprotocol/python-sdk/blob/main/AGENTS.md), [CLAUDE](https://github.com/modelcontextprotocol/python-sdk/blob/main/CLAUDE.md) | Branching model, package management, quality, coverage, breaking changes; `CLAUDE.md` points to `AGENTS.md`. |
| MCP TypeScript SDK | [CLAUDE](https://github.com/modelcontextprotocol/typescript-sdk/blob/main/CLAUDE.md) | Build/test commands, breaking changes, code style, architecture. |
| OpenHands | [AGENTS](https://github.com/OpenHands/OpenHands/blob/main/AGENTS.md) | Large operational guide: setup, git, lockfiles, PR artifacts, package-specific rules. |
| Roo Code | [AGENTS](https://github.com/RooCodeInc/Roo-Code/blob/main/AGENTS.md) | Tiny, targeted rule for a known risky UI state pattern. |
| Goose | [AGENTS](https://github.com/aaif-goose/goose/blob/main/AGENTS.md), [CLAUDE](https://github.com/aaif-goose/goose/blob/main/CLAUDE.md) | Rust/Electron setup, structure, conventions; `CLAUDE.md` points to `AGENTS.md`. |
| Open Interpreter | [AGENTS](https://github.com/openinterpreter/openinterpreter/blob/main/AGENTS.md) | Substantial instructions, but the sampled content appears generic/stale relative to the project; useful as a caution. |
| browser-use | [AGENTS](https://github.com/browser-use/browser-use/blob/main/AGENTS.md), [CLAUDE](https://github.com/browser-use/browser-use/blob/main/CLAUDE.md) | Rich architecture and browser/CDP rules; very long root `AGENTS.md`, shorter `CLAUDE.md`. |
| Stagehand | [claude](https://github.com/browserbase/stagehand/blob/main/claude.md) | Tool/API usage guide with examples for act, observe, extract, and agent patterns. |
| Firecrawl | [AGENTS](https://github.com/firecrawl/firecrawl/blob/main/AGENTS.md), [CLAUDE](https://github.com/firecrawl/firecrawl/blob/main/CLAUDE.md) | Compact monorepo map and end-to-end test expectations. |
| E2B | [AGENTS](https://github.com/e2b-dev/E2B/blob/main/AGENTS.md), [CLAUDE](https://github.com/e2b-dev/E2B/blob/main/CLAUDE.md) | `AGENTS.md` points to `CLAUDE.md`; `CLAUDE.md` is a concise cross-SDK ruleset. |
| Supermemory | [CLAUDE](https://github.com/supermemoryai/supermemory/blob/main/CLAUDE.md) | Monorepo structure, app/package commands, and stack overview. |
| Graphiti | [AGENTS](https://github.com/getzep/graphiti/blob/main/AGENTS.md), [CLAUDE](https://github.com/getzep/graphiti/blob/main/CLAUDE.md) | `AGENTS.md` is compact repository guidance; `CLAUDE.md` is deeper project/command context. |
| Mem0 | [AGENTS](https://github.com/mem0ai/mem0/blob/main/AGENTS.md), [CLAUDE](https://github.com/mem0ai/mem0/blob/main/CLAUDE.md) | Detailed memory-layer context and commands; `CLAUDE.md` points to `AGENTS.md`. |
| LiteLLM | [AGENTS](https://github.com/BerriAI/litellm/blob/litellm_internal_staging/AGENTS.md), [CLAUDE](https://github.com/BerriAI/litellm/blob/litellm_internal_staging/CLAUDE.md) | `AGENTS.md` points to `CLAUDE.md`; `CLAUDE.md` contains detailed coding/test rules. |
| any-agent | [AGENTS](https://github.com/mozilla-ai/any-agent/blob/main/AGENTS.md), [CLAUDE](https://github.com/mozilla-ai/any-agent/blob/main/CLAUDE.md) | Explicitly says `AGENTS.md` is canonical and `CLAUDE.md` is a symlink/pointer. |
| Refactor MCP | [AGENTS](https://github.com/dave-hillier/refactor-mcp/blob/main/AGENTS.md), [CLAUDE](https://github.com/dave-hillier/refactor-mcp/blob/main/CLAUDE.md) | Contribution guide plus project architecture and command guide. |
| Clojure MCP | [AGENTS](https://github.com/bhauman/clojure-mcp/blob/main/AGENTS.md), [CLAUDE](https://github.com/bhauman/clojure-mcp/blob/main/CLAUDE.md) | Short identical development guide. |
| moltbook-mcp | [AGENTS](https://github.com/terminalcraft/moltbook-mcp/blob/master/AGENTS.md), [CLAUDE](https://github.com/terminalcraft/moltbook-mcp/blob/master/CLAUDE.md) | Project overview, security/injection concerns, tools, running, and dependencies. |
| mcp-read-website-fast | [CLAUDE](https://github.com/just-every/mcp-read-website-fast/blob/main/CLAUDE.md) | LLM/RAG-oriented extractor architecture and commands. |
| open-meteo-mcp | [CLAUDE](https://github.com/cmer81/open-meteo-mcp/blob/main/CLAUDE.md) | MCP server overview, tool system, transport modes, commands. |

## Quantitative Patterns

Across the 31 sampled repositories:

- 19 have both `AGENTS.md` and `CLAUDE.md`.
- 6 have only `AGENTS.md`.
- 6 have only `CLAUDE.md`.
- 10 of the 19 dual-file repos use one file as a thin pointer to the other.
- 2 dual-file repos keep the two files identical.
- Median length for substantial files is about 126 lines.
- 29 repositories include project/architecture or repository structure.
- 29 include build/test/development commands.
- 29 include style, linting, typing, or coding conventions.
- 29 include testing guidance.
- 23 include explicit safety, security, privacy, credential, or "do not" rules.
- 21 mention generated files, schemas, or "do not edit generated output" style constraints.

## Strong Patterns

### 1. Use One Canonical Instruction Source

The strongest pattern is not "have both files with two versions of the truth."
It is "choose one canonical file and make the other a pointer."

Common variants:

- `AGENTS.md` is canonical; `CLAUDE.md` contains only `AGENTS.md` or
  `@AGENTS.md`.
- `CLAUDE.md` is canonical; `AGENTS.md` contains a pointer.
- Both files are identical, but this is more fragile unless generated or
  symlinked.

For WideNote, `AGENTS.md` should remain canonical because it is tool-neutral and
already aligned with repository instructions. If Claude-specific discovery is
important, add a thin `CLAUDE.md` pointer instead of duplicating rules.

### 2. Start With "Where To Look First"

Good files rarely ask agents to load the whole repository. They name the
highest-value entrypoints first: README, project map, architecture overview,
module guides, package-local instructions, or contribution docs.

WideNote already has this architecture in `docs/agent-context/START_HERE.md`
and `docs/agent-context/project-map.md`. The root `AGENTS.md` can make this
even more operational by naming which context files map to which change types.

### 3. Treat The File As An Operating Manual, Not A Persona Prompt

The useful files focus on how to work in the repo:

- repository map
- local setup
- build, lint, format, typecheck, and test commands
- dependency and package manager rules
- generated-file rules
- PR/review expectations
- high-risk areas and invariants

They do not spend much space on model personality. WideNote's current
`AGENTS.md` is strong on durable constraints, but it is lighter on exact
validation commands and change-type playbooks.

### 4. Put Domain Semantics In The Agent Rules

AI-native projects encode their domain-specific contracts:

- MCP projects name tool and transport boundaries.
- Browser automation projects name CDP/session/event constraints.
- Memory projects name storage, retrieval, and evaluation expectations.
- AI coding agent projects name git, lockfile, PR artifact, and test workflow
  rules.

For WideNote, the domain semantics that belong in root instructions are:

- raw user records are original source truth
- Memory, cards, insights, recaps, todos, and chat answers are derived outputs
- AI output must preserve source refs and must not overwrite raw input
- Agent Packs use public schemas/SDK boundaries, not private app tables
- high-risk tools require explicit permissions and traces

Most of these exist today, but the operating implications can be sharper.

### 5. Scope Rules By Directory Only When The Rules Actually Diverge

Several monorepos point agents to package-local instructions or local
`AGENTS.md` files. The useful pattern is not "add many files"; it is "put local
rules near areas that have different commands, generated outputs, or ownership
boundaries."

WideNote already uses module READMEs for progressive context. That is good.
Area-level `AGENTS.md` files should wait until an area has materially different
agent behavior, such as `apps/mobile`, `packages/schemas`, or `packs/`.

### 6. Convert Safety Principles Into Checkable Rules

Strong files do not only say "be careful." They name concrete risks:

- do not commit secrets
- do not hand-edit generated files
- run exact tests before PR
- preserve lockfile/package-manager versions
- isolate breaking changes
- do not bypass review for high-risk capabilities

WideNote should keep its existing privacy posture, and add more concrete
personal-data rules as the product matures:

- do not paste raw private records, local databases, credentials, provider keys,
  or unpublished user data into external review tools
- do not introduce broad filesystem/network/location/audio permissions without
  ADR/RFC and explicit UI permission copy
- do not let agent-generated content mutate raw capture objects directly

## Less Useful Patterns

- Duplicating substantial `AGENTS.md` and `CLAUDE.md` content without a
  generation/symlink story invites drift.
- A tiny pointer file is fine only if the target is obvious and discoverable.
- Very long root files can become hard to scan; move stable deep context into
  architecture docs, module READMEs, or package-local instructions.
- Copy-pasted generic instructions are actively harmful when they describe the
  wrong stack or product.
- Command lists without change-type guidance leave agents unsure which checks
  matter for docs-only, UI, schema, runtime, or privacy changes.

## Implications For WideNote

WideNote's current direction is already close to the best pattern:

- `AGENTS.md` has durable product constraints.
- progressive context structure is an accepted ADR.
- module READMEs and `project-map.md` are treated as source-of-truth context.
- decision hygiene already routes raw discussion into `docs/research/` before
  ADR/RFC updates.

The gap is that the root instructions are more like a constitution than an
operating checklist. Strong AI-native repos combine both.

Recommended next steps:

1. Keep `AGENTS.md` canonical.
2. Add a root `CLAUDE.md` that only points to `AGENTS.md`, if Claude Code users
   are expected to work in the repo.
3. Add a "Where to look first by task type" section to `AGENTS.md`.
4. Add a short validation matrix:
   docs-only, Flutter UI, runtime/memory, schemas/generated types, Agent Packs,
   privacy/permissions, backup/export, and GitHub publication.
5. Link exact commands from existing docs instead of inventing a second command
   source. Candidates include Flutter analyze/test, pack validator, schema
   validation, and docs link/text checks.
6. Make personal-data and external-review restrictions concrete.
7. Keep root instructions short; put deep local detail in module READMEs or
   future area-local `AGENTS.md` files only when behavior diverges.
8. Before community Agent Packs, add pack-authoring instructions under `packs/`
   or `docs/architecture/` that cover permissions, traces, source refs, and
   manifest validation.

## Candidate Future Shape

If WideNote updates root instructions, a useful structure would be:

```text
AGENTS.md
  Project identity
  Canonical instruction source
  Durable product/runtime invariants
  Where to look first by task type
  Change-type validation matrix
  Structure and generated-artifact rules
  Privacy, secrets, and external-review rules
  Decision hygiene and ADR/RFC triggers

CLAUDE.md
  See AGENTS.md. AGENTS.md is the canonical repository instruction file.
```

This keeps WideNote aligned with the best external pattern while preserving its
existing progressive context architecture.
