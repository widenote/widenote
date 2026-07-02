# ADR-0019: Hide Bottom Tabs On Mobile Child Pages

---
id: ADR-0019
title: Hide Bottom Tabs On Mobile Child Pages
status: accepted
date: 2026-07-03
owners: [mobile]
tags: [mobile, navigation, ux]
supersedes:
  - ./0015-use-hierarchical-mobile-navigation.md
superseded_by:
sources:
  - ./0015-use-hierarchical-mobile-navigation.md
  - ../architecture/current-contracts.md
  - ../research/2026-07-03-mobile-child-page-tabs-kimi-review.md
---

## Context

ADR-0015 established that WideNote mobile has four peer bottom-tab route roots
and that every other page belongs under an owning parent route. The route
hierarchy and back-stack behavior were accepted, but the visible shell still
allowed most child pages to keep the bottom tab bar. That made child pages feel
like tab-level destinations even when their route ownership and back behavior
said they were subordinate pages.

The product expectation is stricter: after a user enters a subpage, the page
should feel independent. The bottom tab bar belongs to peer tab roots, not to
detail, settings, search, trace, library, or other child pages.

Supersession note: this ADR partially supersedes ADR-0015 only for bottom-tab
visibility on child pages. ADR-0015 remains accepted for the route hierarchy,
declared parents, push-versus-replacement navigation, contextual source links,
and direct-link back-stack construction.

## Decision

Show the mobile bottom navigation bar only on these peer route roots:

| Root | Role |
| --- | --- |
| `/` | Home / quick capture |
| `/chat` | Chat list root |
| `/todos` | Todos |
| `/plugins` | Agent Packs and runtime controls |

Hide the bottom navigation bar on every non-root mobile page, including direct
children such as `/timeline`, `/memory`, `/recap`, `/settings`, nested detail
pages such as `/timeline/items/:itemId`, `/settings/traces/raw/:traceId`, and
tab-owned child pages such as `/chat/session/:sessionId` and `/plugins/packs`.

Child pages must still keep the hierarchical back behavior from ADR-0015:
system back returns to the declared parent stack before platform exit. Hiding
the bottom tab bar does not make child pages new route roots, and bottom-tab
switches remain replacement-style navigation between the four peer roots.

Contextual source links may still preserve the visible source page as the
immediate back target when source inspection is the user's task. The destination
remains a child page and must not show the bottom tab bar while visible.

## Considered Options

- Keep bottom tabs visible on child pages and rely on selected tab highlighting.
- Hide tabs only on deep details such as chat sessions and raw trace pages.
- Hide tabs on every non-root mobile page.

## Rationale

Root-only bottom tabs make the hierarchy visible: tabs switch between peer
areas, while child pages are focused inspection or configuration surfaces. This
matches the existing route ownership contract and avoids teaching users that a
settings page, search page, or detail page is a durable tab destination.

A root-only rule is easier to test and maintain than a list of exceptional
paths. When a new mobile page is added under a parent route, it inherits the
expected independent-page shell unless the team intentionally creates a new
peer tab root through a future decision.

## Consequences

- Navigation tests must assert both parent back stacks and bottom-tab
  visibility for new mobile child pages.
- Feature shortcuts that jump to child pages can keep their source-aware back
  behavior, but they should not expose bottom tabs on the destination.
- If a future page needs persistent bottom-tab access while visible, it must be
  promoted to a peer root or get an explicit follow-up decision.

## Follow-ups

- Keep `apps/mobile/test/navigation_hierarchy_test.dart` updated when adding
  route roots or child pages.
- Revisit independent per-tab navigation stacks only after product flows need
  preserved tab history in addition to root-only tab visibility.
