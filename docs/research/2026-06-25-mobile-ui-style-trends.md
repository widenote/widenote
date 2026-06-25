# Mobile UI Style Trends

Date: 2026-06-25

Scope: current mobile UI direction for WideNote after reviewing 2026-era
platform guidance and design-system constraints.

## Sources Reviewed

- Google Material 3: <https://m3.material.io/>
- Google Android refresh / Material 3 Expressive:
  <https://blog.google/products-and-platforms/platforms/android/material-3-expressive-android-wearos-launch/>
- Android Developers Material 3 in Compose:
  <https://developer.android.com/develop/ui/compose/designsystems/material3>
- Apple Liquid Glass announcement:
  <https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/>
- Apple Human Interface Guidelines / Materials:
  <https://developer.apple.com/design/human-interface-guidelines/materials>
- Flutter Material 3 migration:
  <https://docs.flutter.dev/release/breaking-changes/material-3-migration>
- Flutter Material 3 Expressive tracking issue:
  <https://github.com/flutter/flutter/issues/168813>
- UX Collective 2026 experience-design trends:
  <https://uxdesign.cc/the-most-popular-experience-design-trends-of-2026-3ca85c8a3e3d>
- Muzli mobile app design patterns for 2026:
  <https://muz.li/blog/whats-changing-in-mobile-app-design-ui-patterns-that-matter-in-2026/>

## Findings

The 2026 mobile direction is not a single visual filter. It is a convergence of
three forces:

- Material 3 Expressive: stronger hierarchy through color, typography, shape,
  responsive components, and livelier motion.
- Liquid Glass: translucent controls and navigation that sit above content and
  preserve context, rather than making every content card glassy.
- AI-native structure: semantic tokens, clear component intent, provenance, and
  adaptive surfaces matter because both users and agents read the interface.

Flutter is the constraint. Material 3 Expressive exists in Android/Compose, but
Flutter does not yet actively ship the full Expressive component set. WideNote
should therefore adopt the direction through stable Flutter theme tokens,
component rules, and targeted custom surfaces instead of depending on unavailable
platform components.

## Recommended WideNote Direction

Name: Calm Expressive / Quiet Glass Console.

The app should feel like a local-first memory console, not a marketing page and
not a decorative notebook. The first screen remains the usable capture surface.
The visual system should make raw records, source links, Memory status, and
agent outputs easy to scan.

Principles:

- Keep content surfaces calm: neutral cool surfaces, strong text contrast,
  compact sections, and card radius no larger than 8px.
- Put expressiveness in control layers: navigation, active buttons, status
  chips, source tags, and review affordances get stronger color and motion.
- Use glass sparingly: navigation bars, floating controls, and modal/sheet
  layers can use a translucent feel; core record text stays on opaque surfaces.
- Use a multi-accent palette: blue for primary capture/action, teal for Memory
  and source confidence, amber for review/warning, red only for destructive or
  security states.
- Prefer semantic design tokens over literal color names so future agents and
  design tools can reason about component roles.
- Avoid one-note purple/blue gradients, beige notebook styling, decorative
  blobs, and oversized editorial hero sections.

## Initial Token Direction

Core colors:

- Primary action: deep azure
- Secondary memory/source: muted teal
- Tertiary review: warm amber
- Error/security: controlled red
- Background: cool off-white gray
- Surfaces: white to cool gray container steps
- Text: near-ink neutral

Shape and density:

- Cards: 8px radius, subtle outline, low/no elevation
- Inputs: 8px radius, filled surface, clear focused border
- Buttons: slightly stronger shape than cards, icon-first where possible
- Bottom navigation: opaque/translucent surface container, stronger selected
  indicator, compact labels

Typography:

- No negative letter spacing
- Compact panel headings
- Strong but not hero-scale page titles
- Use font weight before oversized type for hierarchy

## Product Impact

This direction matches WideNote constraints:

- local-first and account-free usage remains central
- raw input stays readable and visually separate from AI output
- source links and review states become first-class UI elements
- model/provider/network uncertainty can be shown as status, not hidden magic

## Implementation Notes

Start with a global theme and token pass in `apps/mobile/lib/app`, then move
feature pages toward shared source/status components. Do not introduce heavy
glass blur everywhere until readability and performance are tested on emulator.
