# ADR-0022: Drop Insight Archive Actions

---
id: ADR-0022
title: Drop Insight Archive Actions
status: accepted
date: 2026-07-04
owners: [product, mobile, runtime]
tags: [insights, mobile, default-ux]
supersedes:
  - ADR-0020
superseded_by:
sources:
  - ../architecture/current-contracts.md
  - ../research/2026-07-03-insight-depth-design.md
  - ../research/2026-07-04-insight-interaction-candidates.html
---

## Context

ADR-0020 accepted the first Insights page and included local archive/restore
actions as a low-risk lifecycle control. Product review found that archive does
not explain what should happen to an insight, does not improve the core
reflection loop, and adds management work before the product has high-quality
deep insights.

The next insight direction is heavier: a neutral reflective persona should help
the user understand recent state, patterns, contradictions, rhythms, and
possible next questions. In that context, a generic archive button is weaker
than explicit feedback, correction, pinning, regeneration, supersession, or a
well-named dismiss action.

## Decision

Remove archive and restore actions from the mobile Insights surface.

The current mobile page reads and displays local `InsightRecord` rows, claims,
metrics, evidence, counter-evidence, and source refs. It must not write
`wn.insight.archived` or `wn.insight.restored` as user lifecycle events.

Do not add a replacement lifecycle control until the product semantics are
clear. Future options should be evaluated under the deep-insight design:

- pin for "keep this prominent"
- ask for "open this as a conversational object"
- correct sources for "this evidence is wrong"
- regenerate for "try again with the same window"
- supersede for "a newer insight replaces this"
- dismiss for "hide this because it is not useful"

## Consequences

- Existing archive/restore UI tests are replaced by tests that assert those
  actions are absent.
- The database schema keeps the `status` field for existing records, review
  states, and future supersession or dismiss semantics.
- Historical archived records from earlier builds remain local data; this ADR
  does not define a destructive migration. The mobile Insights page hides those
  legacy rows so previously dismissed content does not reappear without a
  clearer lifecycle model.
- Deep insight work should focus on quality, evidence, neutrality, and feedback
  rather than generic list cleanup.

## Partial Supersession

This ADR partially supersedes ADR-0020 only for archive/restore actions on the
mobile Insights page. ADR-0020 remains accepted for the source-linked Insights
surface, schema foundation, deep insight guardrails, and future
`pack.insight_depth` direction.
