# Retrieval Feature

## Purpose

Owns mobile local search and embedding retrieval surfaces.

## Ownership Boundary

This feature wires user-facing hybrid search, embedding provider settings, and
mobile retrieval service orchestration. It does not own canonical local object
truth, provider protocol contracts, or Agent Pack schemas. Search projections
and embedding provider records live in `packages/dart/local_db`; embedding HTTP
contracts live in `packages/dart/model_providers`.

## Public Surface

- `application/embedding_settings_controller.dart`
- `application/local_search_service.dart`
- `presentation/retrieval_settings_page.dart`

## Dependencies

- Flutter Material
- `flutter_riverpod`
- `packages/dart/local_db`
- `packages/dart/model_providers`

## Generated Artifacts

None. User-facing strings are sourced from `apps/mobile/lib/l10n/*.arb` and
generated with `flutter gen-l10n`.
