# ADR-0015: Use Hierarchical Mobile Navigation Outside Bottom Tabs

---
id: ADR-0015
title: Use Hierarchical Mobile Navigation Outside Bottom Tabs
status: accepted
date: 2026-07-02
owners: []
tags: [mobile, navigation, ux]
supersedes: []
superseded_by:
sources:
  - ../research/2026-07-02-mobile-navigation-kimi-review.md
---

## Context

WideNote mobile has a small set of durable bottom navigation roots and a larger
set of pages opened from those roots. Before this decision, several child pages
were registered as flat shell routes and some entries used replacement
navigation. That made Android/system back behavior depend on the entry path:
some child pages returned to their parent, while others could behave like app
roots and delegate back to the platform.

The product should feel local, inspectable, and safe to explore. A user opening
a control page, source detail, timeline search, backup surface, or trace view
should be able to return to the page that owns it before the app exits.

## Decision

Only these route roots are peer bottom-tab destinations:

| Root | Role |
| --- | --- |
| `/` | Home / quick capture |
| `/chat` | Chat |
| `/todos` | Todos |
| `/plugins` | Agent Packs and runtime controls |

The center Record item in the bottom navigation is an action that opens capture
from Home. It is not a route root.

All other mobile pages are hierarchical child pages with a declared parent:

| Parent | Child pages |
| --- | --- |
| `/` | `/timeline`, `/memory`, `/recap`, `/settings` |
| `/timeline` | `/timeline/search`, `/timeline/cards/:cardId`, `/timeline/items/:itemId` |
| `/chat` | `/chat/session/:sessionId` |
| `/settings` | `/settings/permissions`, `/settings/model-providers`, `/settings/transcription`, `/settings/location`, `/settings/backup`, `/settings/traces` |
| `/plugins` | `/plugins/packs`, `/plugins/permissions`, `/plugins/model-providers`, `/plugins/backup`, `/plugins/traces` |

UI controls that open a direct child page should use push-style navigation so
the current stack remains intact. Shortcuts that jump over an intermediate
parent should construct the declared parent stack. Bottom-tab switches should
use replacement-style navigation because they move between peer roots. Direct
links to non-tab pages must still construct a back stack that returns through
the declared parent before platform exit. Contextual source links may preserve
the source page as their immediate back target when that is the user's visible
inspection context.

## Considered Options

- Keep flat routes and add custom back interception for every non-tab path.
- Use `go_router` nested routes to encode the page hierarchy.
- Move immediately to independent stateful tab stacks for every bottom tab.

## Rationale

Nested routes encode the UX contract in the router instead of scattering parent
rules across page widgets. They also make deep links and clicked entries follow
the same parent chain. Independent tab stacks may be useful later, but the
current product only needs four peer roots plus clear child-page ownership.

## Consequences

- Android/system back from non-tab pages returns to the declared parent instead
  of delegating directly to the platform.
- Tab root back behavior remains platform-owned unless a future ADR changes
  bottom-tab semantics.
- New mobile pages must be added under the owning parent route and covered by a
  navigation widget test.
- If a page can be reached from multiple features, its durable route parent
  should still be explicit; contextual source links may keep the originating
  page on the stack when source inspection is the visible task.

## Follow-ups

- Keep `apps/mobile/test/navigation_hierarchy_test.dart` updated when adding or
  moving mobile pages.
- Revisit stateful independent tab stacks only after product flows need
  preserved per-tab history.
