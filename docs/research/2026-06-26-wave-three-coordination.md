# Wave Three Coordination

Status: complete; see
`docs/research/2026-06-26-wave-three-results.md` for validation results.
Date: 2026-06-26
Scope: first user-visible integration wave after manifest bridge and Context
Packet foundations

## Goal

Move second-wave foundations into mobile-visible paths while keeping changes
bounded enough for focused widget tests and later simulator QA.

## Workers

| Worker | Scope | Write ownership |
| --- | --- | --- |
| Worker G | Mobile official pack manifest/catalog bridge | `apps/mobile/lib/features/plugins/application/pack_catalog.dart`, new mobile pack manifest helper files, `apps/mobile/lib/features/capture/application/capture_orchestrator.dart`, focused mobile tests |
| Worker H | Chat Context Packet integration | `apps/mobile/lib/features/chat/application/local_chat_context_source.dart`, focused chat tests, related chat README if needed |

## Reviewers

| Reviewer | Scope |
| --- | --- |
| Review G | Mobile manifest/catalog bridge acceptance and edge cases |
| Review H | Chat Context Packet integration acceptance and edge cases |

## Coordination Boundaries

- Worker G owns the mobile pack metadata and capture runtime pack definition
  bridge. It must not change local DB Context Packet builder or Agent Runtime
  parser internals.
- Worker H owns chat context sourcing. It must not change pack catalog,
  capture orchestration, or plugin UI.
- The coordinator owns docs index updates, final mobile validation, and
  simulator QA planning.

## Wave Exit Criteria

- Mobile plugin catalog and capture runtime definitions are derived from a
  manifest-shaped source or checked against official manifests so metadata drift
  is caught by tests.
- Chat context source uses `ContextPacketBuilder` as its progressive disclosure
  path and keeps source refs visible in the current chat UI.
- Focused widget/unit tests cover user-visible behavior for both integrations.
- Mobile `flutter analyze` and full `flutter test` pass.
- Coordinator can proceed to simulator QA or the next product slice.

## Known Non-Goals

- No complete capture-orchestrator rewrite.
- No community pack execution.
- No encrypted full backup UX in this wave.
- No visual redesign beyond necessary source/context behavior.
