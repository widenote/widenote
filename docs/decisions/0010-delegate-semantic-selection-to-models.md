---
id: ADR-0010
title: No local content keyword heuristics in core
status: accepted
date: 2026-06-27
owners: [core, product]
tags: [ai-context, retrieval, fallback, core, mobile]
supersedes: []
superseded_by:
sources:
  - ../research/2026-06-27-local-semantic-rule-audit.md
  - ./0009-use-object-truth-and-context-packets.md
---

# No Local Content Keyword Heuristics in Core

## Context

WideNote is local-first, but local-first must not mean locally pretending to
understand user content with hand-written word rules. The mobile Chat slice
previously selected sources by lowercasing the user's question, splitting terms,
using stop words, and applying hand-tuned kind/intent boosts. Capture also used
content keywords to set Memory metadata, change Todo behavior, and continue with
local text when the model failed.

That behavior is brittle for long conversations, multilingual input, and user
trust. It can look intelligent while silently encoding product assumptions in
core code.

## Decision

WideNote core must not use user natural-language content with keyword, regular
expression, substring, or stop-word heuristics to infer meaning or produce
user-visible intelligence.

Source and fact provenance is a durable product principle. Cards, Memory,
insights, todos, chat answers, and other LLM-derived artifacts must preserve
traceable source refs or fact/evidence ids back to the raw record, source file,
event, Memory item, or reviewed user action that supports them. AI output must
remain derived state and must not overwrite original user input.

LLM call, cost, and trace visibility is also a durable BYOK product principle.
WideNote should keep strengthening local trace rows for model requests,
provider/model ids, token usage, retry/failure state, and provider-exposed cost
metadata without storing API keys or raw private prompts in logs.

## Reject

Core must not use user content for local relevance ranking:

- Do not score captures, Memory, todos, cards, or sources by matching words
  between a user question and stored text.
- Do not maintain local stop-word lists for semantic source selection.
- Do not apply local kind boosts, intent boosts, or rules like promoting todos
  because text mentions follow-up/task.

Core must not use user content for local semantic classification:

- Do not infer `memory_type` from words such as doctor, bank, token, or address.
- Do not infer sensitivity from keyword lists.
- Do not infer confidence from keyword lists.
- Do not locally decide that content is health, finance, location, credential,
  project, or task context from word matches.

Core must not use user content to decide automation branches:

- Do not route to review because a keyword matched.
- Do not skip Todo generation because a keyword matched.
- Do not raise or lower auto-accept behavior because a keyword matched.
- Do not alter pipeline path because a keyword matched.

Core must not use user content for local privacy or safety scans:

- Do not maintain core word lists for secret, token, password, path, prompt
  injection, or similar text.
- Do not use those lists in core to redact, block, mask, or rewrite user
  content.
- If future product work needs this behavior, route it through an explicit
  plugin or Agent Pack design instead of core keyword rules.

Core must not fake model-backed generation when a model is missing or fails:

- Do not return local template answers.
- Do not use `previewText` as a user-visible summary fallback.
- Do not ship deterministic local assistants as runtime answers.
- Do not fallback to local "smart" summaries, answers, or classifications.

Core tests may use fake models or fake retrievers, but those fakes must be
test-injected and must not justify runtime fallback behavior.

In one sentence: if core reads user natural-language content and uses keyword,
regular expression, or containment rules to infer, classify, mask, rank, route,
or answer, it should not exist in core.

## Consequences

- Chat source selection no longer uses local query-term scoring, stop words,
  kind boosts, or intent boosts.
- Product chat requires a configured model provider to generate an answer.
  Tests may inject fake or live model clients, but app bootstrap must not treat
  QA-only dart-defines as product provider state.
- Empty model responses and model request failures become retryable error
  states instead of local assistant answers.
- Capture no longer sets Memory metadata or pipeline branches from keyword
  matches.
- Capture model failures stop model-backed derivation instead of creating local
  summaries from `previewText`.
- LLM-derived cards, Memory, insights, todos, and chat answers must remain
  source-linked so users and Agent Packs can trace them back to evidence.
- Runtime model traces should expose provider/model/usage/cost/failure metadata
  for BYOK visibility while omitting secrets and raw prompts.
- Context Packet and Chat context code no longer maintains core secret,
  path, or prompt-injection word lists.
- Tests that need model output must inject fake model clients explicitly.

## Follow-ups

- Add regression checks around Chat, Capture, Context Packet, runtime traces,
  and backup/export so core content keyword rules are not reintroduced.
- Design plugin or Agent Pack contracts before adding any future content safety
  scanner or semantic classifier.
