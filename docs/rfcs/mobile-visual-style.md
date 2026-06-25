# RFC: Mobile Visual Style

## Summary

WideNote mobile should adopt a Calm Expressive / Quiet Glass Console visual
style: calm, dense, source-first content surfaces with more expressive control
layers for capture, review, navigation, and status.

## Motivation

The current UI is functionally useful but visually generic. Most pages rely on a
thin Material seed color and local widget defaults, so the product lacks a
recognizable hierarchy for raw records, Memory, todos, source links, model
fallback, and review states.

## Goals

- Make the app feel current with 2026 mobile UI direction without chasing
  unavailable Flutter components.
- Keep first-screen quick capture usable, not hidden behind a landing page.
- Improve scanability for raw records, Memory, cards, todos, and traces.
- Reserve stronger styling for controls, state, and provenance.
- Keep content readable on opaque surfaces.
- Define reusable tokens before broad feature-page redesign.

## Non-goals

- Full Liquid Glass implementation across content cards.
- A marketing-style home screen.
- Golden-test-only visual validation.
- Replacing Flutter Material with a custom design framework.

## Style Decision

The style name is Calm Expressive / Quiet Glass Console.

Rules:

- Content surfaces are quiet and opaque.
- Navigation, action controls, review states, and provenance tags may be more
  expressive.
- Cards use 8px radius or less.
- No decorative gradient blobs, one-note purple themes, beige notebook themes,
  or oversized hero layouts.
- Color roles are semantic: primary action, memory/source, review/warning,
  destructive/security, neutral surface.
- Typography uses hierarchy and weight without negative letter spacing.
- Source links and status labels must be visually legible because they are core
  product semantics.

## Initial Implementation

Create a mobile app theme boundary under `apps/mobile/lib/app` and apply:

- a multi-accent Material 3 color scheme
- cool neutral scaffold and stepped surface containers
- compact page/title typography
- outlined low-elevation cards
- filled inputs with clear focus states
- selected navigation indicators with calmer surface treatment
- consistent button and chip shapes

## Privacy and Local-first Impact

This style makes privacy and provenance more visible. It does not change data
ownership, account requirements, sync, model routing, or backup semantics.

## Testing

- Unit-test the app theme tokens and shape constraints.
- Keep widget tests for UI behavior, navigation, review, backup, and todo
  interactions.
- Validate the main journey in Android emulator after theme changes.

## Alternatives

- Adopt pure Material 3 defaults. This remains too generic and does not express
  WideNote's source-first semantics.
- Mimic Liquid Glass everywhere. This risks readability, performance, and
  over-styling in a data-heavy local-first app.
- Wait for Flutter Material 3 Expressive. This delays product polish and does
  not solve component semantics today.

## Decision Outcome

Accepted as the initial mobile visual direction for phase-one UI polish.
