# ADR-0020: Accept Insight Depth Foundation

---
id: ADR-0020
title: Accept Insight Depth Foundation
status: accepted
date: 2026-07-03
owners: [product, mobile, runtime]
tags: [insights, schemas, mobile, agent-packs, privacy]
supersedes:
superseded_by:
sources:
  - ../architecture/current-contracts.md
  - ../research/2026-07-03-insight-depth-design.md
---

## Context

WideNote's implemented insight loop has been intentionally conservative:
deterministic Memory-first projections create source-linked summary, count,
trend, and source-mix insights. That keeps the local-first and source-truth
contracts safe, but the product experience needs a dedicated Insights surface
and a public contract for deeper source-linked insight payloads before Agent
Packs can generate richer behavior, contrast, turning-point, or evidence-based
insights.

The design research for this ADR reviewed a private MemeX backup locally and
recorded only sanitized aggregate findings in WideNote docs. The same research
was reviewed with Kimi using repository docs and redacted context only. No raw
private records, backup rows, credentials, or local database contents were sent
to external review.

Kimi's review conditionally approved the direction with several guardrails:
public schemas must lead model-generated Pack output, high-risk or sensitive
claims need review gates, deep generation should live in a dedicated official
Pack rather than private mobile internals, and model/retriever unavailability
must fail closed instead of falling back to local keyword heuristics.

## Decision

Accept a staged Insight Depth foundation:

1. Add a public Insight Payload schema under `packages/schemas/src/insight/`
   with source refs, claims, metrics, supporting evidence, counter-evidence,
   confidence, sensitivity, review state, UI block declarations, and generator
   provenance.
2. Extend the renderer-safe insight UI block vocabulary to reserve evidence,
   counter-evidence, confidence, contrast, trend chart, and timeline blocks.
3. Add a Home-owned mobile Insights page at `/insights` and detail page at
   `/insights/:insightId`. These pages render local `InsightRecord` rows,
   claims, metrics, evidence, counter-evidence, source refs, and local
   archive/restore lifecycle actions.
4. Keep current deterministic card/insight generation lightweight. It may emit
   source-linked first-pass insights, but it must not infer deeper semantic
   patterns through local text keyword or regular-expression heuristics.
5. Defer deep automatic generation to a future dedicated official Pack,
   `pack.insight_depth`, using public schemas, permissioned tools, source-ref
   validation, runtime task attribution, reviewable traces, and model-backed
   semantic judgment.

## Guardrails

- Original captures, attachments, transcripts, and Memory remain source truth.
  Insights are derived state and must preserve source refs.
- Deep insight generation must fail closed when a governed model, retriever, or
  required permission is unavailable.
- High-sensitivity, high-risk, conflicting, low-confidence, medical, legal,
  financial, credential-like, identity, relationship, or psychological claims
  must route to review or be softened before auto-write.
- Mobile native handlers and future official Pack outputs still need required
  permission grants, declared output events, valid source refs, runtime
  task/run attribution, and trace evidence.
- Pattern candidates and insight payloads are rebuildable derived artifacts.
  They are not Memory, PKM truth, or replacements for raw records.

## Considered Options

- Keep insights only as Daily Recap/timeline snippets.
- Add a mobile Insights page without a public schema.
- Implement full deep insight generation directly in mobile capture
  orchestration.
- Stage public schema and review UI first, then add a dedicated official Pack.

## Rationale

The staged approach creates useful product surface immediately without
pretending the risky generation path is done. A public schema lets mobile,
runtime, and future Pack work share the same contract. A dedicated page gives
users a place to inspect evidence and archive stale insights. Deferring deep
generation keeps privacy, semantic-selection, permission, and trace policies
intact while preserving a clear implementation path.

## Consequences

- New mobile insight pages are hierarchical Home child pages and must not show
  bottom tabs.
- UI-visible insight changes require widget coverage for empty, list, detail,
  source-link, localization, and lifecycle states.
- Schema fixture validation must cover the Insight Payload contract.
- Future `pack.insight_depth` work should start from this ADR, the Insight
  Payload schema, and the research note rather than copying reference-product
  prompts or database structures.

## Follow-ups

- Implement `pack.insight_depth` with read-only pattern indexing,
  model-backed synthesis, reviewer/maintainer agents, and measured replay
  tests.
- Add richer renderers for reserved visual blocks after the schema and Pack
  outputs prove stable.
- Add explicit review queues for high-risk insight claims before broad
  auto-write behavior.
