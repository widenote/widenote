# Recap Feature

## Purpose

Owns the Daily Recap second-level mobile page for a coarse local summary of
what was captured, remembered, suggested, and derived today.

## Ownership Boundary

The recap feature builds a read-only UI projection from existing local object
truth: captures, events, Memory, cards, insights, todos, and trace rows. It does
not call model providers, mutate raw records, create canonical recap storage, or
own Agent Pack runtime policy.

When durable recap objects are added by the default pack, this feature should
consume that public read model while keeping raw source refs visible.

## Dependencies

- Flutter Material
- `flutter_riverpod`
- `go_router`
- `packages/dart/local_db`
- `packages/dart/cards` for source-link parsing helpers

## Public Surface

- `presentation/DailyRecapPage`
- `application/dailyRecapProvider`
- `application/LocalDbDailyRecapRepository`
- immutable view models in `domain/`

## Generated Artifacts

None.
