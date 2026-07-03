# ADR-0021: Use Host-Rendered Pack UI Contributions

---
id: ADR-0021
title: Use Host-Rendered Pack UI Contributions
status: accepted
date: 2026-07-03
owners: [runtime, mobile]
tags: [agent-pack, plugin-ui, permissions, mobile]
supersedes: []
superseded_by:
sources:
  - ../architecture/current-contracts.md
  - ../rfcs/agent-pack-schema.md
  - ../research/2026-06-28-marketplace-pkm-plan.md
---

## Context

WideNote wants Agent Packs to attract community development: people should be
able to add features, AI orchestration, settings, result views, and future app
surfaces without becoming core app contributors. At the same time, WideNote is a
local-first mobile product. Community packs must not write mobile-private
tables, register native handlers, or bypass source-truth, permission, and trace
boundaries.

The existing Pack contract already has `ui_blocks`, but that only describes
safe structured result blocks. It does not say where a pack can appear in the
app, whether a settings contribution is allowed, or how navigation-level UI is
guarded.

## Decision

Agent Pack UI extensibility uses manifest-declared, host-rendered
`ui_contributions`.

Each contribution declares:

- a stable contribution id,
- a public host surface such as `settings.pack_detail`,
  `plugins.pack_home`, `artifact.detail`, `insight.detail`,
  `timeline.card.accessory`, or future surface ids,
- a contribution kind such as `settings_form`, `panel`, `event_blocks`,
  `action`, `inline_status`, or `bottom_tab`,
- optional event, block, slot, schema, placement, and permission metadata.

The mobile app owns rendering. Store-safe and community-safe contributions are
data, not executable Flutter code, WebViews, or native handlers. Host surfaces
must read public pack manifests, public runtime events, declared settings
schemas, and permission state. They must not let packs mutate mobile-private
tables or raw user records directly.

A manifest contribution declares intent; it does not activate an app surface by
itself. A surface becomes supported only when the host implements a renderer,
permission gate, and widget coverage for that surface. This slice activates
Pack Library metadata display and Settings contribution entry points. Detail
surfaces such as `insight.detail`, `artifact.detail`, and
`timeline.item.detail` can be declared and validated now, but their page
renderers remain explicit follow-up work.

Navigation-level UI such as `bottom_tab` is reserved for `official` and
`local_dev` packs until a later decision accepts arbitration, rollback, review,
and conflict policy. Sandboxed WebView or iframe-like plugin UI remains a
deferred high-flexibility escape hatch, not the default store-safe path.

## Considered Options

- Open arbitrary Flutter/plugin code for UI.
- Let packs register sandboxed WebViews first.
- Use manifest-declared host-rendered UI contributions first, with WebView
  deferred.

## Rationale

Host-rendered contributions match WideNote's current architecture: public
schemas are the extension boundary, mobile owns immediate UX, and sensitive
capabilities need explicit permissions and traces. They also keep the app
visually coherent on mobile while still letting pack authors declare settings,
panels, result blocks, actions, and future surface integrations.

This model is close to systems that use contribution points and structured
blocks: the host controls the surface, while extensions provide intent and data.
That is a better first slice for WideNote than exposing arbitrary UI code before
the sandbox and review model exists.

## Consequences

- Pack authors can target many app locations, but only through public,
  documented host surface ids.
- Every new durable surface id is a public contract and belongs in the schema,
  RFC, tests, and current contracts.
- Widget tests are required when a host surface starts rendering a new
  contribution kind or interaction.
- Pack manifests may declare validated future surface intent before the mobile
  renderer exists, but PRs must call out that boundary.
- Validators must reject unsafe combinations such as community `bottom_tab`
  contributions or contribution permissions not declared by the pack.
- Complex custom canvases, third-party OAuth screens, and rich embedded tools
  wait for a sandboxed WebView decision.

## Follow-ups

- Add runtime arbitration for conflicts when multiple packs target the same
  exclusive surface.
- Add a real pack detail page that can render `settings_form` contributions
  from `settings_schema`.
- Add detail-page renderers for `event_blocks` contributions on
  `insight.detail`, `artifact.detail`, and timeline surfaces.
- Decide the sandbox/WebView trust model before community packs can provide
  arbitrary rich UI.
- Document new surface ids as they become real rendered host surfaces.
